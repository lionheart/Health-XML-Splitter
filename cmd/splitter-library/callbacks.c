#include "callbacks.h"

void splitterReport(SplitterProgress callback, void *context, int phase,
                    int64_t part, int64_t current, int64_t total) {
    if (callback) {
        callback(context, phase, part, current, total);
    }
}
