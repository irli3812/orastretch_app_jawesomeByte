/*
  ESP32C6 Random Angle Sender for Flutter App
  
  This sketch sets up the XIAO ESP32C6 as a BLE Peripheral (Server) and
  transmits a simulated random angle value to a central device (Flutter App).
  
  Wrote 752528 bytes (455353 compressed) at 0x00010000 in 2.9 seconds (2072.3 kbit/s).
*/

// --- 1. NATIVE ESP32 BLE LIBRARY INCLUDES ---
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>     // Mandatory for Notifications
#include <esp_system.h>  // Required for esp_random()
#include <stdio.h>
#include <math.h>

// --- 2. CONFIGURATION ---
// These UUIDs MUST match the Flutter application's definitions
const char* SERVICE_UUID = "4fafc201-1fb5-459e-8acb-c74c965c4013";
const char* CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const char* CMD_CHARACTERISTIC_UUID = "0000ff01-0000-1000-8000-00805f9b34fb";

// Using GPIO 15 as confirmed.
const int yellowLED = 15;


// --- 3.a. BLE POINTERS AND STATE ---
BLEServer* pServer = nullptr;
BLECharacteristic* pTxCharacteristic = nullptr;
BLECharacteristic* pCmdCharacteristic = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;


// --- 3.b. Data Tracking Variables ---
const int NUM_BITES = 20;

float randomBites[NUM_BITES];

float angleSum = 0.0;
float angleMax = -180.0;
unsigned long angleCount = 0;

float biteSum = 0.0;
float biteMax = 0.0;
unsigned long biteCount = 0;

// --- Simulated Battery ---
float batteryPercent = 100.0;
unsigned long lastBatteryDrop = 0;

const unsigned long BATTERY_DROP_INTERVAL = 30000;  // 30 seconds
const float BATTERY_DROP_AMOUNT = 0.10;             // slow drain


// --- 5. CALLBACK CLASS FOR CONNECTION HANDLING ---
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Central connected.");
  };

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Central disconnected.");
  }
};


class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {

    String value = pCharacteristic->getValue();
    value.trim();

    if (value == "RESET") {

      Serial.println("Reset cmd received");

      angleSum = 0.0;
      angleMax = 0.0;
      angleCount = 0;

      biteSum = 0.0;
      biteMax = 0.0;
      biteCount = 0;
    }
  }
};

// --- Helper: Compute Top Quartile Average ---
float computeTopQuartileAvg(float* data, int size) {

  // Copy array so we don't modify original
  float temp[size];

  for (int i = 0; i < size; i++) {
    temp[i] = data[i];
  }

  // Simple bubble sort (small array, fast enough)
  for (int i = 0; i < size - 1; i++) {
    for (int j = 0; j < size - i - 1; j++) {
      if (temp[j] > temp[j + 1]) {
        float t = temp[j];
        temp[j] = temp[j + 1];
        temp[j + 1] = t;
      }
    }
  }

  int quartileSize = size / 4;  // Top 25%
  float sum = 0.0;

  for (int i = size - quartileSize; i < size; i++) {
    sum += temp[i];
  }

  return sum / quartileSize;
}

// --- 6. INITIALIZATION ---
void setup() {

  Serial.begin(115200);
  Serial.println("Starting ESP32C6 BLE Random Angle Server...");

  // --- Pin Setup ---
  pinMode(yellowLED, OUTPUT);

  // Initial state: HIGH is OFF for an active-low LED
  digitalWrite(yellowLED, HIGH);


  // --- BLE Setup ---

  // 1. Initialize BLE Device and set Local Name
  BLEDevice::init("OraStretch_RESET_TEST");

  // 2. Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // 3. Create the BLE Service
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // 4. Create DATA characteristic (READ + NOTIFY)
  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);

  pTxCharacteristic->addDescriptor(new BLE2902());


  // 5. Create COMMAND characteristic (WRITE)
  pCmdCharacteristic = pService->createCharacteristic(
    CMD_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  pCmdCharacteristic->addDescriptor(new BLE2902());
  pCmdCharacteristic->setCallbacks(new MyCharacteristicCallbacks());


  // 6. Start the Service
  pService->start();


  // 7. Start Advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();

  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);

  BLEDevice::startAdvertising();

  Serial.println("BLE advertising started as 'OraStretch'");
}


// --- 7. MAIN LOOP (BLOCKING) ---
void loop() {

  // Check connection transitions: DISCONNECTED -> CONNECTED
  if (deviceConnected && !oldDeviceConnected) {

    oldDeviceConnected = true;

    // FIX: LOW = ON
    digitalWrite(yellowLED, LOW);

    Serial.println("LED Solid ON");
  }


  // Check connection transitions: CONNECTED -> DISCONNECTED
  if (!deviceConnected && oldDeviceConnected) {

    oldDeviceConnected = false;

    // FIX: HIGH = OFF
    digitalWrite(yellowLED, HIGH);

    Serial.println("LED OFF, starting blink");

    // Restart advertising
    BLEDevice::startAdvertising();

    // Delay to allow the disconnect event to settle
    delay(500);
  }


  // --- Data Transmission Logic (Connected State) ---
  if (deviceConnected) {

    // --- Simulate battery drain ---
    unsigned long now = millis();

    if (now - lastBatteryDrop > BATTERY_DROP_INTERVAL) {

      batteryPercent -= BATTERY_DROP_AMOUNT;

      if (batteryPercent < 5.0) {
        batteryPercent = 100.0;  // reset for testing
      }

      lastBatteryDrop = now;
    }

    // Re-assert the ON state (LOW)
    digitalWrite(yellowLED, LOW);

    // 1. Generate random angle (-180 to 180)
    uint32_t randomInt = esp_random();
    const float UINT32_MAX_F = 4294967295.0;

    float normalized = (float)randomInt / UINT32_MAX_F;
    float randomAngle = (normalized * 360.0) - 180.0;
    float distance = fabs(1.0354 * randomAngle + 6.9685);

    angleSum += randomAngle;

    if (randomAngle > angleMax) {
      angleMax = randomAngle;
    }

    angleCount++;


    // --- Generate 20 random bite forces (0-150) ---
    for (int i = 0; i < NUM_BITES; i++) {
      uint32_t biteRand = esp_random();
      float biteNormalized = (float)biteRand / UINT32_MAX_F;

      randomBites[i] = biteNormalized * 150.0;

      biteSum += randomBites[i];

      if (randomBites[i] > biteMax) {
        biteMax = randomBites[i];
      }

      biteCount++;
    }

    float topQuartileAvg = computeTopQuartileAvg(randomBites, NUM_BITES);


    // Timestamp
    unsigned long timestamp = millis();


    // Data buffer
    char dataBuffer[600];
    int offset = 0;


    // Append quartile calc + battery
    offset += snprintf(
      dataBuffer + offset,
      sizeof(dataBuffer) - offset,
      ",%.2f,%.1f",
      (unsigned int)timestamp,
      distance);

    // Append 20 bite forces
    for (int i = 0; i < NUM_BITES; i++) {

      offset += snprintf(
        dataBuffer + offset,
        sizeof(dataBuffer) - offset,
        ",%.2f",
        randomBites[i]);
    }

    // Send data
    Serial.print("Sending Data: ");
    Serial.println(dataBuffer);

    pTxCharacteristic->setValue(dataBuffer);
    pTxCharacteristic->notify();


    // Send 5x per second
    delay(200);
  }

  // --- LED Blinking Logic (Disconnected State) ---
  else {

    digitalWrite(yellowLED, LOW);
    delay(750);

    digitalWrite(yellowLED, HIGH);
    delay(750);
  }
}