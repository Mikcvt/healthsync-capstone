// net.h
#pragma once
#include <stdint.h>

// What the Worker says the box should show right now.
struct BoxState {
    uint8_t litMask;   // bit 0 = compartment 1 … bit 5 = compartment 6
    bool    buzz;      // false while every due dose is snoozed in the app
};

// Start Wi-Fi with the network saved in flash (set through the setup
// hotspot). With no saved network, opens the setup hotspot.
void net_begin();

// The 5-second button hold. Opening keeps the saved Wi-Fi (saving a new one
// replaces it). Closing only works when a Wi-Fi is saved; returns false if not.
void net_open_setup();
bool net_close_setup();

bool net_connected();

// Call every loop(). Runs the setup page, opens setup after
// SETUP_AFTER_NO_WIFI_MS without Wi-Fi, and closes an unused setup after
// SETUP_WINDOW_MS to retry the saved Wi-Fi.
// Returns true once, right after a Wi-Fi typed in setup was saved and joined.
bool net_process();

// True while the setup hotspot is open.
bool net_in_setup();

// Reconnect if Wi-Fi dropped, and keep the status LED in step. Cheap; call it
// before every poll.
void net_maintain();

// GET /device/{serial}/state. Returns false (and leaves `out` alone) on any
// failure: no Wi-Fi, in setup, timeout, non-200 reply or bad JSON.
bool net_get_state(BoxState &out);
