package healthsplitter

import (
	"time"

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

// Bound callbacks into native code so large exports do not enqueue a UI update
// for every record. Chunk boundaries and lifecycle events are always delivered.
const progressInterval = 50 * time.Millisecond

type progressReporter struct {
	listener   Progress
	lastUpdate time.Time
	lastPart   int
}

func (r *progressReporter) report(p splitter.Progress, now time.Time) {
	switch p.Phase {
	case splitter.Started:
		r.listener.Started()
	case splitter.Updated:
		if !r.lastUpdate.IsZero() && p.Part == r.lastPart && p.Current < p.Total && now.Sub(r.lastUpdate) < progressInterval {
			return
		}
		r.lastUpdate = now
		r.lastPart = p.Part
		r.listener.Updated(int64(p.Part), int64(p.Current), int64(p.Total))
	case splitter.Saving:
		r.listener.Saving(int64(p.Part))
	case splitter.ChunkCompleted:
		r.listener.ChunkCompleted(int64(p.Part))
	}
}
