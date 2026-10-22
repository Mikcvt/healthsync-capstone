// protocol.cpp
#include "protocol.h"
#include "config.h"
#include "secrets.h"
#include "ble.h"
#include "rtc_clock.h"
#include "schedule.h"
#include "storage.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include <RTClib.h>

static const uint32_t VALID_FROM_UTC = 1704067200UL;   // 2024-01-01

// ── replies ──────────────────────────────────────────────────────────────────

static void send(const char *msg) {
    Serial.printf("BLE < %s\n", msg);
    ble_send(msg);
}

static void reply(JsonDocument &doc) {
    char buf[BLE_MTU];
    serializeJson(doc, buf, sizeof(buf));
    send(buf);
}

static void replyOk() {
    JsonDocument doc;
    doc["op"] = "ok";
    reply(doc);
}

static void replyError(const char *msg) {
    JsonDocument doc;
    doc["op"]  = "error";
    doc["msg"] = msg;
    reply(doc);
}

// One event, wrapped: {"op":"event","e":<the same line as in the log file>}.
static void sendEvent(const char *line) {
    char buf[BLE_MTU];
    snprintf(buf, sizeof(buf), "{\"op\":\"event\",\"e\":%s}", line);
    send(buf);
    delay(15);   // give the Bluetooth stack time to send each packet
}

// ── parsing ──────────────────────────────────────────────────────────────────

static bool parseHHMM(const char *s, uint16_t &minute) {
    int h, m;
    if (!s || sscanf(s, "%d:%d", &h, &m) != 2 || h < 0 || h > 23 || m < 0 || m > 59) return false;
    minute = h * 60 + m;
    return true;
}

// "2026-10-24" → local days since 1970.
static bool parseDate(const char *s, uint32_t &day) {
    int y, mo, d;
    if (!s || sscanf(s, "%d-%d-%d", &y, &mo, &d) != 3 || y < 2024 || mo < 1 || mo > 12 || d < 1 ||
        d > 31) {
        return false;
    }
    day = DateTime(y, mo, d).unixtime() / 86400UL;
    return true;
}

// The app's days_of_week: integers, 1 = Monday … 7 = Sunday; empty = every day.
// Returns 0 if not understood.
static uint8_t parseDays(JsonVariantConst v) {
    if (v.isNull()) return DAYS_EVERY;
    if (!v.is<JsonArrayConst>()) return 0;
    JsonArrayConst arr = v.as<JsonArrayConst>();
    if (arr.size() == 0) return DAYS_EVERY;
    uint8_t bits = 0;
    for (JsonVariantConst d : arr) {
        int n = d | 0;
        if (n < 1 || n > 7) return 0;
        bits |= 1 << (n - 1);
    }
    return bits;
}

// ── commands ─────────────────────────────────────────────────────────────────

bool protocol_handle(const char *msg) {
    JsonDocument in;
    if (deserializeJson(in, msg)) {
        replyError("not JSON");
        return false;
    }
    const char *op = in["op"] | "";
    JsonDocument out;

    if (!strcmp(op, "hello")) {
        out["op"]        = "hello";
        out["serial"]    = DEVICE_SERIAL;
        out["fw"]        = FIRMWARE_VERSION;
        out["utc"]       = rtc_now_utc();
        out["clock_ok"]  = rtc_time_valid();
        out["sched_ver"] = schedule_version();
        out["count"]     = schedule_count();
        out["last_seq"]  = storage_last_seq();
        out["acked"]     = storage_acked_seq();
        out["pending"]   = storage_pending();
        out["sd"]        = storage_sd_ok();
        reply(out);
        return false;
    }

    if (!strcmp(op, "set_time")) {
        uint32_t utc = in["utc"] | (uint32_t)0;
        if (utc < VALID_FROM_UTC) {
            replyError("utc missing or before 2024");
            return false;
        }
        rtc_set_utc(utc);
        replyOk();
        return true;
    }

    if (!strcmp(op, "sched_begin")) {
        int count = in["count"] | -1;
        if (count < 0 || count > MAX_SCHEDULES) {
            replyError("count must be 0 to 24");
            return false;
        }
        schedule_sync_begin(in["ver"] | "", count);
        replyOk();
        return false;
    }

    if (!strcmp(op, "sched_item")) {
        uint16_t minute;
        uint8_t  days = parseDays(in["days"]);
        int      comp = in["comp"] | 0;
        if (!parseHHMM(in["time"] | "", minute) || !days ||
            !schedule_sync_item(in["sid"] | "", comp, minute, days)) {
            replyError("bad item (comp 1-6, time HH:MM, days 1-7) or no sched_begin");
            return false;
        }
        replyOk();
        return false;
    }

    if (!strcmp(op, "sched_commit")) {
        if (!rtc_time_valid()) {
            replyError("set_time first");
            return false;
        }
        int count = schedule_sync_commit(rtc_now_local());
        if (count < 0) {
            replyError(schedule_sync_error());
            return false;
        }
        out["op"]    = "ok";
        out["count"] = count;
        reply(out);
        Serial.printf("Schedule replaced by the phone: %d dose time(s), version \"%s\"\n", count,
                      schedule_version());
        return true;
    }

    if (!strcmp(op, "events")) {
        uint32_t after = in["after"] | storage_acked_seq();
        int      max   = in["max"] | BLE_EVENTS_MAX;
        if (max < 1 || max > BLE_EVENTS_MAX) max = BLE_EVENTS_MAX;
        int sent = storage_events_after(after, max, sendEvent);
        out["op"]   = "events_end";
        out["sent"] = sent;
        out["last"] = storage_last_seq();
        reply(out);
        return false;
    }

    if (!strcmp(op, "ack")) {
        if (!in["seq"].is<uint32_t>() || !storage_ack(in["seq"].as<uint32_t>())) {
            replyError("seq missing or beyond the last event");
            return false;
        }
        out["op"]      = "ok";
        out["pending"] = storage_pending();
        reply(out);
        return false;
    }

    if (!strcmp(op, "app_done")) {
        uint32_t day;
        uint16_t minute;
        if (!parseDate(in["date"] | "", day) || !parseHHMM(in["time"] | "", minute) ||
            !schedule_app_done(in["sid"] | "", day, minute)) {
            replyError("no dose with that sid, date and time");
            return false;
        }
        replyOk();
        return true;
    }

    replyError("unknown op");
    return false;
}
