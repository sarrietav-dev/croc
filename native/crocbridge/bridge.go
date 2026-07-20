package crocbridge

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/schollz/croc/v10/src/croc"
	"github.com/schollz/croc/v10/src/utils"
)

const (
	defaultRelayAddress  = "croc.schollz.com:9009"
	defaultRelayPassword = "pass123"
	defaultRelayPorts    = "9009,9010,9011,9012,9013"
)

// Listener receives JSON events on a Go runtime thread.
type Listener interface {
	OnEvent(event string)
}

// Transfer owns one cancellable croc operation.
type Transfer struct {
	listener      Listener
	relayAddress  string
	relayPorts    []string
	relayPassword string

	mu     sync.Mutex
	cancel context.CancelFunc
	active bool
}

type transferEvent struct {
	Type        string         `json:"type"`
	Stage       string         `json:"stage,omitempty"`
	Name        string         `json:"name,omitempty"`
	Done        int64          `json:"done,omitempty"`
	Total       int64          `json:"total,omitempty"`
	FileIndex   int            `json:"fileIndex,omitempty"`
	FileCount   int            `json:"fileCount,omitempty"`
	Files       []receivedFile `json:"files,omitempty"`
	Message     string         `json:"message,omitempty"`
	WasCanceled bool           `json:"wasCanceled,omitempty"`
}

type receivedFile struct {
	Name string `json:"name"`
	Path string `json:"path"`
	Size int64  `json:"size"`
}

var processTransferMu sync.Mutex

func NewTransfer(listener Listener, relayAddress, relayPorts, relayPassword string) *Transfer {
	if strings.TrimSpace(relayAddress) == "" {
		relayAddress = defaultRelayAddress
	}
	if strings.TrimSpace(relayPorts) == "" {
		relayPorts = defaultRelayPorts
	}
	if relayPassword == "" && relayAddress == defaultRelayAddress {
		relayPassword = defaultRelayPassword
	}

	ports := make([]string, 0, 5)
	for _, port := range strings.Split(relayPorts, ",") {
		if port = strings.TrimSpace(port); port != "" {
			ports = append(ports, port)
		}
	}

	return &Transfer{
		listener:      listener,
		relayAddress:  strings.TrimSpace(relayAddress),
		relayPorts:    ports,
		relayPassword: relayPassword,
	}
}

func GenerateCode() string {
	return utils.GetRandomName()
}

// Send blocks until all selected files are sent, canceled, or fail.
func (t *Transfer) Send(code, pathsJSON string) error {
	var paths []string
	if err := json.Unmarshal([]byte(pathsJSON), &paths); err != nil {
		return fmt.Errorf("invalid selected files: %w", err)
	}
	if len(paths) == 0 {
		return errors.New("select at least one file")
	}
	for i, path := range paths {
		absolute, err := filepath.Abs(path)
		if err != nil {
			return fmt.Errorf("resolve selected file: %w", err)
		}
		if _, err = os.Stat(absolute); err != nil {
			return fmt.Errorf("selected file is unavailable: %w", err)
		}
		paths[i] = absolute
	}

	return t.run(true, normalizeCode(code), func(client *croc.Client) error {
		files, emptyFolders, folderCount, err := croc.GetFilesInfo(paths, false, false, nil)
		if err != nil {
			return fmt.Errorf("inspect selected files: %w", err)
		}
		return client.Send(files, emptyFolders, folderCount)
	}, "Preparing files")
}

// Receive blocks and writes into the supplied app-private staging directory.
func (t *Transfer) Receive(code, stagingDirectory string) error {
	absolute, err := filepath.Abs(stagingDirectory)
	if err != nil {
		return fmt.Errorf("resolve receive directory: %w", err)
	}
	if err = os.MkdirAll(absolute, 0o700); err != nil {
		return fmt.Errorf("create receive directory: %w", err)
	}

	return t.run(false, normalizeCode(code), func(client *croc.Client) error {
		previous, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("read working directory: %w", err)
		}
		if err = os.Chdir(absolute); err != nil {
			return fmt.Errorf("open receive directory: %w", err)
		}
		defer os.Chdir(previous) // Best effort; the transfer lock prevents another session racing it.

		if err = client.Receive(); err != nil {
			return err
		}

		files := make([]receivedFile, 0, len(client.FilesToTransfer))
		for _, info := range client.FilesToTransfer {
			path := filepath.Join(absolute, filepath.FromSlash(info.FolderRemote), info.Name)
			files = append(files, receivedFile{Name: info.Name, Path: path, Size: info.Size})
		}
		t.emit(transferEvent{Type: "received", Files: files})
		return nil
	}, "Connecting to sender")
}

func (t *Transfer) Cancel() {
	t.mu.Lock()
	cancel := t.cancel
	t.mu.Unlock()
	if cancel != nil {
		cancel()
	}
}

func (t *Transfer) run(isSender bool, code string, operation func(*croc.Client) error, initialStage string) error {
	if len(code) < 6 {
		return errors.New("transfer code must be at least 6 characters")
	}

	t.mu.Lock()
	if t.active {
		t.mu.Unlock()
		return errors.New("a transfer is already active")
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.cancel = cancel
	t.active = true
	t.mu.Unlock()

	defer func() {
		cancel()
		t.mu.Lock()
		t.cancel = nil
		t.active = false
		t.mu.Unlock()
	}()

	processTransferMu.Lock()
	defer processTransferMu.Unlock()

	client, err := croc.NewCtx(ctx, croc.Options{
		IsSender:         isSender,
		SharedSecret:     code,
		RelayAddress:     t.relayAddress,
		RelayPorts:       t.relayPorts,
		RelayPassword:    t.relayPassword,
		NoPrompt:         true,
		DisableLocal:     true,
		IgnoreStdin:      true,
		Overwrite:        true,
		Quiet:            true,
		DisableClipboard: true,
		Curve:            "p256",
		HashAlgorithm:    "xxhash",
		MulticastAddress: "239.255.255.250",
	})
	if err != nil {
		return err
	}

	t.emit(transferEvent{Type: "stage", Stage: initialStage})
	done := make(chan struct{})
	go t.reportProgress(client, done)
	err = operation(client)
	close(done)

	if err != nil {
		canceled := errors.Is(err, context.Canceled) || errors.Is(ctx.Err(), context.Canceled)
		t.emit(transferEvent{Type: "failed", Message: err.Error(), WasCanceled: canceled})
		if canceled {
			return errors.New("transfer canceled")
		}
		return err
	}

	t.emit(transferEvent{Type: "complete"})
	return nil
}

func (t *Transfer) reportProgress(client *croc.Client, done <-chan struct{}) {
	ticker := time.NewTicker(150 * time.Millisecond)
	defer ticker.Stop()
	lastDone := int64(-1)
	lastIndex := -1

	for {
		select {
		case <-done:
			return
		case <-ticker.C:
			index := client.FilesToTransferCurrentNum
			if index < 0 || index >= len(client.FilesToTransfer) {
				continue
			}
			info := client.FilesToTransfer[index]
			transferred := client.TotalSent
			if transferred == lastDone && index == lastIndex {
				continue
			}
			lastDone, lastIndex = transferred, index
			t.emit(transferEvent{
				Type:      "progress",
				Name:      info.Name,
				Done:      transferred,
				Total:     info.Size,
				FileIndex: index,
				FileCount: len(client.FilesToTransfer),
			})
		}
	}
}

func (t *Transfer) emit(event transferEvent) {
	if t.listener == nil {
		return
	}
	payload, err := json.Marshal(event)
	if err == nil {
		t.listener.OnEvent(string(payload))
	}
}

func normalizeCode(code string) string {
	return strings.ReplaceAll(strings.TrimSpace(code), " ", "-")
}
