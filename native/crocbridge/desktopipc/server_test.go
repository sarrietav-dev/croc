package desktopipc

import (
	"bytes"
	"strings"
	"testing"
)

func TestServeRejectsUnknownMethod(t *testing.T) {
	var out bytes.Buffer
	err := Serve(strings.NewReader(`{"method":"unknown"}`), &out)

	if err != nil {
		t.Fatalf("Serve() returned an error: %v", err)
	}
	if !strings.Contains(out.String(), `"type":"failed"`) {
		t.Fatalf("Serve() output = %q", out.String())
	}
}

func TestServeReportsInvalidSendRequest(t *testing.T) {
	var out bytes.Buffer
	err := Serve(strings.NewReader(`{"method":"send","code":"valid-code"}`), &out)

	if err != nil {
		t.Fatalf("Serve() returned an error: %v", err)
	}
	if !strings.Contains(out.String(), "select at least one file") {
		t.Fatalf("Serve() output = %q", out.String())
	}
}
