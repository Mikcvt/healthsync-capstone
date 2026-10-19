// config.example.h — copy this file to secrets.h and fill in your values.
// secrets.h is git-ignored and must be flashed individually per box.
// This template is committed, so it holds placeholders only.
#pragma once

// Serial number printed on the box label — must match the one paired in the app.
#define DEVICE_SERIAL "HS-0000"

// Password of the box's Wi-Fi setup hotspot (HealthSync-xxxx). 8+ characters,
// printed on the box label.
#define SETUP_AP_PASSWORD "change-me-8-chars"

// The home Wi-Fi is NOT typed here: it is chosen on the box's setup page
// (Phase 3) and saved in the ESP32's flash.
