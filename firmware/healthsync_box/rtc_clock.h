// rtc_clock.h — the DS3231 clock. It holds UTC; the box works in Manila time
// (UTC + TZ_OFFSET_MIN), the same as the Worker.
#pragma once
#include <stdint.h>
#include <stddef.h>

bool rtc_begin();            // false if the DS3231 does not answer on I2C
bool rtc_ok();
bool rtc_lost_power();       // the clock stopped (no coin cell power) since it was last set

// Seconds since 1970-01-01 00:00:00.
uint32_t rtc_now_utc();
uint32_t rtc_now_local();    // Manila time, counted the same way
void     rtc_set_utc(uint32_t utc);

// False until the time has been set (anything before 2024 counts as not set).
bool rtc_time_valid();

// "2026-10-23 14:02:05" for a local time.
void rtc_format_local(uint32_t local, char *buf, size_t len);
