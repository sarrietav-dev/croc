package webbridge

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGenerateCode(t *testing.T) {
	server, err := New(t.TempDir(), "")
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/api/code", nil)
	response := httptest.NewRecorder()

	server.Handler("").ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	var payload map[string]string
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		t.Fatal(err)
	}
	if len(payload["code"]) < 6 {
		t.Fatalf("generated code %q is too short", payload["code"])
	}
}

func TestSendRequiresFiles(t *testing.T) {
	server, err := New(t.TempDir(), "")
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/transfers/send",
		strings.NewReader(""),
	)
	request.Header.Set("Content-Type", "multipart/form-data; boundary=test")
	response := httptest.NewRecorder()

	server.Handler("").ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusBadRequest)
	}
}

func TestConfiguredCORS(t *testing.T) {
	server, err := New(t.TempDir(), "https://app.example")
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodOptions, "/api/code", nil)
	response := httptest.NewRecorder()

	server.Handler("").ServeHTTP(response, request)

	if got := response.Header().Get("Access-Control-Allow-Origin"); got != "https://app.example" {
		t.Fatalf("Access-Control-Allow-Origin = %q", got)
	}
}

func TestReceivedEventPreservesServerPath(t *testing.T) {
	sess := &session{id: "transfer-id", events: make(chan string, 1)}
	sess.OnEvent(`{"type":"received","files":[{"name":"report.pdf","path":"/private/report.pdf","size":42}]}`)

	if got := sess.files[0].Path; got != "/private/report.pdf" {
		t.Fatalf("stored path = %q", got)
	}
	var event struct {
		Files []receivedFile `json:"files"`
	}
	if err := json.Unmarshal([]byte(<-sess.events), &event); err != nil {
		t.Fatal(err)
	}
	if got := event.Files[0].Path; got != "/api/transfers/transfer-id/files/0" {
		t.Fatalf("client path = %q", got)
	}
}

func TestDownloadReceivedFile(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "report.pdf")
	if err := os.WriteFile(path, []byte("contents"), 0o600); err != nil {
		t.Fatal(err)
	}
	server, err := New(root, "")
	if err != nil {
		t.Fatal(err)
	}
	server.sessions.Store("transfer-id", &session{
		id:    "transfer-id",
		files: []receivedFile{{Name: "report.pdf", Path: path, Size: 8}},
	})
	request := httptest.NewRequest(http.MethodGet, "/api/transfers/transfer-id/files/0", nil)
	response := httptest.NewRecorder()

	server.Handler("").ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %q", response.Code, response.Body.String())
	}
	if got := response.Body.String(); got != "contents" {
		t.Fatalf("body = %q", got)
	}
}
