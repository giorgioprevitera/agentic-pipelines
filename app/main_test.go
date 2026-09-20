package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	healthHandler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"status":"ok"`) {
		t.Errorf("expected status:ok in body, got: %s", w.Body.String())
	}
}

func TestHelloHandler_Default(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/hello", nil)
	w := httptest.NewRecorder()

	helloHandler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "Hello, world!") {
		t.Errorf("expected Hello, world! in body, got: %s", w.Body.String())
	}
}

func TestHelloHandler_WithName(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/hello?name=Giorgio", nil)
	w := httptest.NewRecorder()

	helloHandler(w, req)

	if !strings.Contains(w.Body.String(), "Hello, Giorgio!") {
		t.Errorf("expected Hello, Giorgio! in body, got: %s", w.Body.String())
	}
}

func TestRootHandler_NotFound(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/nonexistent", nil)
	w := httptest.NewRecorder()

	rootHandler(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}
