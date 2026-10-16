package splitter

import (
	"encoding/xml"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestAbortReportsCloseFailureAndStillRemovesUnfinishedChunk(t *testing.T) {
	directory := t.TempDir()
	s := &session{options: Options{OutputDirectory: directory}, root: xml.StartElement{Name: xml.Name{Local: "HealthData"}}}
	if err := s.open(); err != nil {
		t.Fatal(err)
	}
	if err := s.file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := s.abort(); !errors.Is(err, os.ErrClosed) {
		t.Fatalf("expected close failure, got %v", err)
	}
	if _, err := os.Stat(filepath.Join(directory, "export0.xml")); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("unfinished chunk was not removed: %v", err)
	}
}

func TestAbortReportsRemovalFailure(t *testing.T) {
	// A nonempty directory provides a portable removal failure without relying
	// on permissions that differ when tests run as root.
	path := t.TempDir()
	if err := os.WriteFile(filepath.Join(path, "keep"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	s := &session{filename: path}
	err := s.abort()
	if pathErr, ok := errors.AsType[*os.PathError](err); !ok || pathErr.Op != "remove" {
		t.Fatalf("expected the removal error, got %v", err)
	}
}
