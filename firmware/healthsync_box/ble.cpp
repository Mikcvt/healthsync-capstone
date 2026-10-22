// ble.cpp
#include "ble.h"
#include "config.h"
#include <Arduino.h>
#include <NimBLEDevice.h>

struct Command {
    char text[BLE_COMMAND_MAX];
};

static NimBLEServer         *_server = nullptr;
static NimBLECharacteristic *_reply  = nullptr;
static QueueHandle_t         _queue  = nullptr;

// Written by the Bluetooth task, read by loop().
static volatile bool     _connected    = false;
static volatile uint16_t _connHandle   = 0;
static volatile uint16_t _mtu          = 23;
static volatile uint32_t _lastActivity = 0;
static volatile bool     _changed      = false;   // connect/disconnect/MTU to report
static volatile uint32_t _dropped      = 0;       // commands lost because the queue was full

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer *, NimBLEConnInfo &info) override {
        _connHandle   = info.getConnHandle();
        _connected    = true;
        _mtu          = 23;
        _lastActivity = millis();
        _changed      = true;
    }
    void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int) override {
        _connected = false;
        _changed   = true;   // advertising restarts by itself (advertiseOnDisconnect)
    }
    void onMTUChange(uint16_t mtu, NimBLEConnInfo &) override {
        _mtu     = mtu;
        _changed = true;
    }
};

class CommandCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic *c, NimBLEConnInfo &) override {
        NimBLEAttValue value = c->getValue();
        Command cmd;
        size_t n = value.size() < sizeof(cmd.text) - 1 ? value.size() : sizeof(cmd.text) - 1;
        memcpy(cmd.text, value.data(), n);
        cmd.text[n] = 0;
        _lastActivity = millis();
        if (xQueueSend(_queue, &cmd, 0) != pdTRUE) _dropped = _dropped + 1;
    }
};

void ble_begin(const char *name) {
    pinMode(STATUS_LED_PIN, OUTPUT);
    digitalWrite(STATUS_LED_PIN, LOW);
    _queue = xQueueCreate(8, sizeof(Command));

    NimBLEDevice::init(name);
    NimBLEDevice::setMTU(BLE_MTU);

    _server = NimBLEDevice::createServer();
    _server->setCallbacks(new ServerCallbacks());
    _server->advertiseOnDisconnect(true);

    NimBLEService *service = _server->createService(BLE_SERVICE_UUID);
    NimBLECharacteristic *command = service->createCharacteristic(
        BLE_COMMAND_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR, BLE_COMMAND_MAX);
    command->setCallbacks(new CommandCallbacks());
    _reply = service->createCharacteristic(BLE_REPLY_UUID, NIMBLE_PROPERTY::NOTIFY);
    _server->start();

    // The 128-bit service id fills most of the 31-byte advertisement, so the
    // name goes in the scan response.
    NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
    NimBLEAdvertisementData advData, scanData;
    advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
    advData.setCompleteServices(NimBLEUUID(BLE_SERVICE_UUID));
    scanData.setName(name);
    adv->enableScanResponse(true);
    adv->setAdvertisementData(advData);
    adv->setScanResponseData(scanData);
    adv->start();

    Serial.printf("Bluetooth: advertising as \"%s\"\n", name);
}

void ble_update() {
    if (_changed) {
        _changed = false;
        if (_connected) Serial.printf("Bluetooth: phone connected (packet size %u)\n", _mtu);
        else            Serial.println("Bluetooth: phone disconnected, advertising again");
    }
    if (_dropped) {
        Serial.printf("Bluetooth: %lu command(s) dropped (sent too fast)\n", (unsigned long)_dropped);
        _dropped = 0;
    }
    if (_connected && millis() - _lastActivity > BLE_IDLE_DISCONNECT_MS) {
        Serial.println("Bluetooth: phone silent for 60 s, disconnecting");
        _lastActivity = millis();
        _server->disconnect(_connHandle);
    }
    digitalWrite(STATUS_LED_PIN, _connected ? HIGH : LOW);
}

bool ble_connected() { return _connected; }

uint16_t ble_mtu() { return _mtu; }

bool ble_next_command(char *buf, size_t len) {
    Command cmd;
    if (!_queue || xQueueReceive(_queue, &cmd, 0) != pdTRUE) return false;
    strncpy(buf, cmd.text, len - 1);
    buf[len - 1] = 0;
    return true;
}

bool ble_send(const char *msg) {
    if (!_connected || !_reply) return false;
    size_t len = strlen(msg);
    if (len > (size_t)_mtu - 3) {   // 3 bytes of every packet are protocol header
        Serial.printf("Bluetooth: reply of %u bytes does not fit packet size %u: ask for MTU %d\n",
                      (unsigned)len, _mtu, BLE_MTU);
        return false;
    }
    return _reply->notify(reinterpret_cast<const uint8_t *>(msg), len);
}
