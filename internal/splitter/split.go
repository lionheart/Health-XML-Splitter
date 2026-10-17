// Package splitter splits Health XML exports independently of the host UI.
package splitter

import (
	"context"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
)

// Phase identifies a progress event.
type Phase int

const (
	Started Phase = iota
	Updated
	Saving
	ChunkCompleted
)

// Progress describes the current zero-based chunk and its element count.
type Progress struct {
	Phase   Phase
	Part    int
	Current int
	Total   int
}

// Options controls output. Threshold counts all closed elements, including
// nested elements, matching the original Swift splitter. A chunk ends after
// exceeding Threshold, at the next complete child of HealthData.
type Options struct {
	OutputDirectory string
	Threshold       int
	Progress        func(Progress)
}

// SplitFile splits an XML file. Existing output files are never overwritten.
func SplitFile(ctx context.Context, filename string, options Options) (err error) {
	f, err := os.Open(filename)
	if err != nil {
		return fmt.Errorf("open input: %w", err)
	}
	defer func() {
		if closeErr := f.Close(); closeErr != nil {
			err = errors.Join(err, fmt.Errorf("close input: %w", closeErr))
		}
	}()
	return Split(ctx, f, options)
}

// Split streams complete top-level records into exportN.xml files, preserving
// the root attributes and repeating ExportDate in subsequent chunks. On failure
// the unfinished chunk is removed; already completed chunks remain available.
// Structurally malformed XML returns an error rather than silently recovering.
func Split(ctx context.Context, input io.Reader, options Options) (err error) {
	if options.Threshold <= 0 {
		return fmt.Errorf("threshold must be positive")
	}
	if options.OutputDirectory == "" {
		return fmt.Errorf("output directory is required")
	}
	if err := os.MkdirAll(options.OutputDirectory, 0o755); err != nil {
		return fmt.Errorf("create output directory: %w", err)
	}
	s := &session{options: options}
	defer func() { err = errors.Join(err, s.abort()) }()
	s.report(Started)
	decoder := xml.NewDecoder(newSanitizingReader(ctx, input))
	depth := 0
	rootClosed := false
	capturingDate := false
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		token, err := decoder.Token()
		if err == io.EOF {
			if !rootClosed {
				return fmt.Errorf("input ended before HealthData was closed")
			}
			return nil
		}
		if err != nil {
			return fmt.Errorf("parse xml: %w", err)
		}
		if depth == 0 {
			switch t := token.(type) {
			case xml.StartElement:
				if rootClosed || t.Name.Local != "HealthData" {
					return fmt.Errorf("expected a single HealthData root")
				}
				s.root = xml.CopyToken(t).(xml.StartElement)
				depth = 1
			case xml.CharData:
				if !whitespace(t) {
					return fmt.Errorf("unexpected text outside HealthData")
				}
			}
			continue
		}
		// Ignore formatting whitespace between records, including after a split.
		if t, ok := token.(xml.CharData); ok && depth == 1 && whitespace(t) {
			continue
		}
		if _, ok := token.(xml.EndElement); ok && depth == 1 {
			if s.file == nil && s.part == 0 {
				if err := s.open(); err != nil {
					return err
				}
			}
			if err := s.finish(); err != nil {
				return err
			}
			depth = 0
			rootClosed = true
			continue
		}
		if s.file == nil {
			switch token.(type) {
			case xml.Comment, xml.ProcInst:
				continue
			}
			if err := s.open(); err != nil {
				return err
			}
		}
		if t, ok := token.(xml.StartElement); ok {
			if depth == 1 && t.Name.Local == "ExportDate" && len(s.exportDate) == 0 {
				capturingDate = true
			}
			depth++
		}
		if capturingDate {
			s.exportDate = append(s.exportDate, xml.CopyToken(token))
		}
		if err := s.encoder.EncodeToken(token); err != nil {
			return fmt.Errorf("write xml: %w", err)
		}
		if _, ok := token.(xml.EndElement); ok {
			depth--
			s.count++
			// Report only at complete record boundaries, avoiding callbacks for
			// every nested metadata element.
			if depth == 1 {
				capturingDate = false
				s.report(Updated)
				if s.count > options.Threshold {
					if err := s.finish(); err != nil {
						return err
					}
				}
			}
		}
	}
}

func whitespace(data []byte) bool {
	for _, b := range data {
		if b != ' ' && b != '\t' && b != '\r' && b != '\n' {
			return false
		}
	}
	return true
}
