package healthsplitter

import (
	"fmt"
	"slices"
	"testing"
	"time"

	"github.com/lionheart/Health-XML-Splitter/internal/splitter"
)

func TestProgressThrottlesUpdatesAndPreservesChunkEvents(t *testing.T) {
	listener := &progressLog{}
	reporter := &progressReporter{listener: listener}
	start := time.Date(2026, time.October, 16, 12, 0, 0, 0, time.UTC)
	for _, event := range []struct {
		after   time.Duration
		phase   splitter.Phase
		part    int
		current int
	}{
		{0, splitter.Started, 0, 0},
		{0, splitter.Updated, 0, 1},
		{time.Millisecond, splitter.Updated, 0, 2},
		{progressInterval, splitter.Updated, 0, 3},
		{progressInterval, splitter.Updated, 0, 101},
		{progressInterval, splitter.Saving, 0, 101},
		{progressInterval, splitter.ChunkCompleted, 0, 101},
		{progressInterval, splitter.Updated, 1, 1},
	} {
		reporter.report(splitter.Progress{Phase: event.phase, Part: event.part, Current: event.current, Total: 100}, start.Add(event.after))
	}
	want := []string{"started", "updated:0:1", "updated:0:3", "updated:0:101", "saving:0", "completed:0", "updated:1:1"}
	if !slices.Equal(listener.events, want) {
		t.Fatalf("events = %v, want %v", listener.events, want)
	}
}

var _ Progress = (*progressLog)(nil)

type progressLog struct {
	events []string
}

func (p *progressLog) Started() { p.events = append(p.events, "started") }

func (p *progressLog) Updated(part, current, total int64) {
	p.events = append(p.events, fmt.Sprintf("updated:%d:%d", part, current))
}

func (p *progressLog) Saving(part int64) {
	p.events = append(p.events, fmt.Sprintf("saving:%d", part))
}

func (p *progressLog) ChunkCompleted(part int64) {
	p.events = append(p.events, fmt.Sprintf("completed:%d", part))
}
