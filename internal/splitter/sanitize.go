package splitter

import "io"

// sanitizingReader removes the invalid ASCII control characters found in some
// Health exports. UTF-8 bytes pass through for the XML decoder to validate.
type sanitizingReader struct {
	r io.Reader
}

func (r *sanitizingReader) Read(p []byte) (int, error) {
	for {
		n, err := r.r.Read(p)
		valid := 0
		for _, b := range p[:n] {
			if b == '\t' || b == '\n' || b == '\r' || b >= 0x20 {
				p[valid] = b
				valid++
			}
		}
		// A buffer containing only removed characters is not EOF.
		if valid > 0 || err != nil || len(p) == 0 {
			return valid, err
		}
	}
}
