// storage.cpp
#include "storage.h"
#include "config.h"
#include <Arduino.h>
#include <SPI.h>
#include <SD.h>
#include <Preferences.h>
#include <RTClib.h>

static Preferences _prefs;
static bool        _sdOk  = false;
static uint32_t    _seq   = 0;   // last seq handed out (saved before the line is written)
static uint32_t    _acked = 0;   // last seq the phone confirmed
static DoseEvent   _fallback[LOG_FALLBACK_MAX];   // events waiting for a card, oldest first
static int         _fbCount = 0;

static const char *TIMING_TEXT[] = {"", "on_time", "late", "early"};

// ── helpers ──────────────────────────────────────────────────────────────────

static void saveFallback() {
    _prefs.putBytes("fb", _fallback, sizeof(DoseEvent) * _fbCount);
    _prefs.putInt("fbn", _fbCount);
}

// One JSON line. `date` + `time` are the dose's Manila date and time; with
// `sid` they make the app's dose id {sid}_{date}_{time}.
static void formatLine(const DoseEvent &e, char *buf, size_t len) {
    DateTime dose(e.doseLocal);
    DateTime at(e.atUtc);
    snprintf(buf, len,
             "{\"seq\":%lu,\"type\":\"%s\",\"comp\":%u,\"date\":\"%04d-%02d-%02d\","
             "\"time\":\"%02d:%02d\",\"at\":\"%04d-%02d-%02dT%02d:%02d:%02dZ\","
             "\"timing\":\"%s\",\"sid\":\"%s\"}",
             (unsigned long)e.seq, e.type == EV_TAKEN ? "taken" : "missed", e.compartment,
             dose.year(), dose.month(), dose.day(), dose.hour(), dose.minute(),
             at.year(), at.month(), at.day(), at.hour(), at.minute(), at.second(),
             TIMING_TEXT[e.timing <= TIMING_EARLY ? e.timing : 0], e.sid);
}

static bool appendToSd(const DoseEvent &e) {
    File f = SD.open(LOG_FILE, FILE_APPEND);
    if (!f) return false;
    char line[220];
    formatLine(e, line, sizeof(line));
    size_t written = f.println(line);
    f.close();                       // closed at once: a power cut loses nothing
    return written > 0;
}

static bool mountCard() {
    SPI.begin(SD_SCK_PIN, SD_MISO_PIN, SD_MOSI_PIN, SD_CS_PIN);
    const uint32_t speeds[] = {4000000, 1000000};   // slower retry for long breadboard wires
    for (uint32_t hz : speeds) {
        if (SD.begin(SD_CS_PIN, SPI, hz) && SD.cardType() != CARD_NONE) return true;
        SD.end();
    }
    return false;
}

// ── public ───────────────────────────────────────────────────────────────────

bool storage_begin() {
    _prefs.begin("doselog", false);
    _seq     = _prefs.getUInt("seq", 0);
    _acked   = _prefs.getUInt("acked", 0);
    _fbCount = _prefs.getInt("fbn", 0);
    if (_fbCount < 0 || _fbCount > LOG_FALLBACK_MAX) _fbCount = 0;
    if (_fbCount > 0) _prefs.getBytes("fb", _fallback, sizeof(DoseEvent) * _fbCount);

    _sdOk = mountCard();
    if (!_sdOk) {
        Serial.println("WARNING: no SD card: dose events are kept in flash until a card is found");
        return false;
    }

    // Events that waited in flash move to the card, oldest first.
    int moved = 0;
    while (moved < _fbCount && appendToSd(_fallback[moved])) moved++;
    if (moved > 0) {
        for (int i = moved; i < _fbCount; i++) _fallback[i - moved] = _fallback[i];
        _fbCount -= moved;
        saveFallback();
        Serial.printf("Moved %d event(s) from flash to the SD card\n", moved);
    }
    return true;
}

bool storage_sd_ok() { return _sdOk; }

uint32_t storage_log(DoseEventType type, uint8_t compartment, uint32_t doseLocal, uint32_t atUtc,
                     DoseTiming timing, const char *sid) {
    DoseEvent e = {};
    e.seq = ++_seq;
    _prefs.putUInt("seq", _seq);     // saved first: a seq is never handed out twice
    e.doseLocal   = doseLocal;
    e.atUtc       = atUtc;
    e.type        = type;
    e.compartment = compartment;
    e.timing      = timing;
    // The app's ids are letters and digits; drop anything that would break the JSON.
    int j = 0;
    for (int i = 0; sid && sid[i] && j < (int)sizeof(e.sid) - 1; i++) {
        if (sid[i] != '"' && sid[i] != '\\' && sid[i] >= ' ') e.sid[j++] = sid[i];
    }

    if (_sdOk && appendToSd(e)) {
        Serial.printf("  logged #%lu on the SD card\n", (unsigned long)e.seq);
        return e.seq;
    }
    if (_sdOk) {
        _sdOk = false;
        Serial.println("WARNING: SD card write failed: events are kept in flash from now on");
    }
    if (_fbCount == LOG_FALLBACK_MAX) {
        Serial.printf("WARNING: flash log full: oldest event #%lu dropped\n",
                      (unsigned long)_fallback[0].seq);
        for (int i = 1; i < _fbCount; i++) _fallback[i - 1] = _fallback[i];
        _fbCount--;
    }
    _fallback[_fbCount++] = e;
    saveFallback();
    Serial.printf("  logged #%lu in flash (%d waiting for a card)\n", (unsigned long)e.seq, _fbCount);
    return e.seq;
}

uint32_t storage_last_seq()  { return _seq; }
uint32_t storage_acked_seq() { return _acked; }
uint32_t storage_pending()   { return _seq > _acked ? _seq - _acked : 0; }

bool storage_ack(uint32_t seq) {
    if (seq > _seq) return false;            // the phone cannot have what does not exist
    if (seq <= _acked) return true;          // already confirmed: nothing to do
    _acked = seq;
    _prefs.putUInt("acked", _acked);
    // Flash copies the phone already has are no longer needed.
    int keep = 0;
    for (int i = 0; i < _fbCount; i++) {
        if (_fallback[i].seq > _acked) _fallback[keep++] = _fallback[i];
    }
    if (keep != _fbCount) {
        _fbCount = keep;
        saveFallback();
    }
    return true;
}

int storage_events_after(uint32_t after, int max, void (*fn)(const char *line)) {
    int sent = 0;
    if (_sdOk) {
        File f = SD.open(LOG_FILE, FILE_READ);
        if (f) {
            while (f.available() && sent < max) {
                String line = f.readStringUntil('\n');
                line.trim();
                if (line.length() == 0) continue;
                if ((uint32_t)line.substring(7).toInt() <= after) continue;   // "seq":N comes first
                fn(line.c_str());
                sent++;
            }
            f.close();
        }
    }
    for (int i = 0; i < _fbCount && sent < max; i++) {
        if (_fallback[i].seq <= after) continue;
        char line[220];
        formatLine(_fallback[i], line, sizeof(line));
        fn(line);
        sent++;
    }
    return sent;
}

void storage_print_last(int count) {
    const int MAX_SHOW = 20;
    if (count < 1) count = 1;
    if (count > MAX_SHOW) count = MAX_SHOW;

    // The last `count` lines of the file, then the events still in flash.
    String lines[MAX_SHOW];
    int total = 0;
    if (_sdOk) {
        File f = SD.open(LOG_FILE, FILE_READ);
        if (f) {
            while (f.available()) {
                String line = f.readStringUntil('\n');
                line.trim();
                if (line.length() == 0) continue;
                lines[total % MAX_SHOW] = line;
                total++;
            }
            f.close();
        }
    }
    int fromFile = total < count ? total : count;
    if (total + _fbCount == 0) {
        Serial.println("  (no dose events yet)");
        return;
    }
    Serial.printf("Last events (* = not collected by the phone yet; acked up to #%lu):\n",
                  (unsigned long)_acked);
    for (int i = total - fromFile; i < total; i++) {
        const String &line = lines[i % MAX_SHOW];
        // "seq":N is first in every line.
        uint32_t seq = line.substring(7).toInt();
        Serial.printf(" %s %s\n", seq > _acked ? "*" : " ", line.c_str());
    }
    for (int i = 0; i < _fbCount; i++) {
        char line[220];
        formatLine(_fallback[i], line, sizeof(line));
        Serial.printf(" %s %s   (in flash)\n", _fallback[i].seq > _acked ? "*" : " ", line);
    }
}

void storage_print_info() {
    if (_sdOk) {
        File f = SD.open(LOG_FILE, FILE_READ);
        size_t size = f ? f.size() : 0;
        if (f) f.close();
        Serial.printf("SD card: OK, %llu MB, %s is %u bytes\n",
                      SD.cardSize() / (1024ULL * 1024ULL), LOG_FILE, (unsigned)size);
    } else {
        Serial.println("SD card: NOT available (check the card and wiring; it is retried at boot)");
    }
    Serial.printf("Events: last #%lu, phone has up to #%lu, pending %lu, waiting in flash %d\n",
                  (unsigned long)_seq, (unsigned long)_acked, (unsigned long)storage_pending(),
                  _fbCount);
}
