package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"go.opentelemetry.io/otel/metric/noop"
)

const testIssuer = "https://token.actions.githubusercontent.com"

var testKey = func() *rsa.PrivateKey {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(err)
	}
	return key
}()

func signJWT(t *testing.T, claims map[string]any) string {
	t.Helper()
	enc := base64.RawURLEncoding
	body, err := json.Marshal(claims)
	if err != nil {
		t.Fatal(err)
	}
	input := enc.EncodeToString([]byte(`{"alg":"RS256","typ":"JWT"}`)) + "." + enc.EncodeToString(body)
	sum := sha256.Sum256([]byte(input))
	sig, err := rsa.SignPKCS1v15(rand.Reader, testKey, crypto.SHA256, sum[:])
	if err != nil {
		t.Fatal(err)
	}
	return input + "." + enc.EncodeToString(sig)
}

func actionsToken(t *testing.T, repo, aud string) string {
	return actionsTokenWith(t, map[string]any{"repository": repo, "aud": aud, "sub": "repo:" + repo + ":ref:refs/heads/main"})
}

// actionsTokenWith signs an Actions token for acme/app, with claims overridden by overrides.
func actionsTokenWith(t *testing.T, overrides map[string]any) string {
	claims := map[string]any{
		"iss": testIssuer, "aud": "token-broker", "repository": "acme/app", "actor": "dev", "run_id": "7",
		"sub": "repo:acme/app:ref:refs/heads/main", "repository_id": "1431", "repository_owner_id": "9436",
		"iat": time.Now().Unix(), "exp": time.Now().Add(5 * time.Minute).Unix(),
	}
	for k, v := range overrides {
		claims[k] = v
	}
	return signJWT(t, claims)
}

// minted holds the last agent token request body sent to the fake GitHub.
func newTestBroker(t *testing.T) (*broker, *map[string]any) {
	t.Helper()
	var minted map[string]any
	gh := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		switch {
		case r.URL.Path == "/applications/login-client/token" && r.Method == http.MethodPost:
			id, secret, _ := r.BasicAuth()
			var in struct {
				AccessToken string `json:"access_token"`
			}
			_ = json.NewDecoder(r.Body).Decode(&in)
			users := map[string]string{"ghu_dev": "dev", "ghu_reader": "reader"}
			if id != "login-client" || secret != "s3cret" || users[in.AccessToken] == "" {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			_, _ = w.Write([]byte(`{"user":{"login":"` + users[in.AccessToken] + `"}}`))
		case r.URL.Path == "/repos/acme/app/installation" && strings.HasPrefix(auth, "Bearer "):
			_, _ = w.Write([]byte(`{"id":42}`))
		case r.URL.Path == "/app/installations/42/access_tokens" && r.Method == http.MethodPost:
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			if perms, _ := body["permissions"].(map[string]any); len(perms) == 1 {
				_, _ = w.Write([]byte(`{"token":"ghs_check"}`))
				return
			}
			minted = body
			_, _ = w.Write([]byte(`{"token":"ghs_agent","expires_at":"2026-01-01T00:00:00Z"}`))
		case strings.HasPrefix(r.URL.Path, "/repos/acme/app/collaborators/") && auth == "Bearer ghs_check":
			perm := map[string]string{"dev": "write", "reader": "read"}[strings.Split(r.URL.Path, "/")[5]]
			_, _ = w.Write([]byte(`{"permission":"` + perm + `"}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	t.Cleanup(gh.Close)

	keys := &oidc.StaticKeySet{PublicKeys: []crypto.PublicKey{&testKey.PublicKey}}
	actions := oidc.NewVerifier(testIssuer, keys, &oidc.Config{ClientID: "token-broker"})
	cfg := config{appID: "1", key: testKey, org: "acme", apiURL: gh.URL, loginID: "login-client", loginSecret: "s3cret"}
	b, err := newBroker(cfg, actions, noop.NewMeterProvider().Meter(""))
	if err != nil {
		t.Fatal(err)
	}
	return b, &minted
}

func TestHandleToken(t *testing.T) {
	tests := []struct {
		name, bearer, repo string
		want               int
	}{
		{"developer issued", "ghu_dev", "acme/app", http.StatusOK},
		{"developer without push", "ghu_reader", "acme/app", http.StatusForbidden},
		{"foreign or invalid login token", "gho_other", "acme/app", http.StatusUnauthorized},
		{"missing token", "", "acme/app", http.StatusUnauthorized},
		{"app not installed", "ghu_dev", "acme/uninstalled", http.StatusForbidden},
		{"other org", "ghu_dev", "evil/app", http.StatusForbidden},
		{"path traversal", "ghu_dev", "acme/../app", http.StatusBadRequest},
		{"actions issued", actionsToken(t, "acme/app", "token-broker"), "acme/app", http.StatusOK},
		{"actions other repo", actionsToken(t, "acme/other", "token-broker"), "acme/app", http.StatusForbidden},
		{"actions wrong audience", actionsToken(t, "acme/app", "someone-else"), "acme/app", http.StatusUnauthorized},
		{"actions pull_request subject", actionsTokenWith(t, map[string]any{"sub": "repo:acme/app:pull_request"}), "acme/app", http.StatusOK},
		{"actions immutable subject", actionsTokenWith(t, map[string]any{"sub": "repo:acme@9436/app@1431:ref:refs/heads/main"}), "acme/app", http.StatusOK},
		{"actions subject other repo", actionsTokenWith(t, map[string]any{"sub": "repo:acme/other:ref:refs/heads/main"}), "acme/app", http.StatusForbidden},
		{"actions subject repo name prefix", actionsTokenWith(t, map[string]any{"sub": "repo:acme/app-fork:ref:refs/heads/main"}), "acme/app", http.StatusForbidden},
		{"actions immutable subject other repo ID", actionsTokenWith(t, map[string]any{"sub": "repo:acme@9436/app@9999:ref:refs/heads/main"}), "acme/app", http.StatusForbidden},
		{"actions missing subject", actionsTokenWith(t, map[string]any{"sub": ""}), "acme/app", http.StatusForbidden},
		{"actions forged signature", actionsToken(t, "acme/app", "token-broker") + "x", "acme/app", http.StatusUnauthorized},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b, minted := newTestBroker(t)
			req := httptest.NewRequest(http.MethodPost, "/token", strings.NewReader(`{"repo":"`+tt.repo+`"}`))
			if tt.bearer != "" {
				req.Header.Set("Authorization", "Bearer "+tt.bearer)
			}
			rec := httptest.NewRecorder()
			b.handleToken(rec, req)
			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d: %s", rec.Code, tt.want, rec.Body)
			}
			if tt.want != http.StatusOK {
				if *minted != nil {
					t.Errorf("agent token minted on denied request")
				}
				return
			}
			if !strings.Contains(rec.Body.String(), "ghs_agent") {
				t.Errorf("body missing token: %s", rec.Body)
			}
			repos, _ := (*minted)["repositories"].([]any)
			if len(repos) != 1 || repos[0] != "app" {
				t.Errorf("token not scoped to single repo: %v", (*minted)["repositories"])
			}
			if perms, _ := (*minted)["permissions"].(map[string]any); perms["workflows"] != nil || perms["contents"] != "write" {
				t.Errorf("unexpected permissions: %v", perms)
			}
		})
	}
}

func TestHandleActionsToken(t *testing.T) {
	tests := []struct {
		name, bearer string
		want         int
	}{
		{"actions issued", actionsToken(t, "acme/app", "token-broker"), http.StatusOK},
		{"valid login token rejected", "ghu_dev", http.StatusUnauthorized},
		{"missing token", "", http.StatusUnauthorized},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			b, minted := newTestBroker(t)
			req := httptest.NewRequest(http.MethodPost, "/token/actions", strings.NewReader(`{"repo":"acme/app"}`))
			if tt.bearer != "" {
				req.Header.Set("Authorization", "Bearer "+tt.bearer)
			}
			rec := httptest.NewRecorder()
			b.handleActionsToken(rec, req)
			if rec.Code != tt.want {
				t.Fatalf("status = %d, want %d: %s", rec.Code, tt.want, rec.Body)
			}
			if tt.want != http.StatusOK && *minted != nil {
				t.Errorf("agent token minted on denied request")
			}
		})
	}
}
