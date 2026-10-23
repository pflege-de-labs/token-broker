// Command token-broker exchanges a developer login (GitHub App device flow) or a
// GitHub Actions OIDC token for a short-lived, single-repo agent token.
package main

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"syscall"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/prometheus"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
)

// Agent tokens never get more than this, regardless of what the app is granted.
var agentPermissions = map[string]string{
	"contents":      "write",
	"pull_requests": "write",
	"issues":        "write",
	"metadata":      "read",
}

// Set by the image build via -ldflags.
var version = "dev"

// Guards the path segments we splice into GitHub API URLs.
var namePattern = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

type config struct {
	appID       string
	key         *rsa.PrivateKey
	org         string
	apiURL      string
	loginID     string // client ID of the low-privilege login app
	loginSecret string
	// Optional Actions allowlists (globs, `*` spans `/`); empty allows any ref or workflow.
	allowedRefs      []string
	allowedWorkflows []string
}

type broker struct {
	cfg      config
	client   *http.Client
	actions  *oidc.IDTokenVerifier
	requests metric.Int64Counter
	latency  metric.Float64Histogram
}

// Claims we use from GitHub Actions OIDC tokens.
type actionsClaims struct {
	Subject           string `json:"sub"`
	Repository        string `json:"repository"`
	RepositoryID      string `json:"repository_id"`
	RepositoryOwnerID string `json:"repository_owner_id"`
	Actor             string `json:"actor"`
	Ref               string `json:"ref"`
	JobWorkflowRef    string `json:"job_workflow_ref"`
	RunID             string `json:"run_id"`
}

func main() {
	if err := run(); err != nil {
		slog.Error("token-broker failed", "err", err)
		os.Exit(1)
	}
}

func run() error {
	key, err := loadKey(os.Getenv("GITHUB_APP_PRIVATE_KEY_FILE"))
	if err != nil {
		return err
	}
	cfg := config{
		appID:            os.Getenv("GITHUB_APP_ID"),
		key:              key,
		org:              os.Getenv("GITHUB_ORG"),
		apiURL:           envOr("GITHUB_API_URL", "https://api.github.com"),
		loginID:          os.Getenv("LOGIN_APP_CLIENT_ID"),
		loginSecret:      os.Getenv("LOGIN_APP_CLIENT_SECRET"),
		allowedRefs:      splitList(os.Getenv("ACTIONS_ALLOWED_REFS")),
		allowedWorkflows: splitList(os.Getenv("ACTIONS_ALLOWED_WORKFLOWS")),
	}
	if cfg.appID == "" || cfg.org == "" || cfg.loginID == "" || cfg.loginSecret == "" {
		return errors.New("GITHUB_APP_ID, GITHUB_ORG, LOGIN_APP_CLIENT_ID and LOGIN_APP_CLIENT_SECRET are required")
	}
	issuer := envOr("ACTIONS_OIDC_ISSUER", "https://token.actions.githubusercontent.com")
	keys := oidc.NewRemoteKeySet(context.Background(), issuer+"/.well-known/jwks")
	actions := oidc.NewVerifier(issuer, keys, &oidc.Config{ClientID: envOr("ACTIONS_OIDC_AUDIENCE", "token-broker")})

	exporter, err := prometheus.New()
	if err != nil {
		return err
	}
	provider := sdkmetric.NewMeterProvider(sdkmetric.WithReader(exporter))
	b, err := newBroker(cfg, actions, provider.Meter("token-broker"))
	if err != nil {
		return err
	}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /token", b.handleToken)
	mux.HandleFunc("POST /token/actions", b.handleActionsToken)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("GET /readyz", b.handleReady)
	mux.Handle("GET /metrics", promhttp.Handler())

	srv := &http.Server{Addr: envOr("LISTEN_ADDR", ":8080"), Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdownCtx)
	}()

	slog.Info("listening", "addr", srv.Addr, "org", cfg.org, "version", version)
	if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return provider.Shutdown(context.Background())
}

func newBroker(cfg config, actions *oidc.IDTokenVerifier, meter metric.Meter) (*broker, error) {
	requests, err := meter.Int64Counter("broker.token.requests", metric.WithDescription("Token requests by outcome"))
	if err != nil {
		return nil, err
	}
	latency, err := meter.Float64Histogram("broker.token.duration", metric.WithUnit("s"))
	if err != nil {
		return nil, err
	}
	return &broker{cfg: cfg, client: &http.Client{Timeout: 10 * time.Second}, actions: actions, requests: requests, latency: latency}, nil
}

// handleActionsToken is the only path a public route should forward: it never accepts
// login tokens, so the device flow stays reachable from the internal network only.
func (b *broker) handleActionsToken(w http.ResponseWriter, r *http.Request) {
	bearer, _ := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if strings.Count(bearer, ".") != 2 {
		attrs := metric.WithAttributes(attribute.String("outcome", "unauthenticated"), attribute.String("via", "actions"))
		b.requests.Add(r.Context(), 1, attrs)
		http.Error(w, "only GitHub Actions OIDC tokens are accepted here", http.StatusUnauthorized)
		return
	}
	b.handleToken(w, r)
}

func (b *broker) handleToken(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	outcome, via := "error", "unknown"
	defer func() {
		attrs := metric.WithAttributes(attribute.String("outcome", outcome), attribute.String("via", via))
		b.requests.Add(r.Context(), 1, attrs)
		b.latency.Record(r.Context(), time.Since(start).Seconds(), attrs)
	}()
	var audit []any
	fail := func(status int, o, msg string, args ...any) {
		outcome = o
		slog.Warn("token denied", append(append([]any{"reason", msg, "status", status, "via", via}, audit...), args...)...)
		http.Error(w, msg, status)
	}

	bearer, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !ok || bearer == "" {
		fail(http.StatusUnauthorized, "unauthenticated", "missing bearer token")
		return
	}
	var req struct {
		Repo string `json:"repo"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 4096)).Decode(&req); err != nil {
		fail(http.StatusBadRequest, "bad_request", "invalid JSON body")
		return
	}
	owner, name, ok := strings.Cut(req.Repo, "/")
	if !ok || !namePattern.MatchString(owner) || !namePattern.MatchString(name) {
		fail(http.StatusBadRequest, "bad_request", "repo must be owner/name")
		return
	}
	audit = append(audit, "repo", req.Repo)
	if !strings.EqualFold(owner, b.cfg.org) {
		fail(http.StatusForbidden, "denied", "repo outside allowed org")
		return
	}

	ctx := r.Context()
	// Login app user tokens (ghu_) never contain dots; Actions OIDC tokens are JWTs.
	var developer string
	if strings.Count(bearer, ".") == 2 {
		via = "actions"
		idToken, err := b.actions.Verify(ctx, bearer)
		if err != nil {
			fail(http.StatusUnauthorized, "unauthenticated", "invalid Actions OIDC token", "err", err)
			return
		}
		var c actionsClaims
		if err := idToken.Claims(&c); err != nil {
			fail(http.StatusUnauthorized, "unauthenticated", "unreadable Actions OIDC claims", "err", err)
			return
		}
		audit = append(audit, "actor", c.Actor, "workflow_repo", c.Repository, "sub", c.Subject, "ref", c.Ref, "job_workflow_ref", c.JobWorkflowRef, "run_id", c.RunID)
		// A workflow may only get a token for the repo it runs in.
		if !strings.EqualFold(c.Repository, req.Repo) {
			fail(http.StatusForbidden, "denied", "Actions token is for a different repo")
			return
		}
		if !subjectMatches(c, owner, name) {
			fail(http.StatusForbidden, "denied", "Actions token subject is for a different repo")
			return
		}
		if !matchesAny(b.cfg.allowedRefs, c.Ref) {
			fail(http.StatusForbidden, "denied", "Actions ref not allowed")
			return
		}
		if !matchesAny(b.cfg.allowedWorkflows, c.JobWorkflowRef) {
			fail(http.StatusForbidden, "denied", "Actions workflow not allowed")
			return
		}
	} else {
		via = "device"
		login, status, err := b.loginUser(ctx, bearer)
		if err != nil {
			if status == http.StatusNotFound {
				fail(http.StatusUnauthorized, "unauthenticated", "invalid login token, run agent-token again to log in")
			} else {
				fail(http.StatusBadGateway, "error", "login token check failed", "err", err)
			}
			return
		}
		developer = login
		audit = append(audit, "user", login)
	}

	jwt, err := b.appJWT(time.Now())
	if err != nil {
		fail(http.StatusInternalServerError, "error", "signing app JWT failed", "err", err)
		return
	}
	var inst struct {
		ID int64 `json:"id"`
	}
	status, err := b.github(ctx, http.MethodGet, "/repos/"+owner+"/"+name+"/installation", "Bearer "+jwt, nil, &inst)
	if status == http.StatusNotFound {
		fail(http.StatusForbidden, "denied", "app not installed on repo")
		return
	}
	if err != nil {
		fail(http.StatusBadGateway, "error", "installation lookup failed", "err", err)
		return
	}

	if developer != "" {
		// The developer can only hand the agent repos they could push to themselves.
		check, err := b.installationToken(ctx, jwt, inst.ID, name, map[string]string{"metadata": "read"})
		if err != nil {
			fail(http.StatusBadGateway, "error", "minting check token failed", "err", err)
			return
		}
		var perm struct {
			Permission string `json:"permission"`
		}
		status, err := b.github(ctx, http.MethodGet, "/repos/"+owner+"/"+name+"/collaborators/"+developer+"/permission", "Bearer "+check.Token, nil, &perm)
		if status == http.StatusNotFound || (err == nil && perm.Permission != "admin" && perm.Permission != "write") {
			fail(http.StatusForbidden, "denied", "no push access to repo", "permission", perm.Permission)
			return
		}
		if err != nil {
			fail(http.StatusBadGateway, "error", "permission lookup failed", "err", err)
			return
		}
	}

	tok, err := b.installationToken(ctx, jwt, inst.ID, name, agentPermissions)
	if err != nil {
		fail(http.StatusBadGateway, "error", "minting installation token failed", "err", err)
		return
	}

	outcome = "issued"
	slog.Info("token issued", append([]any{"via", via, "expires_at", tok.ExpiresAt}, audit...)...)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"token": tok.Token, "expires_at": tok.ExpiresAt})
}

// subjectMatches reports whether sub names owner/name, in either GitHub's classic form
// "repo:owner/name:..." or the immutable "repo:owner@ownerID/name@repoID:..." form, whose
// IDs must also match the signed ID claims (a re-created repo of the same name gets new IDs).
func subjectMatches(c actionsClaims, owner, name string) bool {
	sub := strings.ToLower(c.Subject)
	classic := strings.ToLower("repo:" + owner + "/" + name + ":")
	if strings.HasPrefix(sub, classic) {
		return true
	}
	if c.RepositoryOwnerID == "" || c.RepositoryID == "" {
		return false
	}
	immutable := strings.ToLower("repo:" + owner + "@" + c.RepositoryOwnerID + "/" + name + "@" + c.RepositoryID + ":")
	return strings.HasPrefix(sub, immutable)
}

type installationToken struct {
	Token     string `json:"token"`
	ExpiresAt string `json:"expires_at"`
}

func (b *broker) installationToken(ctx context.Context, jwt string, id int64, repo string, perms map[string]string) (installationToken, error) {
	var tok installationToken
	body := map[string]any{"repositories": []string{repo}, "permissions": perms}
	_, err := b.github(ctx, http.MethodPost, fmt.Sprintf("/app/installations/%d/access_tokens", id), "Bearer "+jwt, body, &tok)
	return tok, err
}

// loginUser returns the login behind a login app user token; only that app's tokens are accepted.
func (b *broker) loginUser(ctx context.Context, token string) (string, int, error) {
	var check struct {
		User *struct {
			Login string `json:"login"`
		} `json:"user"`
	}
	basic := "Basic " + base64.StdEncoding.EncodeToString([]byte(b.cfg.loginID+":"+b.cfg.loginSecret))
	status, err := b.github(ctx, http.MethodPost, "/applications/"+b.cfg.loginID+"/token", basic, map[string]string{"access_token": token}, &check)
	if err != nil {
		return "", status, err
	}
	if check.User == nil || check.User.Login == "" {
		return "", http.StatusNotFound, errors.New("token has no user")
	}
	return check.User.Login, status, nil
}

// Ready when GitHub accepts the app key; a GitHub outage marks every replica unready by design.
func (b *broker) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	jwt, err := b.appJWT(time.Now())
	if err == nil {
		_, err = b.github(ctx, http.MethodGet, "/app", "Bearer "+jwt, nil, nil)
	}
	if err != nil {
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// github returns the HTTP status (0 on transport failure) and an error for any non-2xx response.
func (b *broker) github(ctx context.Context, method, path, auth string, in, out any) (int, error) {
	var body io.Reader
	if in != nil {
		buf, err := json.Marshal(in)
		if err != nil {
			return 0, err
		}
		body = bytes.NewReader(buf)
	}
	req, err := http.NewRequestWithContext(ctx, method, b.cfg.apiURL+path, body)
	if err != nil {
		return 0, err
	}
	req.Header.Set("Authorization", auth)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	resp, err := b.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode >= 300 {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return resp.StatusCode, fmt.Errorf("%s %s: %d %s", method, path, resp.StatusCode, msg)
	}
	if out == nil {
		return resp.StatusCode, nil
	}
	return resp.StatusCode, json.NewDecoder(resp.Body).Decode(out)
}

func (b *broker) appJWT(now time.Time) (string, error) {
	enc := base64.RawURLEncoding
	header := enc.EncodeToString([]byte(`{"alg":"RS256","typ":"JWT"}`))
	// iat backdated for clock skew; GitHub caps exp at 10 minutes.
	claims, err := json.Marshal(map[string]any{
		"iat": now.Add(-time.Minute).Unix(),
		"exp": now.Add(9 * time.Minute).Unix(),
		"iss": b.cfg.appID,
	})
	if err != nil {
		return "", err
	}
	signingInput := header + "." + enc.EncodeToString(claims)
	sum := sha256.Sum256([]byte(signingInput))
	sig, err := rsa.SignPKCS1v15(rand.Reader, b.cfg.key, crypto.SHA256, sum[:])
	if err != nil {
		return "", err
	}
	return signingInput + "." + enc.EncodeToString(sig), nil
}

func loadKey(path string) (*rsa.PrivateKey, error) {
	if path == "" {
		return nil, errors.New("GITHUB_APP_PRIVATE_KEY_FILE is required")
	}
	data, err := os.ReadFile(path) // #nosec G304 -- path is operator config, never request input
	if err != nil {
		return nil, err
	}
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, errors.New("no PEM block in private key file")
	}
	// GitHub issues PKCS#1 keys; accept PKCS#8 for keys converted by other tooling.
	if key, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		return key, nil
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	key, ok := parsed.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("private key is not RSA")
	}
	return key, nil
}

// matchesAny reports whether s matches one of the glob patterns; an empty list matches everything.
func matchesAny(patterns []string, s string) bool {
	if len(patterns) == 0 {
		return true
	}
	for _, p := range patterns {
		// path.Match's `*` stops at `/`, which refs and workflow refs are full of.
		re := "^" + strings.ReplaceAll(regexp.QuoteMeta(p), `\*`, ".*") + "$"
		if regexp.MustCompile(re).MatchString(s) {
			return true
		}
	}
	return false
}

func splitList(s string) []string {
	var out []string
	for _, v := range strings.Split(s, ",") {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	return out
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
