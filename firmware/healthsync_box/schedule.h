// schedule.h — the dose times stored on the box, and which doses are due.
//
// Works in Manila local time, as seconds since 1970 (rtc_now_local()).
// Entries and the taken/missed record live in the ESP32's flash
// (Preferences), so they survive power cuts. Phase 3 lets the phone write the
// entries over Bluetooth; until then the bench console does.
#pragma once
#include <stdint.h>

// Day bits: bit 0 = Monday … bit 6 = Sunday.
static const uint8_t DAYS_EVERY = 0x7F;

struct ScheduleEntry {
    uint32_t since;        // local time it was added: earlier dose times are ignored
    uint16_t minute;       // minute of the day, 0–1439
    uint8_t  compartment;  // 1–LED_COUNT
    uint8_t  days;         // day bits
    char     sid[25];      // the app's schedule id (Phase 3, from the phone); "" from the console
};

void schedule_begin();     // load from flash

int                  schedule_count();
const ScheduleEntry &schedule_get(int index);          // 0-based
bool                 schedule_add(uint8_t compartment, uint16_t minute, uint8_t days, uint32_t nowLocal,
                                  const char *sid = "");
bool                 schedule_remove(int index);       // 0-based
void                 schedule_clear();                 // entries and the taken/missed record

// Which compartments are due now (bit 0 = compartment 1). Doses whose 60-minute
// window has passed are recorded as missed (once). Every taken or missed dose
// is also written to the dose log (storage.h).
uint8_t schedule_update(uint32_t nowLocal);

// Whether the buzzer should sound: a lit dose whose time was less than
// ALARM_BEEP_FOR_MIN ago. After that the LED stays lit, silently (Oct 31).
// Measured from the dose time, so a restart mid-alarm does not beep longer.
bool schedule_beeping(uint32_t nowLocal);

// The button. Marks every due (lit) dose taken and returns their compartments,
// or 0 if none is due. Doses that are not lit yet are never taken early: a
// press before the alarm may be an accident (Oct 25).
uint8_t schedule_take(uint32_t nowLocal);

// ── Phone sync (Phase 3) ─────────────────────────────────────────────────────
// The phone replaces the whole schedule in one step: begin, one item per dose
// time, commit. Nothing changes until commit, and commit fails if the number of
// items differs from `count`. Entries that did not change keep their "added"
// time, so a re-sync never stops a dose that is due right now from lighting.
void        schedule_sync_begin(const char *version, int count);
bool        schedule_sync_item(const char *sid, uint8_t compartment, uint16_t minute, uint8_t days);
int         schedule_sync_commit(uint32_t nowLocal);   // entry count, or -1 (see schedule_sync_error)
const char *schedule_sync_error();
const char *schedule_version();                        // "" until the phone sends one

// The dose was taken or skipped in the app: stop its alarm without logging it
// again on the box. False if no entry has that sid and time on that day.
bool schedule_app_done(const char *sid, uint32_t day, uint16_t minute);

// For the console: one line per entry with today's state.
void schedule_print(uint32_t nowLocal);

// "Mon,Wed,Fri" or "every day".
void schedule_days_text(uint8_t days, char *buf, int len);
