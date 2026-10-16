#ifndef HEALTH_SPLITTER_H
#define HEALTH_SPLITTER_H

#include <stdint.h>

// Events are delivered synchronously on the calling thread. Context is opaque,
// owned by the caller, and retained only for the duration of SplitterSplitXML.
enum {
    SplitterStarted = 0,
    SplitterUpdated = 1,
    SplitterSaving = 2,
    SplitterChunkCompleted = 3
};
typedef void (*SplitterProgress)(void *context, int phase, int64_t part,
                                 int64_t current, int64_t total);

// UTF-8 paths are borrowed for the call. Threshold must be positive.
// Returns NULL on success, otherwise an owned UTF-8 error string.
char *SplitterSplitXML(char *input, char *output, int64_t threshold,
                       SplitterProgress progress, void *context);
void SplitterFreeString(char *string);

#endif
