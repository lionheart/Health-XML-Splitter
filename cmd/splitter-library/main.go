// Command splitter-library exposes the Go engine through a small C ABI.
package main

/*
#include <stdlib.h>
#include "callbacks.h"
*/
import "C"

import (
	"context"
	"unsafe"

	"github.com/lionheart/Health-XML-Splitter/internal/splitter"
)

//export SplitterSplitXML
func SplitterSplitXML(input, output *C.char, threshold C.int64_t, progress C.SplitterProgress, userContext unsafe.Pointer) *C.char {
	if input == nil || output == nil {
		return C.CString("input and output paths are required")
	}
	if threshold <= 0 || uint64(threshold) > uint64(^uint(0)>>1) {
		return C.CString("threshold is out of range")
	}
	err := splitter.SplitFile(context.Background(), C.GoString(input), splitter.Options{
		OutputDirectory: C.GoString(output),
		Threshold:       int(threshold),
		Progress: func(p splitter.Progress) {
			C.splitterReport(progress, userContext, C.int(p.Phase), C.int64_t(p.Part), C.int64_t(p.Current), C.int64_t(p.Total))
		},
	})
	if err != nil {
		return C.CString(err.Error())
	}
	return nil
}

//export SplitterFreeString
func SplitterFreeString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

func main() {}
