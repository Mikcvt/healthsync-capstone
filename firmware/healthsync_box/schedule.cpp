// schedule.cpp
#include "schedule.h"
#include "config.h"
#include "storage.h"
#include <Arduino.h>
#include <Preferences.h>

// A dose already dealt with: which day, which time, which compartment.
struct Handled {
    uint32_t day;          // local days since 1970
    uint16_t minute;
    uint8_t  compartment;
    uint8_t  status;       // 0 = empty slot, ST_TAKEN, ST_MISSED
};

static const uint8_t ST_TAKEN  = 1;
static const uint8_t ST_MISSED = 2;
static const uint8_t ST_APP    = 3;   // handled in the app: alarm off, not logged on the box
static const int     HANDLED_MAX   = 48;   // 2 days × 24 dose times
static const uint8_t STORE_VERSION = 2;    // bump if the structs change (2: sid added, Phase 2)

static const uint32_t DAY_S = 86400UL;

static ScheduleEntry _entries[MAX_SCHEDULES];
static int           _count = 0;
static Handled       _handled[HANDLED_MAX];
static int           _handledNext = 0;
static Preferences   _prefs;

// Phone sync in progress (Phase 3).
static ScheduleEntry _staged[MAX_SCHEDULES];
static int           _stagedCount    = 0;
static int           _stagedExpected = -1;   // -1 = no sync in progress
static bool          _stagedOverflow = false;
static char          _stagedVersion[32] = "";
static char          _version[32]       = "";
static const char   *_syncError         = "";

static const char *DAY_NAMES[7] = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};

// ── storage ──────────────────────────────────────────────────────────────────

static void saveEntries() {
    _prefs.putBytes("entries", _entries, sizeof(ScheduleEntry) * _count);
    _prefs.putInt("count", _count);
}

static void saveHandled() {
    _prefs.putBytes("handled", _handled, sizeof(_handled));
    _prefs.putInt("hnext", _handledNext);
}

void schedule_begin() {
    _prefs.begin("schedule", false);
    if (_prefs.getUChar("version", 0) != STORE_VERSION) {
        _prefs.clear();
        _prefs.putUChar("version", STORE_VERSION);
    }
    _count = _prefs.getInt("count", 0);
    if (_count < 0 || _count > MAX_SCHEDULES) _count = 0;
    if (_count > 0) _prefs.getBytes("entries", _entries, sizeof(ScheduleEntry) * _count);
    if (_prefs.getBytes("handled", _handled, sizeof(_handled)) != sizeof(_handled)) {
        memset(_handled, 0, sizeof(_handled));
    }
    _handledNext = _prefs.getInt("hnext", 0) % HANDLED_MAX;
    _prefs.getString("ver", _version, sizeof(_version));
}

// ── helpers ──────────────────────────────────────────────────────────────────

// 1970-01-01 was a Thursday; with Monday = 0 that is weekday 3.
static uint8_t weekday(uint32_t day) { return (day + 3) % 7; }

static bool runsOn(const ScheduleEntry &e, uint32_t day) {
    return (e.days >> weekday(day)) & 1;
}

static uint8_t findHandled(uint32_t day, uint16_t minute, uint8_t compartment) {
    for (const Handled &h : _handled) {
        if (h.status && h.day == day && h.minute == minute && h.compartment == compartment) {
            return h.status;
        }
    }
    return 0;
}

static void markHandled(uint32_t day, uint16_t minute, uint8_t compartment, uint8_t status) {
    _handled[_handledNext] = {day, minute, compartment, status};
    _handledNext = (_handledNext + 1) % HANDLED_MAX;
    saveHandled();
}

// Prints the dose and writes it to the dose log (SD card, or flash without one).
static void recordDose(DoseEventType type, const ScheduleEntry &e, uint32_t day, uint32_t nowLocal,
                       DoseTiming timing, const char *note) {
    Serial.printf("Dose %s: compartment %u, %02u:%02u (day %lu)%s%s\n",
                  type == EV_TAKEN ? "TAKEN" : "MISSED", e.compartment, e.minute / 60,
                  e.minute % 60, (unsigned long)day, note ? ", " : "", note ? note : "");
    storage_log(type, e.compartment, day * DAY_S + e.minute * 60UL,
                nowLocal - TZ_OFFSET_MIN * 60UL, timing, e.sid);
}

// Call `fn(entry, day, start)` for each dose of each entry that falls on one of
// the days today + fromOffset … today + toOffset and is not before the entry was
// added.
template <typename Fn>
static void forEachDose(uint32_t nowLocal, int fromOffset, int toOffset, Fn fn) {
    uint32_t today = nowLocal / DAY_S;
    for (int i = 0; i < _count; i++) {
        const ScheduleEntry &e = _entries[i];
        for (int off = fromOffset; off <= toOffset; off++) {
            uint32_t day = today + off;
            if (!runsOn(e, day)) continue;
            uint32_t start = day * DAY_S + e.minute * 60UL;
            if (start < e.since) continue;   // before this dose time was added
            fn(e, day, start);
        }
    }
}

// ── entries ──────────────────────────────────────────────────────────────────

int schedule_count() { return _count; }

const ScheduleEntry &schedule_get(int index) { return _entries[index]; }

bool schedule_add(uint8_t compartment, uint16_t minute, uint8_t days, uint32_t nowLocal,
                  const char *sid) {
    if (_count >= MAX_SCHEDULES || compartment < 1 || compartment > LED_COUNT || minute >= 1440 ||
        days == 0) {
        return false;
    }
    ScheduleEntry &e = _entries[_count++];
    e = {};
    e.since       = nowLocal;
    e.minute      = minute;
    e.compartment = compartment;
    e.days        = days;
    strncpy(e.sid, sid ? sid : "", sizeof(e.sid) - 1);
    saveEntries();
    return true;
}

bool schedule_remove(int index) {
    if (index < 0 || index >= _count) return false;
    for (int i = index; i < _count - 1; i++) _entries[i] = _entries[i + 1];
    _count--;
    saveEntries();
    return true;
}

void schedule_clear() {
    _count = 0;
    memset(_handled, 0, sizeof(_handled));
    _handledNext = 0;
    _version[0] = 0;
    _prefs.putString("ver", _version);
    saveEntries();
    saveHandled();
}

// ── phone sync ───────────────────────────────────────────────────────────────

void schedule_sync_begin(const char *version, int count) {
    _stagedCount    = 0;
    _stagedExpected = count;
    _stagedOverflow = false;
    strncpy(_stagedVersion, version ? version : "", sizeof(_stagedVersion) - 1);
    _stagedVersion[sizeof(_stagedVersion) - 1] = 0;
}

bool schedule_sync_item(const char *sid, uint8_t compartment, uint16_t minute, uint8_t days) {
    if (_stagedExpected < 0 || compartment < 1 || compartment > LED_COUNT || minute >= 1440 ||
        days == 0) {
        return false;
    }
    if (_stagedCount >= MAX_SCHEDULES) {
        _stagedOverflow = true;
        return false;
    }
    ScheduleEntry &e = _staged[_stagedCount++];
    e = {};
    e.minute      = minute;
    e.compartment = compartment;
    e.days        = days;
    strncpy(e.sid, sid ? sid : "", sizeof(e.sid) - 1);
    return true;
}

int schedule_sync_commit(uint32_t nowLocal) {
    if (_stagedExpected < 0)         { _syncError = "no sched_begin";        return -1; }
    if (_stagedOverflow)             { _syncError = "too many dose times";   _stagedExpected = -1; return -1; }
    if (_stagedCount != _stagedExpected) {
        _syncError = "item count does not match sched_begin";
        _stagedExpected = -1;
        return -1;
    }
    // Unchanged dose times keep their "added" time; new ones start now.
    for (int i = 0; i < _stagedCount; i++) {
        ScheduleEntry &s = _staged[i];
        s.since = nowLocal;
        for (int j = 0; j < _count; j++) {
            const ScheduleEntry &old = _entries[j];
            if (!strcmp(old.sid, s.sid) && old.minute == s.minute && old.compartment == s.compartment &&
                old.days == s.days) {
                s.since = old.since;
                break;
            }
        }
    }
    memcpy(_entries, _staged, sizeof(ScheduleEntry) * _stagedCount);
    _count = _stagedCount;
    strncpy(_version, _stagedVersion, sizeof(_version));
    _prefs.putString("ver", _version);
    saveEntries();
    _stagedExpected = -1;
    _syncError = "";
    return _count;
}

const char *schedule_sync_error() { return _syncError; }

const char *schedule_version() { return _version; }

bool schedule_app_done(const char *sid, uint32_t day, uint16_t minute) {
    for (int i = 0; i < _count; i++) {
        const ScheduleEntry &e = _entries[i];
        if (e.minute != minute || strcmp(e.sid, sid) || !runsOn(e, day)) continue;
        if (!findHandled(day, e.minute, e.compartment)) {
            markHandled(day, e.minute, e.compartment, ST_APP);
            Serial.printf("Dose done in the app: compartment %u, %02u:%02u (day %lu): alarm off\n",
                          e.compartment, minute / 60, minute % 60, (unsigned long)day);
        }
        return true;
    }
    return false;
}

// ── due, taken, missed ───────────────────────────────────────────────────────

uint8_t schedule_update(uint32_t nowLocal) {
    uint8_t lit = 0;
    // Yesterday too: a dose at 23:30 is still due at 00:15.
    forEachDose(nowLocal, -1, 0, [&](const ScheduleEntry &e, uint32_t day, uint32_t start) {
        if (nowLocal < start) return;                                   // not yet
        if (findHandled(day, e.minute, e.compartment)) return;          // taken or missed
        if (nowLocal < start + DUE_WINDOW_MIN * 60UL) {
            lit |= 1 << (e.compartment - 1);
        } else {
            markHandled(day, e.minute, e.compartment, ST_MISSED);
            recordDose(EV_MISSED, e, day, nowLocal, TIMING_NONE, nullptr);
        }
    });
    return lit;
}

uint8_t schedule_take(uint32_t nowLocal, bool &early) {
    uint8_t taken = 0;
    early = false;

    // Every dose that is due now.
    forEachDose(nowLocal, -1, 0, [&](const ScheduleEntry &e, uint32_t day, uint32_t start) {
        if (nowLocal < start || nowLocal >= start + DUE_WINDOW_MIN * 60UL) return;
        if (findHandled(day, e.minute, e.compartment)) return;
        markHandled(day, e.minute, e.compartment, ST_TAKEN);
        taken |= 1 << (e.compartment - 1);
        bool late = nowLocal >= start + LATE_AFTER_MIN * 60UL;
        recordDose(EV_TAKEN, e, day, nowLocal, late ? TIMING_LATE : TIMING_ON_TIME,
                   late ? "late" : "on time");
    });
    if (taken) return taken;

    // Nothing due: the NEAREST dose time within the early window is taken early
    // (every compartment at that same time; a later dose waits for its own
    // press — team decision, Oct 24). Tomorrow too: a 00:10 dose can be taken
    // early at 23:50.
    auto inEarlyWindow = [&](const ScheduleEntry &e, uint32_t day, uint32_t start) {
        return start > nowLocal && start <= nowLocal + EARLY_WINDOW_MIN * 60UL &&
               !findHandled(day, e.minute, e.compartment);
    };
    uint32_t nearest = UINT32_MAX;
    forEachDose(nowLocal, 0, 1, [&](const ScheduleEntry &e, uint32_t day, uint32_t start) {
        if (inEarlyWindow(e, day, start) && start < nearest) nearest = start;
    });
    forEachDose(nowLocal, 0, 1, [&](const ScheduleEntry &e, uint32_t day, uint32_t start) {
        if (start != nearest || !inEarlyWindow(e, day, start)) return;
        markHandled(day, e.minute, e.compartment, ST_TAKEN);
        taken |= 1 << (e.compartment - 1);
        char note[24];
        snprintf(note, sizeof(note), "early (%lu min before)",
                 (unsigned long)((start - nowLocal + 59) / 60));
        recordDose(EV_TAKEN, e, day, nowLocal, TIMING_EARLY, note);
    });
    early = taken != 0;
    return taken;
}

// ── console output ───────────────────────────────────────────────────────────

void schedule_days_text(uint8_t days, char *buf, int len) {
    if ((days & DAYS_EVERY) == DAYS_EVERY) {
        snprintf(buf, len, "every day");
        return;
    }
    buf[0] = 0;
    for (int d = 0; d < 7; d++) {
        if (!((days >> d) & 1)) continue;
        if (buf[0]) strncat(buf, ",", len - strlen(buf) - 1);
        strncat(buf, DAY_NAMES[d], len - strlen(buf) - 1);
    }
}

void schedule_print(uint32_t nowLocal) {
    if (_count == 0) {
        Serial.println("  (no dose times)  Add one:  add <compartment> <HH:MM> [mon,tue,...]");
        return;
    }
    uint32_t today = nowLocal / DAY_S;
    for (int i = 0; i < _count; i++) {
        const ScheduleEntry &e = _entries[i];
        char days[32];
        schedule_days_text(e.days, days, sizeof(days));

        // Today's dose; yesterday's wins if it is still inside its window
        // (a 23:30 dose is still due at 00:15).
        const char *state = "not today";
        for (int off = 0; off >= -1; off--) {
            uint32_t day = today + off;
            if (!runsOn(e, day)) continue;
            uint32_t start = day * DAY_S + e.minute * 60UL;
            if (off == -1 && nowLocal >= start + DUE_WINDOW_MIN * 60UL) continue;
            if (start < e.since)                             state = "added after its time";
            else if (uint8_t st = findHandled(day, e.minute, e.compartment))
                state = st == ST_TAKEN ? "TAKEN" : st == ST_MISSED ? "MISSED" : "done in the app";
            else if (nowLocal < start)                       state = "upcoming";
            else if (nowLocal < start + DUE_WINDOW_MIN * 60UL) state = "DUE NOW (lit)";
            else                                             state = "missed";
        }
        Serial.printf("  %d. compartment %u at %02u:%02u, %s  ->  %s\n", i + 1, e.compartment,
                      e.minute / 60, e.minute % 60, days, state);
    }
}
