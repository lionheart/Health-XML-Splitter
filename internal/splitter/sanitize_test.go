package splitter

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"
)

func TestSanitizerDoesNotTruncateAtRemovedBuffer(t *testing.T) {
	reader := newSanitizingReader(context.Background(), strings.NewReader("\x00\x01\x18é\t\n\r🙂"))
	var result strings.Builder
	buffer := make([]byte, 1)
	for {
		n, err := reader.Read(buffer)
		result.Write(buffer[:n])
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
	}
	if result.String() != "é\t\n\r🙂" {
		t.Fatalf("unexpected sanitized data: %q", result.String())
	}
}

func TestSanitizerCancellationWhileRemovingControls(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader := newSanitizingReader(ctx, &cancelingReader{cancel: cancel})
	if _, err := reader.Read(make([]byte, 1)); !errors.Is(err, context.Canceled) {
		t.Fatalf("expected cancellation, got %v", err)
	}
}

type cancelingReader struct {
	cancel context.CancelFunc
}

func (r *cancelingReader) Read(p []byte) (int, error) {
	p[0] = 0
	r.cancel()
	return 1, nil
}
