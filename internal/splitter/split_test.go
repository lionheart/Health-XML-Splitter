package splitter

import (
	"context"
	"encoding/xml"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSplitPreservesRecordsAndMetadata(t *testing.T) {
	directory := t.TempDir()
	input := `<?xml version="1.0"?><!DOCTYPE HealthData [<!ELEMENT HealthData ANY>]>
<HealthData locale="en_US"><ExportDate value="today"/>
<Record type="a" sourceName="A &amp; B"><MetadataEntry key="note" value="é 🫀"/>text &amp; more</Record>
<Workout duration="12"><WorkoutEvent type="pause"/></Workout><Record type="b"/></HealthData>`
	var events []Progress
	err := Split(context.Background(), strings.NewReader(input), Options{
		OutputDirectory: directory, Threshold: 3,
		Progress: func(p Progress) { events = append(events, p) },
	})
	if err != nil {
		t.Fatal(err)
	}
	files, err := filepath.Glob(filepath.Join(directory, "*.xml"))
	if err != nil || len(files) != 2 {
		t.Fatalf("expected two chunks, got %v (%v)", files, err)
	}
	var records, dates, workouts int
	var text strings.Builder
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		decoder := xml.NewDecoder(strings.NewReader(string(data)))
		for {
			token, err := decoder.Token()
			if err == io.EOF {
				break
			}
			if err != nil {
				t.Fatalf("invalid chunk: %v", err)
			}
			switch token := token.(type) {
			case xml.StartElement:
				switch token.Name.Local {
				case "HealthData":
					if len(token.Attr) != 1 || token.Attr[0].Value != "en_US" {
						t.Fatalf("root attributes were lost: %v", token.Attr)
					}
				case "ExportDate":
					dates++
				case "Record":
					records++
					if token.Attr[0].Value == "a" && token.Attr[1].Value != "A & B" {
						t.Fatalf("escaped attribute changed: %v", token.Attr)
					}
				case "MetadataEntry":
					if token.Attr[1].Value != "é 🫀" {
						t.Fatalf("Unicode metadata changed: %v", token.Attr)
					}
				case "Workout":
					workouts++
				}
			case xml.CharData:
				text.Write(token)
			}
		}
	}
	if records != 2 || dates != 2 || workouts != 1 || !strings.Contains(text.String(), "text & more") {
		t.Fatalf("lost content: records=%d dates=%d workouts=%d text=%q", records, dates, workouts, text.String())
	}
	if events[0].Phase != Started || events[len(events)-1].Phase != ChunkCompleted || events[len(events)-1].Part != 1 {
		t.Fatalf("unexpected progress: %v", events)
	}
}

func TestSplitDoesNotCreateEmptyTrailingChunk(t *testing.T) {
	directory := t.TempDir()
	err := Split(context.Background(), strings.NewReader(`<HealthData><Record/><Record/></HealthData>`), Options{
		OutputDirectory: directory, Threshold: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	files, _ := filepath.Glob(filepath.Join(directory, "*.xml"))
	if len(files) != 1 {
		t.Fatalf("expected one chunk, got %v", files)
	}
}

func TestSplitFailures(t *testing.T) {
	for _, input := range []string{
		`<HealthData><Record>`,
		`<HealthData><Record></HealthData>`,
		`<NotHealthData/>`,
		``,
		`<HealthData><Record value="&unknown;"/></HealthData>`,
	} {
		t.Run(input, func(t *testing.T) {
			directory := t.TempDir()
			err := Split(context.Background(), strings.NewReader(input), Options{OutputDirectory: directory, Threshold: 100})
			if err == nil {
				t.Fatal("expected an error")
			}
			files, _ := os.ReadDir(directory)
			if len(files) != 0 {
				t.Fatalf("unfinished output left behind: %v", files)
			}
		})
	}
}

func TestSplitProtectsExistingOutput(t *testing.T) {
	directory := t.TempDir()
	file := filepath.Join(directory, "export0.xml")
	if err := os.WriteFile(file, []byte("keep me"), 0o644); err != nil {
		t.Fatal(err)
	}
	err := Split(context.Background(), strings.NewReader(`<HealthData/>`), Options{OutputDirectory: directory, Threshold: 1})
	if err == nil {
		t.Fatal("expected output conflict")
	}
	data, _ := os.ReadFile(file)
	if string(data) != "keep me" {
		t.Fatalf("overwrote existing output: %q", data)
	}
}

func TestSplitCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	directory := t.TempDir()
	err := Split(ctx, strings.NewReader(`<HealthData><Record/><Record/></HealthData>`), Options{
		OutputDirectory: directory, Threshold: 100,
		Progress: func(p Progress) {
			if p.Phase == Updated {
				cancel()
			}
		},
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected cancellation, got %v", err)
	}
	files, _ := os.ReadDir(directory)
	if len(files) != 0 {
		t.Fatalf("unfinished output left behind: %v", files)
	}
}

func TestSanitizerDoesNotTruncateAtRemovedBuffer(t *testing.T) {
	reader := &sanitizingReader{r: strings.NewReader("\x00\x01\x18é\t\n\r🙂")}
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

func TestSplitSanitizesControlCharacters(t *testing.T) {
	directory := t.TempDir()
	err := Split(context.Background(), strings.NewReader("<HealthData><Record value=\"a\x00\x18é\"/></HealthData>"), Options{
		OutputDirectory: directory, Threshold: 10,
	})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(filepath.Join(directory, "export0.xml"))
	if !strings.Contains(string(data), `value="aé"`) {
		t.Fatalf("unexpected output: %s", data)
	}
}
