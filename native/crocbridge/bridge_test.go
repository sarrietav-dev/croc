package crocbridge

import "testing"

func TestNormalizeCode(t *testing.T) {
	if got := normalizeCode("  alpha beta gamma  "); got != "alpha-beta-gamma" {
		t.Fatalf("normalizeCode() = %q", got)
	}
}

func TestGenerateCode(t *testing.T) {
	if code := GenerateCode(); len(code) < 6 {
		t.Fatalf("GenerateCode() returned a short code: %q", code)
	}
}
