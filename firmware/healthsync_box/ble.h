// ble.h — the box as a Bluetooth Low Energy peripheral (NimBLE-Arduino).
//
// One service with two characteristics: "command" (the phone writes one JSON
// message per write) and "reply" (the box sends one JSON message per
// notification). Connect-on-demand: the phone connects, syncs and disconnects;
// a phone that stays silent for BLE_IDLE_DISCONNECT_MS is dropped. The box
// advertises again after every disconnect.
//
// Commands arrive on the Bluetooth task; they are queued and read from loop()
// with ble_next_command(), so the schedule, clock and SD card are only ever
// touched from loop().
#pragma once
#include <stddef.h>
#include <stdint.h>

void ble_begin(const char *name);   // e.g. "HealthSync-0001"
void ble_update();                  // call every loop(): connection messages, idle drop, status LED

bool     ble_connected();
uint16_t ble_mtu();

// The next command from the phone, if any (copied into `buf`).
bool ble_next_command(char *buf, size_t len);

// One reply as a notification. False if no phone is connected or the message
// is longer than the packet size allows (the phone must ask for MTU 247).
bool ble_send(const char *msg);
