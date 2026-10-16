package splitter

import (
	"context"
	"io"
)

// sanitizingReader removes the invalid ASCII control characters found in some
// Health exports. UTF-8 bytes pass through for the XML decoder to validate.
type sanitizingReader struct {
	ctx context.Context
	r   io.Reader
}

func newSanitizingReader(ctx context.Context, r io.Reader) *sanitizingReader {
	return &sanitizingReader{ctx: ctx, r: r}
}

func (r *sanitizingReader) Read(p []byte) (int, error) {
	for {
		if err := r.ctx.Err(); err != nil {
			return 0, err
		}
		n, err := r.r.Read(p)
		valid := 0
		for _, b := range p[:n] {
			if b == '\t' || b == '\n' || b == '\r' || b >= 0x20 {
				p[valid] = b
				valid++
			}
		}
		// A buffer containing only removed characters is not EOF.
		if valid > 0 || err != nil || n == 0 {
			return valid, err
		}
	}
}
