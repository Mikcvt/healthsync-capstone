// console.cpp
#include "console.h"
#include "config.h"
#include "rtc_clock.h"
#include "schedule.h"
#include "storage.h"
#include "ble.h"
#include <Arduino.h>
#include <RTClib.h>

static char _line[96];
static int _len = 0;

static const char *DAY_KEYS[7] = { "mon", "tue", "wed", "thu", "fri", "sat", "sun" };

static void printHelp() {
  Serial.println("Commands (Serial Monitor line ending: Newline):");
  Serial.println("  time YYYY-MM-DD HH:MM        set the clock, Manila time (e.g. time 2026-10-23 14:00)");
  Serial.println("  add <1-6> <HH:MM> [days]     add a dose time; days like mon,wed,fri (default every day)");
  Serial.println("  list   or   status           dose times with today's state");
  Serial.println("  del <n>                      delete dose time n");
  Serial.println("  clear                        delete every dose time");
  Serial.println("  log [n]                      the last n dose events (default 10)");
  Serial.println("  pending                      events the phone has not collected yet");
  Serial.println("  ack <seq>                    pretend the phone collected everything up to seq");
  Serial.println("  sd                           SD card status");
  Serial.println("  pair                         open Bluetooth pairing mode for 2 minutes");
  Serial.println("  bonds                        how many phones are paired");
  Serial.println("  unpair                       forget every paired phone");
}

static void printTime() {
  if (!rtc_ok()) {
    Serial.println("Clock: DS3231 not found (check SDA 21 / SCL 22)");
    return;
  }
  if (!rtc_time_valid()) {
    Serial.println("Clock: NOT SET. Type  time YYYY-MM-DD HH:MM");
    return;
  }
  char buf[24];
  rtc_format_local(rtc_now_local(), buf, sizeof(buf));
  Serial.printf("Clock: %s (Manila)%s\n", buf, rtc_lost_power() ? "  [lost power: set it again]" : "");
}

static bool parseHHMM(const char *s, uint16_t &minute) {
  int h, m;
  if (!s || sscanf(s, "%d:%d", &h, &m) != 2 || h < 0 || h > 23 || m < 0 || m > 59) return false;
  minute = h * 60 + m;
  return true;
}

// "mon,wed,fri" → day bits; empty/"daily" → every day. 0 = not understood.
static uint8_t parseDays(const char *s) {
  if (!s || !*s || !strcasecmp(s, "daily") || !strcasecmp(s, "every")) return DAYS_EVERY;
  uint8_t bits = 0;
  char copy[48];
  strncpy(copy, s, sizeof(copy) - 1);
  copy[sizeof(copy) - 1] = 0;
  for (char *tok = strtok(copy, ","); tok; tok = strtok(nullptr, ",")) {
    int found = -1;
    for (int d = 0; d < 7; d++)
      if (!strncasecmp(tok, DAY_KEYS[d], 3)) found = d;
    if (found < 0) return 0;
    bits |= 1 << found;
  }
  return bits;
}

static bool cmdTime(char *args) {
  if (!args || !*args) {
    printTime();
    return false;
  }
  int y, mo, d, h, mi, s = 0;
  int n = sscanf(args, "%d-%d-%d %d:%d:%d", &y, &mo, &d, &h, &mi, &s);
  if (n < 5 || y < 2024 || y > 2099 || mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) {
    Serial.println("Use: time YYYY-MM-DD HH:MM   (e.g. time 2026-10-23 14:00)");
    return false;
  }
  if (!rtc_ok()) {
    Serial.println("DS3231 not found, cannot set the time");
    return false;
  }
  uint32_t local = DateTime(y, mo, d, h, mi, s).unixtime();
  rtc_set_utc(local - TZ_OFFSET_MIN * 60UL);
  printTime();
  return true;
}

static bool cmdAdd(char *args) {
  char *c = strtok(args, " ");
  char *t = strtok(nullptr, " ");
  char *days = strtok(nullptr, " ");
  int compartment = c ? atoi(c) : 0;
  uint16_t minute;
  uint8_t bits = parseDays(days);
  if (compartment < 1 || compartment > LED_COUNT || !parseHHMM(t, minute) || !bits) {
    Serial.println("Use: add <1-6> <HH:MM> [mon,tue,wed,thu,fri,sat,sun]   (e.g. add 3 14:02)");
    return false;
  }
  if (!rtc_time_valid()) {
    Serial.println("Set the clock first:  time YYYY-MM-DD HH:MM");
    return false;
  }
  if (!schedule_add(compartment, minute, bits, rtc_now_local())) {
    Serial.printf("Schedule full (%d dose times)\n", MAX_SCHEDULES);
    return false;
  }
  char text[32];
  schedule_days_text(bits, text, sizeof(text));
  Serial.printf("Added: compartment %d at %02u:%02u, %s\n", compartment, minute / 60, minute % 60, text);
  return true;
}

static bool handle(char *line) {
  char *cmd = strtok(line, " ");
  char *args = strtok(nullptr, "");  // the rest of the line
  if (!cmd) return false;

  if (!strcasecmp(cmd, "help")) {
    printHelp();
    return false;
  }
  if (!strcasecmp(cmd, "time")) return cmdTime(args);
  if (!strcasecmp(cmd, "add")) return cmdAdd(args);
  if (!strcasecmp(cmd, "list") || !strcasecmp(cmd, "status")) {
    printTime();
    schedule_print(rtc_now_local());
    return false;
  }
  if (!strcasecmp(cmd, "del")) {
    int n = args ? atoi(args) : 0;
    if (!schedule_remove(n - 1)) {
      Serial.println("Use: del <n>  (n from the list)");
      return false;
    }
    Serial.printf("Deleted dose time %d\n", n);
    return true;
  }
  if (!strcasecmp(cmd, "clear")) {
    schedule_clear();
    Serial.println("All dose times deleted (the dose log is kept)");
    return true;
  }
  if (!strcasecmp(cmd, "log")) {
    storage_print_last(args ? atoi(args) : 10);
    return false;
  }
  if (!strcasecmp(cmd, "pending")) {
    Serial.printf("Pending: %lu event(s) not collected by the phone (last #%lu, phone has up to #%lu)\n",
                  (unsigned long)storage_pending(), (unsigned long)storage_last_seq(),
                  (unsigned long)storage_acked_seq());
    return false;
  }
  if (!strcasecmp(cmd, "ack")) {
    long seq = args ? atol(args) : -1;
    if (seq < 0 || !storage_ack((uint32_t)seq)) {
      Serial.printf("Use: ack <seq>  (0 to %lu)\n", (unsigned long)storage_last_seq());
      return false;
    }
    Serial.printf("Acked up to #%ld. Pending: %lu\n", seq, (unsigned long)storage_pending());
    return false;
  }
  if (!strcasecmp(cmd, "sd")) {
    storage_print_info();
    return false;
  }
  if (!strcasecmp(cmd, "pair")) {
    ble_pairing_open(PAIRING_WINDOW_MS);
    Serial.println("PAIRING MODE for 2 minutes: connect the phone and type the 6-digit code from the box label");
    return false;
  }
  if (!strcasecmp(cmd, "bonds")) {
    Serial.printf("Paired phones: %d (the box remembers up to 3)\n", ble_bond_count());
    return false;
  }
  if (!strcasecmp(cmd, "unpair")) {
    int n = ble_bond_count();
    ble_forget_all();
    Serial.printf("Forgot %d paired phone(s). On each phone also tap Forget for the box in Bluetooth settings.\n", n);
    return false;
  }
  Serial.printf("Unknown command \"%s\". Type help\n", cmd);
  return false;
}

void console_begin() {
  printTime();
  storage_print_info();
  Serial.printf("%d dose time(s) stored. Type help for the commands.\n", schedule_count());
}

bool console_update() {
  bool changed = false;
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (_len > 0) {
        _line[_len] = 0;
        Serial.printf("> %s\n", _line);
        changed |= handle(_line);
        _len = 0;
      }
    } else if (_len < (int)sizeof(_line) - 1) {
      _line[_len++] = ch;
    }
  }
  return changed;
}
