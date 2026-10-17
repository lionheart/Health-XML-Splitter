package healthsplitter

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestEngineAllowsNoProgressListener(t *testing.T) {
	directory := t.TempDir()
	input := filepath.Join(directory, "input.xml")
	if err := os.WriteFile(input, []byte(`<HealthData><Record/></HealthData>`), 0o644); err != nil {
		t.Fatal(err)
	}
	engine := &Engine{}
	output := filepath.Join(directory, "output")
	if err := engine.SplitFile(input, output, 10, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(output, "export0.xml")); err != nil {
		t.Fatal(err)
	}
}

func TestEnginePreservesFileError(t *testing.T) {
	engine := &Engine{}
	input := filepath.Join(t.TempDir(), "missing.xml")
	err := engine.SplitFile(input, t.TempDir(), 10, nil)
	if pathErr, ok := errors.AsType[*os.PathError](err); !ok || pathErr.Path != input || !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("expected input file error, got %v", err)
	}
}
