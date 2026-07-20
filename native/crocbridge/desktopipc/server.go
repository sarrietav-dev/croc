package desktopipc

import (
	"bufio"
	"encoding/json"
	"errors"
	"io"
	"sync"

	"dev.sarrietav/crocbridge"
)

type request struct {
	Method           string   `json:"method"`
	Code             string   `json:"code,omitempty"`
	Paths            []string `json:"paths,omitempty"`
	StagingDirectory string   `json:"stagingDirectory,omitempty"`
	RelayAddress     string   `json:"relayAddress,omitempty"`
	RelayPorts       string   `json:"relayPorts,omitempty"`
	RelayPassword    string   `json:"relayPassword,omitempty"`
}

type listener struct {
	mu       sync.Mutex
	out      io.Writer
	terminal bool
}

func (l *listener) OnEvent(event string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	_, _ = io.WriteString(l.out, event+"\n")
	var payload struct {
		Type string `json:"type"`
	}
	if json.Unmarshal([]byte(event), &payload) == nil {
		l.terminal = payload.Type == "failed" || payload.Type == "complete"
	}
}

func (l *listener) hasTerminalEvent() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.terminal
}

// Serve runs one transfer and accepts cancellation requests until it finishes.
func Serve(in io.Reader, out io.Writer) error {
	decoder := json.NewDecoder(bufio.NewReader(in))
	var initial request
	if err := decoder.Decode(&initial); err != nil {
		return err
	}
	if initial.Method != "send" && initial.Method != "receive" {
		emitFailure(out, "unknown transfer method")
		return nil
	}

	events := &listener{out: out}
	transfer := crocbridge.NewTransfer(
		events,
		initial.RelayAddress,
		initial.RelayPorts,
		initial.RelayPassword,
	)
	done := make(chan error, 1)
	go func() {
		if initial.Method == "send" {
			paths, err := json.Marshal(initial.Paths)
			if err != nil {
				done <- err
				return
			}
			done <- transfer.Send(initial.Code, string(paths))
			return
		}
		done <- transfer.Receive(initial.Code, initial.StagingDirectory)
	}()

	cancelRequests := make(chan struct{})
	go func() {
		defer close(cancelRequests)
		for {
			var next request
			if err := decoder.Decode(&next); err != nil {
				return
			}
			if next.Method == "cancel" {
				cancelRequests <- struct{}{}
			}
		}
	}()

	for {
		select {
		case _, open := <-cancelRequests:
			if !open {
				cancelRequests = nil
				continue
			}
			transfer.Cancel()
		case err := <-done:
			if err != nil && !errors.Is(err, io.EOF) && !events.hasTerminalEvent() {
				emitFailure(out, err.Error())
			}
			return nil
		}
	}
}

func emitFailure(out io.Writer, message string) {
	payload, _ := json.Marshal(map[string]any{
		"type":    "failed",
		"message": message,
	})
	_, _ = out.Write(append(payload, '\n'))
}
