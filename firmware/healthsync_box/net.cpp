// net.cpp
#include "net.h"
#include "config.h"
#include "secrets.h"
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WiFiManager.h>

// WPA2 needs at least 8 characters, or the hotspot will not start.
static_assert(sizeof(SETUP_AP_PASSWORD) - 1 >= 8, "SETUP_AP_PASSWORD needs 8+ characters");

static WiFiManager wm;
static String   _apName;               // "HealthSync-0001"
static bool     _inSetup     = false;
static bool     _hasSaved    = false;  // a Wi-Fi is saved in flash
static uint32_t _setupSince  = 0;
static uint32_t _noWifiSince = 0;      // 0 = connected (not counting)

static void showStatus() {
    digitalWrite(STATUS_LED_PIN, net_connected() ? HIGH : LOW);
}

static void printConnected() {
    Serial.print("Wi-Fi connected to \"");
    Serial.print(WiFi.SSID());
    Serial.print("\", IP ");
    Serial.println(WiFi.localIP());
}

static void startSetup() {
    wm.startConfigPortal(_apName.c_str(), SETUP_AP_PASSWORD);   // non-blocking
    _inSetup    = true;
    _setupSince = millis();
    Serial.printf("SETUP MODE: on the phone join Wi-Fi \"%s\" (password on the label),\n",
                  _apName.c_str());
    Serial.println("then open 192.168.4.1 if the setup page does not open by itself.");
    showStatus();
}

static void stopSetup() {
    // After a successful Save, WiFiManager has already closed the hotspot
    // itself. Closing it a second time dereferences its freed web server and
    // crashes the ESP32 (Guru Meditation, LoadProhibited — bench, Oct 20).
    if (wm.getConfigPortalActive()) wm.stopConfigPortal();
    WiFi.mode(WIFI_STA);
    _inSetup = false;
}

void net_begin() {
    pinMode(STATUS_LED_PIN, OUTPUT);
    digitalWrite(STATUS_LED_PIN, LOW);

    String suffix = DEVICE_SERIAL;
    if (suffix.startsWith("HS-")) suffix = suffix.substring(3);
    _apName = "HealthSync-" + suffix;

    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);

    wm.setDebugOutput(false);
    wm.setConfigPortalBlocking(false);
    wm.setConfigPortalTimeout(0);   // we decide when setup closes (net_process)
    wm.setConnectTimeout(WIFI_CONNECT_TIMEOUT_MS / 1000);
    wm.setTitle("HealthSync box setup");
    static std::vector<const char *> menu = {"wifi"};   // only "Configure Wi-Fi"
    wm.setMenu(menu);

    // Try the saved Wi-Fi FIRST. Asking "is a Wi-Fi saved?" before this can
    // wrongly answer no: the ESP32 may not have loaded its saved settings yet.
    Serial.print("Connecting to the saved Wi-Fi");
    WiFi.begin();   // uses the network saved in flash
    uint32_t start = millis();
    while (!net_connected() && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
        delay(500);
        Serial.print(".");
    }
    Serial.println();

    if (net_connected()) {
        _hasSaved = true;
        printConnected();
        showStatus();
        return;
    }

    _hasSaved = wm.getWiFiIsSaved();
    if (_hasSaved) {
        _noWifiSince = millis();
        Serial.printf("Saved Wi-Fi \"%s\" not found (status %d). Retrying; setup opens after "
                      "%lu min without Wi-Fi.\n", WiFi.SSID().c_str(), WiFi.status(),
                      (unsigned long)(SETUP_AFTER_NO_WIFI_MS / 60000UL));
        showStatus();
    } else {
        Serial.printf("No Wi-Fi saved yet (status %d).\n", WiFi.status());
        startSetup();
    }
}

void net_open_setup() {
    if (!_inSetup) startSetup();
}

bool net_close_setup() {
    if (!_inSetup || !_hasSaved) return false;
    Serial.println("Setup closed: back to the saved Wi-Fi.");
    stopSetup();
    WiFi.begin();
    _noWifiSince = millis();
    return true;
}

bool net_connected() {
    return WiFi.status() == WL_CONNECTED;
}

bool net_in_setup() {
    return _inSetup;
}

bool net_process() {
    uint32_t now = millis();

    if (_inSetup) {
        if (wm.process()) {            // a Wi-Fi typed in setup was saved and joined
            stopSetup();
            _hasSaved    = true;
            _noWifiSince = 0;
            printConnected();
            showStatus();
            return true;
        }
        // Nobody is using setup and an older Wi-Fi is saved: close setup for a
        // while and try that Wi-Fi again (it may have come back).
        if (_hasSaved && WiFi.softAPgetStationNum() == 0 && now - _setupSince >= SETUP_WINDOW_MS) {
            Serial.println("Setup not used: trying the saved Wi-Fi again.");
            stopSetup();
            WiFi.begin();
            _noWifiSince = now;
        }
        return false;
    }

    if (net_connected()) {
        _noWifiSince = 0;
    } else {
        if (_noWifiSince == 0) _noWifiSince = now ? now : 1;
        if (now - _noWifiSince >= SETUP_AFTER_NO_WIFI_MS) {
            Serial.println("No Wi-Fi for 5 minutes.");
            startSetup();
        }
    }
    return false;
}

void net_maintain() {
    if (_inSetup) return;
    if (!net_connected()) {
        Serial.println("Wi-Fi down, reconnecting...");
        WiFi.reconnect();
    }
    showStatus();
}

bool net_get_state(BoxState &out) {
    if (_inSetup || !net_connected()) return false;

    String url = String(WORKER_BASE_URL) + "/device/" + DEVICE_SERIAL + "/state";

    // The Worker and the tunnel are HTTPS. Certificates are not checked yet
    // (setInsecure); the device key in Phase 5 is what authenticates the box.
    // A plain http:// URL (Worker on the local network) uses a normal client.
    WiFiClientSecure secureClient;
    WiFiClient plainClient;
    bool https = url.startsWith("https://");
    if (https) secureClient.setInsecure();

    HTTPClient http;
    http.setConnectTimeout(HTTP_TIMEOUT_MS);
    http.setTimeout(HTTP_TIMEOUT_MS);
    if (!http.begin(https ? (WiFiClient &)secureClient : plainClient, url)) {
        Serial.println("GET /state: bad URL");
        return false;
    }

    int code = http.GET();
    if (code != 200) {
        Serial.printf("GET /state failed: %d %s\n", code,
                      code < 0 ? http.errorToString(code).c_str() : http.getString().c_str());
        http.end();
        return false;
    }

    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, http.getString());
    http.end();
    if (err) {
        Serial.printf("GET /state: bad JSON (%s)\n", err.c_str());
        return false;
    }

    uint8_t mask = 0;
    for (JsonVariantConst v : doc["lit"].as<JsonArrayConst>()) {
        int compartment = v.as<int>();
        // The app allows compartments 1–8; this box has LED_COUNT of them.
        if (compartment >= 1 && compartment <= LED_COUNT) mask |= (1 << (compartment - 1));
    }

    out.litMask = mask;
    out.buzz    = doc["buzz"] | true;
    return true;
}
