package splitter

import (
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type session struct {
	options    Options
	root       xml.StartElement
	exportDate []xml.Token
	file       *os.File
	filename   string
	encoder    *xml.Encoder
	part       int
	count      int
}

func (s *session) report(phase Phase) {
	if s.options.Progress != nil {
		s.options.Progress(Progress{Phase: phase, Part: s.part, Current: s.count, Total: s.options.Threshold})
	}
}

func (s *session) open() error {
	filename := filepath.Join(s.options.OutputDirectory, fmt.Sprintf("export%d.xml", s.part))
	f, err := os.OpenFile(filename, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
	if err != nil {
		return fmt.Errorf("create chunk %q: %w", filename, err)
	}
	s.file = f
	s.filename = filename
	s.encoder = xml.NewEncoder(f)
	if _, err := io.WriteString(f, xml.Header); err != nil {
		return fmt.Errorf("write xml header: %w", err)
	}
	if err := s.encoder.EncodeToken(s.root); err != nil {
		return fmt.Errorf("write root: %w", err)
	}
	if s.part > 0 {
		for _, token := range s.exportDate {
			if err := s.encoder.EncodeToken(token); err != nil {
				return fmt.Errorf("write export date: %w", err)
			}
		}
	}
	return nil
}

func (s *session) finish() error {
	if s.file == nil {
		return nil
	}
	s.report(Saving)
	if err := s.encoder.EncodeToken(s.root.End()); err != nil {
		return fmt.Errorf("close root: %w", err)
	}
	if err := s.encoder.Close(); err != nil {
		return fmt.Errorf("flush xml: %w", err)
	}
	f := s.file
	s.file = nil
	if err := f.Close(); err != nil {
		return fmt.Errorf("close chunk %q: %w", s.filename, err)
	}
	s.filename = ""
	s.report(ChunkCompleted)
	s.part++
	s.count = 0
	return nil
}

// abort removes only the unfinished file owned by this session. A closed file
// can still need removal when closing it failed.
func (s *session) abort() error {
	var closeErr, removeErr error
	if s.file != nil {
		if err := s.file.Close(); err != nil {
			closeErr = fmt.Errorf("close unfinished chunk: %w", err)
		}
		s.file = nil
	}
	if s.filename != "" {
		if err := os.Remove(s.filename); err != nil && !errors.Is(err, os.ErrNotExist) {
			removeErr = fmt.Errorf("remove unfinished chunk %q: %w", s.filename, err)
		}
		s.filename = ""
	}
	return errors.Join(closeErr, removeErr)
}
