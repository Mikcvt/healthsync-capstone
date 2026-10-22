// protocol.h — the messages the phone and the box exchange over Bluetooth
// (BLE_PROTOCOL.md). One JSON object per message, with an "op" field.
//
//   hello · set_time · sched_begin / sched_item / sched_commit · events · ack ·
//   app_done      (replies: hello, ok, event, events_end, error)
#pragma once

// Handles one command from the phone and sends the reply. Returns true when
// the clock or the schedule changed, so the caller refreshes the LEDs.
bool protocol_handle(const char *msg);
