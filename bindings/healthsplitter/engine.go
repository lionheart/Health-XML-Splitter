// Package healthsplitter exposes a small gomobile-compatible API for native UIs.
package healthsplitter

import (
	"context"
	"fmt"
	"time"

	"github.com/lionheart/Health-XML-Splitter/internal/splitter"
)

// Engine provides Objective-C methods that Swift imports with throws support.
// Its zero value is ready to use; each SplitFile call owns its processing session.
type Engine struct{}

// SplitFile splits a Health XML export. A returned error becomes an NSError in
// the generated Objective-C bindings and a thrown error when called from Swift.
func (e *Engine) SplitFile(filename, outputDirectory string, threshold int64, progress Progress) error {
	if threshold <= 0 || uint64(threshold) > uint64(^uint(0)>>1) {
		return fmt.Errorf("threshold is out of range")
	}
	options := splitter.Options{OutputDirectory: outputDirectory, Threshold: int(threshold)}
	if progress != nil {
		reporter := &progressReporter{listener: progress}
		options.Progress = func(p splitter.Progress) { reporter.report(p, time.Now()) }
	}
	if err := splitter.SplitFile(context.Background(), filename, options); err != nil {
		return fmt.Errorf("split export %q: %w", filename, err)
	}
	return nil
}
