// ble.h — the box as a Bluetooth Low Energy peripheral (NimBLE-Arduino).
//
// One service with two characteristics: "command" (the phone writes one JSON
// message per write) and "reply" (the box sends one JSON message per
// notification). Connect-on-demand: the phone connects, syncs and disconnects;
// a phone that stays silent for BLE_IDLE_DISCONNECT_MS is dropped. The box
// advertises again after every disconnect.
//
// Security (Phase 4): LE Secure Connections with a 6-digit passkey (printed on
// the box label) and bonding. Both characteristics need an encrypted,
// authenticated link. A new phone can pair only while pairing mode is open
// (ble_pairing_open); at any other time the box hands out a random code, so
// pairing fails. Paired phones reconnect encrypted with no code.
//
// Commands arrive on the Bluetooth task; they are queued and read from loop()
// with ble_next_command(), so the schedule, clock and SD card are only ever
// touched from loop().
#pragma once
#include <stddef.h>
#include <stdint.h>

void ble_begin(const char *name, uint32_t passkey);   // e.g. "HealthSync-0001", BLE_PASSKEY
void ble_update();                  // call every loop(): connection messages, drops, status LED

bool     ble_connected();
bool     ble_secure();              // connected over an encrypted link with a paired phone
uint16_t ble_mtu();

// Pairing mode: a new phone may pair (with the passkey) until it closes.
void ble_pairing_open(uint32_t ms);
void ble_pairing_close();
bool ble_pairing_active();
bool ble_take_paired_event();       // true once, right after a new phone paired

int  ble_bond_count();              // phones the box remembers (up to 3)
void ble_forget_all();              // forget every paired phone

// The next command from the phone, if any (copied into `buf`).
bool ble_next_command(char *buf, size_t len);

// One reply as a notification. False if no paired phone is connected or the
// message is longer than the packet size allows (the phone must ask for MTU 247).
bool ble_send(const char *msg);
