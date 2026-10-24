// storage.h — the dose log on the microSD card (Phase 2).
//
// Every taken or missed dose becomes one JSON line in LOG_FILE, with a `seq`
// number that never repeats (kept in flash). The phone collects the events
// after the last one it acknowledged (Phase 3, over Bluetooth), so a repeated
// sync never creates a duplicate. Without a card, events wait in flash
// (LOG_FALLBACK_MAX) and move to the card at the next boot that finds one.
#pragma once
#include <stdint.h>

enum DoseEventType : uint8_t { EV_TAKEN = 1, EV_MISSED = 2 };
// TIMING_EARLY is kept for the stored format; the box no longer takes doses early.
enum DoseTiming    : uint8_t { TIMING_NONE = 0, TIMING_ON_TIME, TIMING_LATE, TIMING_EARLY };

struct DoseEvent {
    uint32_t seq;
    uint32_t doseLocal;     // the dose's own time (Manila, seconds since 1970)
    uint32_t atUtc;         // when it was taken, or marked missed
    uint8_t  type;          // DoseEventType
    uint8_t  compartment;   // 1–6
    uint8_t  timing;        // DoseTiming
    char     sid[25];       // the app's schedule id ("" until the phone sends it)
};

bool storage_begin();      // false = no SD card (events go to the flash fallback)
bool storage_sd_ok();

// Records one event and returns its seq.
uint32_t storage_log(DoseEventType type, uint8_t compartment, uint32_t doseLocal, uint32_t atUtc,
                     DoseTiming timing, const char *sid);

uint32_t storage_last_seq();
uint32_t storage_acked_seq();
uint32_t storage_pending();            // events the phone has not collected yet
bool     storage_ack(uint32_t seq);    // the phone has everything up to `seq`

// Phase 3: calls `fn(line)` for each event with seq > `after`, oldest first,
// at most `max` of them, each as the same JSON line as in the log file.
// Returns how many were passed to `fn`.
int storage_events_after(uint32_t after, int max, void (*fn)(const char *line));

void storage_print_last(int count);    // console: the last `count` events
void storage_print_info();             // console: card status
