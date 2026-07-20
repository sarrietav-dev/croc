package webbridge

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"dev.sarrietav/crocbridge"
)

const maxUploadBytes = 4 << 30

type Server struct {
	root          string
	allowedOrigin string
	sessions      sync.Map
}

type session struct {
	id        string
	directory string
	events    chan string
	transfer  *crocbridge.Transfer
	stateMu   sync.RWMutex
	files     []receivedFile
	terminal  bool
	done      chan struct{}
}

type receivedFile struct {
	Name string `json:"name"`
	Path string `json:"path"`
	Size int64  `json:"size"`
}

type relaySettings struct {
	Address  string `json:"address"`
	Ports    string `json:"ports"`
	Password string `json:"password"`
}

type receiveRequest struct {
	Code  string        `json:"code"`
	Relay relaySettings `json:"relay"`
}

func New(root, allowedOrigin string) (*Server, error) {
	if root == "" {
		root = filepath.Join(os.TempDir(), "croc-web")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, fmt.Errorf("create transfer storage: %w", err)
	}
	return &Server{root: root, allowedOrigin: allowedOrigin}, nil
}

func (s *Server) Handler(webRoot string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/code", s.generateCode)
	mux.HandleFunc("POST /api/transfers/send", s.startSend)
	mux.HandleFunc("POST /api/transfers/receive", s.startReceive)
	mux.HandleFunc("GET /api/transfers/{id}/events", s.streamEvents)
	mux.HandleFunc("DELETE /api/transfers/{id}", s.cancelTransfer)
	mux.HandleFunc("GET /api/transfers/{id}/files/{index}", s.downloadFile)
	if webRoot != "" {
		mux.Handle("/", http.FileServer(http.Dir(webRoot)))
	}
	return s.withCORS(mux)
}

func (s *Server) generateCode(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"code": crocbridge.GenerateCode()})
}

func (s *Server) startSend(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		http.Error(w, "invalid file upload", http.StatusBadRequest)
		return
	}
	files := r.MultipartForm.File["files"]
	if len(files) == 0 {
		http.Error(w, "select at least one file", http.StatusBadRequest)
		return
	}

	sess, err := s.newSession(relaySettings{
		Address:  r.FormValue("relayAddress"),
		Ports:    r.FormValue("relayPorts"),
		Password: r.FormValue("relayPassword"),
	})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	var relativePaths []string
	if encoded := r.FormValue("relativePaths"); encoded != "" {
		if err := json.Unmarshal([]byte(encoded), &relativePaths); err != nil || len(relativePaths) != len(files) {
			s.failAndRemove(sess)
			http.Error(w, "invalid relative file paths", http.StatusBadRequest)
			return
		}
	}
	paths := make([]string, 0, len(files))
	seenPaths := make(map[string]bool)
	for index, header := range files {
		source, openErr := header.Open()
		if openErr != nil {
			s.failAndRemove(sess)
			http.Error(w, "read uploaded file", http.StatusBadRequest)
			return
		}
		name := filepath.Base(strings.ReplaceAll(header.Filename, "\\", "/"))
		if name == "." || name == string(filepath.Separator) || name == "" {
			name = "file"
		}
		uploadDirectory := filepath.Join(sess.directory, "uploads", strconv.Itoa(index))
		transferPath := filepath.Join(uploadDirectory, name)
		if len(relativePaths) != 0 {
			parts := strings.Split(strings.ReplaceAll(relativePaths[index], "\\", "/"), "/")
			valid := len(parts) != 0
			for _, part := range parts {
				if part == "" || part == "." || part == ".." || filepath.Base(part) != part {
					valid = false
					break
				}
			}
			if !valid {
				_ = source.Close()
				s.failAndRemove(sess)
				http.Error(w, "invalid relative file path", http.StatusBadRequest)
				return
			}
			if len(parts) > 1 {
				transferPath = filepath.Join(append([]string{sess.directory, "uploads"}, parts...)...)
				uploadDirectory = filepath.Dir(transferPath)
				root := filepath.Join(sess.directory, "uploads", parts[0])
				if !seenPaths[root] {
					paths = append(paths, root)
					seenPaths[root] = true
				}
			} else if !seenPaths[transferPath] {
				paths = append(paths, transferPath)
				seenPaths[transferPath] = true
			}
		}
		if createErr := os.MkdirAll(uploadDirectory, 0o700); createErr != nil {
			_ = source.Close()
			s.failAndRemove(sess)
			http.Error(w, "store uploaded file", http.StatusInternalServerError)
			return
		}
		target, createErr := os.OpenFile(transferPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
		if createErr == nil {
			_, createErr = io.Copy(target, source)
			createErr = errors.Join(createErr, target.Close())
		}
		_ = source.Close()
		if createErr != nil {
			s.failAndRemove(sess)
			http.Error(w, "store uploaded file", http.StatusInternalServerError)
			return
		}
		if len(relativePaths) == 0 {
			paths = append(paths, transferPath)
		}
	}

	encodedPaths, _ := json.Marshal(paths)
	s.sessions.Store(sess.id, sess)
	writeJSON(w, http.StatusAccepted, map[string]string{"id": sess.id})
	go s.run(sess, func() error {
		return sess.transfer.Send(r.FormValue("code"), string(encodedPaths))
	})
}

func (s *Server) startReceive(w http.ResponseWriter, r *http.Request) {
	var request receiveRequest
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	if err := decoder.Decode(&request); err != nil {
		http.Error(w, "invalid receive request", http.StatusBadRequest)
		return
	}
	sess, err := s.newSession(request.Relay)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.sessions.Store(sess.id, sess)
	writeJSON(w, http.StatusAccepted, map[string]string{"id": sess.id})
	go s.run(sess, func() error {
		return sess.transfer.Receive(request.Code, sess.directory)
	})
}

func (s *Server) streamEvents(w http.ResponseWriter, r *http.Request) {
	sess, ok := s.loadSession(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unavailable", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/x-ndjson")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	for {
		select {
		case event, open := <-sess.events:
			if !open {
				return
			}
			_, _ = io.WriteString(w, event+"\n")
			flusher.Flush()
		case <-r.Context().Done():
			return
		}
	}
}

func (s *Server) cancelTransfer(w http.ResponseWriter, r *http.Request) {
	sess, ok := s.loadSession(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	sess.transfer.Cancel()
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) downloadFile(w http.ResponseWriter, r *http.Request) {
	sess, ok := s.loadSession(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	index, err := strconv.Atoi(r.PathValue("index"))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	sess.stateMu.RLock()
	if index < 0 || index >= len(sess.files) {
		sess.stateMu.RUnlock()
		http.NotFound(w, r)
		return
	}
	file := sess.files[index]
	sess.stateMu.RUnlock()
	w.Header().Set("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": file.Name}))
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, file.Path)
}

func (s *Server) newSession(relay relaySettings) (*session, error) {
	id, err := randomID()
	if err != nil {
		return nil, err
	}
	directory, err := os.MkdirTemp(s.root, id+"-")
	if err != nil {
		return nil, fmt.Errorf("create transfer directory: %w", err)
	}
	sess := &session{id: id, directory: directory, events: make(chan string, 128), done: make(chan struct{})}
	sess.transfer = crocbridge.NewTransfer(sess, relay.Address, relay.Ports, relay.Password)
	return sess, nil
}

func (s *Server) run(sess *session, operation func() error) {
	err := operation()
	if err != nil && !sess.hasTerminalEvent() {
		sess.OnEvent(mustJSON(map[string]any{"type": "failed", "message": err.Error()}))
	}
	close(sess.events)
	close(sess.done)
	time.AfterFunc(time.Hour, func() {
		s.sessions.Delete(sess.id)
		_ = os.RemoveAll(sess.directory)
	})
}

func (s *Server) failAndRemove(sess *session) {
	_ = os.RemoveAll(sess.directory)
	s.sessions.Delete(sess.id)
}

func (s *Server) loadSession(id string) (*session, bool) {
	value, ok := s.sessions.Load(id)
	if !ok {
		return nil, false
	}
	return value.(*session), true
}

func (s *Server) withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.allowedOrigin != "" {
			w.Header().Set("Access-Control-Allow-Origin", s.allowedOrigin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *session) OnEvent(event string) {
	var payload struct {
		Type  string         `json:"type"`
		Files []receivedFile `json:"files"`
	}
	if json.Unmarshal([]byte(event), &payload) == nil && payload.Type == "received" {
		s.stateMu.Lock()
		s.files = append([]receivedFile(nil), payload.Files...)
		for index := range payload.Files {
			payload.Files[index].Path = fmt.Sprintf("/api/transfers/%s/files/%d", s.id, index)
		}
		s.stateMu.Unlock()
		event = mustJSON(payload)
	}
	if payload.Type == "complete" || payload.Type == "failed" {
		s.stateMu.Lock()
		s.terminal = true
		s.stateMu.Unlock()
	}
	select {
	case s.events <- event:
	default:
		// Progress is best-effort. Preserve terminal and received events by
		// replacing one stale buffered progress event when a client disconnects.
		if payload.Type == "complete" || payload.Type == "failed" || payload.Type == "received" {
			select {
			case <-s.events:
			default:
			}
			s.events <- event
		}
	}
}

func (s *session) hasTerminalEvent() bool {
	s.stateMu.RLock()
	defer s.stateMu.RUnlock()
	return s.terminal
}

func randomID() (string, error) {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		return "", fmt.Errorf("generate session ID: %w", err)
	}
	return hex.EncodeToString(value), nil
}

func mustJSON(value any) string {
	payload, _ := json.Marshal(value)
	return string(payload)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func ParseAddress(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ":8080"
	}
	return value
}
