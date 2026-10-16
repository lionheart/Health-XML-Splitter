// Package healthsplitter exposes a small gomobile-compatible API for native UIs.
package healthsplitter

import (
	"context"
	"fmt"

	"github.com/lionheart/Health-XML-Splitter/internal/splitter"
)

// Progress receives synchronous events on the thread calling SplitFile. The
// listener is held only for that call; native UIs must dispatch UI updates to
// their main thread. Chunk indices are zero-based.
type Progress interface {
	Started()
	Updated(part, current, total int64)
	Saving(part int64)
	ChunkCompleted(part int64)
}

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
		options.Progress = func(p splitter.Progress) {
			switch p.Phase {
			case splitter.Started:
				progress.Started()
			case splitter.Updated:
				progress.Updated(int64(p.Part), int64(p.Current), int64(p.Total))
			case splitter.Saving:
				progress.Saving(int64(p.Part))
			case splitter.ChunkCompleted:
				progress.ChunkCompleted(int64(p.Part))
			}
		}
	}
	return splitter.SplitFile(context.Background(), filename, options)
}
