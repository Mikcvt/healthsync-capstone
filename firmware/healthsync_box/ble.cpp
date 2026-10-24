// ble.cpp
#include "ble.h"
#include "config.h"
#include <Arduino.h>
#include <NimBLEDevice.h>

struct Command {
    char text[BLE_COMMAND_MAX];
};

static NimBLEServer         *_server  = nullptr;
static NimBLECharacteristic *_reply   = nullptr;
static QueueHandle_t         _queue   = nullptr;
static uint32_t              _passkey = 0;

// Written by the Bluetooth task, read by loop().
static volatile bool     _connected    = false;
static volatile bool     _secure       = false;   // encrypted + authenticated (paired phone)
static volatile uint16_t _connHandle   = 0;
static volatile uint16_t _mtu          = 23;
static volatile uint32_t _connectedAt  = 0;
static volatile uint32_t _lastActivity = 0;
static volatile uint32_t _dropped      = 0;       // commands lost because the queue was full
static volatile uint32_t _pairingUntil = 0;       // millis() when pairing mode ends; 0 = closed
static volatile bool     _codeGiven    = false;   // this connection was given the real passkey

// Events for loop() to report.
static volatile bool _evConnected = false, _evDisconnected = false, _evMtu = false;
static volatile bool _evSecure = false, _evPaired = false, _evRejected = false;
static volatile bool _pairedEvent = false;        // for ble_take_paired_event()

static bool pairingOpen() {
    return _pairingUntil != 0 && (int32_t)(_pairingUntil - millis()) > 0;
}

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer *, NimBLEConnInfo &info) override {
        _connHandle   = info.getConnHandle();
        _connected    = true;
        _secure       = false;
        _codeGiven    = false;
        _mtu          = 23;
        _connectedAt  = millis();
        _lastActivity = millis();
        _evConnected  = true;
        // Ask for encryption at once: a paired phone re-encrypts silently, a new
        // phone is asked for the passkey (which only works in pairing mode).
        NimBLEDevice::startSecurity(info.getConnHandle());
    }
    void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int) override {
        _connected      = false;
        _secure         = false;
        _evDisconnected = true;   // advertising restarts by itself (advertiseOnDisconnect)
    }
    void onMTUChange(uint16_t mtu, NimBLEConnInfo &) override {
        _mtu   = mtu;
        _evMtu = true;
    }
    // The passkey the phone's user must type. Outside pairing mode a random
    // number is used, so a phone that is not paired yet cannot pair.
    uint32_t onPassKeyDisplay() override {
        if (pairingOpen()) {
            _codeGiven = true;
            return _passkey;
        }
        return 100000 + esp_random() % 900000;
    }
    void onAuthenticationComplete(NimBLEConnInfo &info) override {
        if (!info.isEncrypted() || !info.isAuthenticated() || !info.isBonded()) {
            _evRejected = true;
            _server->disconnect(info.getConnHandle());
            return;
        }
        _secure   = true;
        _evSecure = true;
        if (_codeGiven) {          // a new phone just paired with the passkey
            _evPaired    = true;
            _pairedEvent = true;
        }
    }
};

class CommandCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic *c, NimBLEConnInfo &info) override {
        if (!info.isEncrypted() || !info.isAuthenticated()) return;   // only paired phones
        NimBLEAttValue value = c->getValue();
        Command cmd;
        size_t n = value.size() < sizeof(cmd.text) - 1 ? value.size() : sizeof(cmd.text) - 1;
        memcpy(cmd.text, value.data(), n);
        cmd.text[n] = 0;
        _lastActivity = millis();
        if (xQueueSend(_queue, &cmd, 0) != pdTRUE) _dropped = _dropped + 1;
    }
};

void ble_begin(const char *name, uint32_t passkey) {
    pinMode(STATUS_LED_PIN, OUTPUT);
    digitalWrite(STATUS_LED_PIN, LOW);
    _queue   = xQueueCreate(8, sizeof(Command));
    _passkey = passkey;

    NimBLEDevice::init(name);
    NimBLEDevice::setMTU(BLE_MTU);

    // LE Secure Connections + passkey (MITM protection) + bonding. The box
    // "displays" the passkey (it is printed on the label); the phone types it.
    // No fixed passkey is set, so onPassKeyDisplay() decides it (pairing mode).
    // Identity keys are exchanged, so a paired phone is recognised even though
    // Android changes its Bluetooth address every few minutes.
    NimBLEDevice::setSecurityAuth(true, true, true);
    NimBLEDevice::setSecurityIOCap(BLE_HS_IO_DISPLAY_ONLY);
    NimBLEDevice::setSecurityInitKey(BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID);
    NimBLEDevice::setSecurityRespKey(BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID);

    _server = NimBLEDevice::createServer();
    _server->setCallbacks(new ServerCallbacks());
    _server->advertiseOnDisconnect(true);

    NimBLEService *service = _server->createService(BLE_SERVICE_UUID);
    NimBLECharacteristic *command = service->createCharacteristic(
        BLE_COMMAND_UUID,
        NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR | NIMBLE_PROPERTY::WRITE_ENC |
            NIMBLE_PROPERTY::WRITE_AUTHEN,
        BLE_COMMAND_MAX);
    command->setCallbacks(new CommandCallbacks());
    _reply = service->createCharacteristic(
        BLE_REPLY_UUID,
        NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC |
            NIMBLE_PROPERTY::READ_AUTHEN);
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

    Serial.printf("Bluetooth: advertising as \"%s\", %d paired phone(s)\n", name,
                  NimBLEDevice::getNumBonds());
}

void ble_update() {
    if (_evConnected)    { _evConnected = false;    Serial.println("Bluetooth: phone connected, asking for encryption"); }
    if (_evMtu)          { _evMtu = false;          Serial.printf("Bluetooth: packet size %u\n", _mtu); }
    if (_evPaired)       { _evPaired = false;       Serial.println("Bluetooth: NEW PHONE PAIRED (passkey accepted)"); }
    else if (_evSecure)  { _evSecure = false;       Serial.println("Bluetooth: paired phone, encrypted link"); }
    _evSecure = false;
    if (_evRejected) {
        _evRejected = false;
        Serial.println(pairingOpen()
            ? "Bluetooth: pairing failed (wrong code?), disconnected"
            : "Bluetooth: phone not paired: rejected (pairing mode is closed)");
    }
    if (_evDisconnected) { _evDisconnected = false; Serial.println("Bluetooth: phone disconnected, advertising again"); }
    if (_dropped) {
        Serial.printf("Bluetooth: %lu command(s) dropped (sent too fast)\n", (unsigned long)_dropped);
        _dropped = 0;
    }

    if (_pairingUntil != 0 && !pairingOpen()) {
        _pairingUntil = 0;
        Serial.println("Pairing mode closed");
    }

    if (_connected && !_secure && millis() - _connectedAt > BLE_UNSECURED_DROP_MS) {
        Serial.println("Bluetooth: phone did not pair within 30 s, disconnecting");
        _connectedAt = millis();
        _server->disconnect(_connHandle);
    } else if (_connected && millis() - _lastActivity > BLE_IDLE_DISCONNECT_MS) {
        Serial.println("Bluetooth: phone silent for 60 s, disconnecting");
        _lastActivity = millis();
        _server->disconnect(_connHandle);
    }
    digitalWrite(STATUS_LED_PIN, _connected ? HIGH : LOW);
}

bool ble_connected() { return _connected; }
bool ble_secure()    { return _connected && _secure; }

uint16_t ble_mtu() { return _mtu; }

void ble_pairing_open(uint32_t ms) {
    uint32_t until = millis() + ms;
    _pairingUntil  = until ? until : 1;
}

void ble_pairing_close() { _pairingUntil = 0; }

bool ble_pairing_active() { return pairingOpen(); }

bool ble_take_paired_event() {
    if (!_pairedEvent) return false;
    _pairedEvent = false;
    return true;
}

int ble_bond_count() { return NimBLEDevice::getNumBonds(); }

void ble_forget_all() {
    NimBLEDevice::deleteAllBonds();
    if (_connected) _server->disconnect(_connHandle);
}

bool ble_next_command(char *buf, size_t len) {
    Command cmd;
    if (!_queue || xQueueReceive(_queue, &cmd, 0) != pdTRUE) return false;
    strncpy(buf, cmd.text, len - 1);
    buf[len - 1] = 0;
    return true;
}

bool ble_send(const char *msg) {
    if (!_connected || !_secure || !_reply) return false;
    size_t len = strlen(msg);
    if (len > (size_t)_mtu - 3) {   // 3 bytes of every packet are protocol header
        Serial.printf("Bluetooth: reply of %u bytes does not fit packet size %u: ask for MTU %d\n",
                      (unsigned)len, _mtu, BLE_MTU);
        return false;
    }
    return _reply->notify(reinterpret_cast<const uint8_t *>(msg), len);
}
