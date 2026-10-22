// rtc_clock.cpp
#include "rtc_clock.h"
#include "config.h"
#include <Arduino.h>
#include <Wire.h>
#include <RTClib.h>

static RTC_DS3231 _rtc;
static bool       _ok = false;

static const uint32_t VALID_FROM_UTC = 1704067200UL;   // 2024-01-01 00:00:00

bool rtc_begin() {
    Wire.begin(RTC_SDA_PIN, RTC_SCL_PIN);
    _ok = _rtc.begin(&Wire);
    return _ok;
}

bool rtc_ok() { return _ok; }

bool rtc_lost_power() { return _ok && _rtc.lostPower(); }

uint32_t rtc_now_utc() { return _ok ? _rtc.now().unixtime() : 0; }

uint32_t rtc_now_local() { return rtc_now_utc() + TZ_OFFSET_MIN * 60UL; }

void rtc_set_utc(uint32_t utc) {
    if (_ok) _rtc.adjust(DateTime(utc));   // also clears the "lost power" flag
}

bool rtc_time_valid() { return rtc_now_utc() >= VALID_FROM_UTC; }

void rtc_format_local(uint32_t local, char *buf, size_t len) {
    DateTime d(local);
    snprintf(buf, len, "%04d-%02d-%02d %02d:%02d:%02d",
             d.year(), d.month(), d.day(), d.hour(), d.minute(), d.second());
}
