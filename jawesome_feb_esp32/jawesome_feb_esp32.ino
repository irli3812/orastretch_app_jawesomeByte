/*
  ESP32C6 Random Angle Sender for Flutter App
  
  This sketch sets up the XIAO ESP32C6 as a BLE Peripheral (Server) and
  transmits a simulated random angle value to a central device (Flutter App).
  
  FIX: Implemented active-low LED logic for GPIO 15 (LOW = ON, HIGH = OFF).
*/

// --- 1. NATIVE ESP32 BLE LIBRARY INCLUDES ---
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h> // Mandatory for Notifications
#include <esp_system.h> // Required for esp_random()
#include <stdio.h>

// --- 2. CONFIGURATION ---
// These UUIDs MUST match the Flutter application's definitions
const char* SERVICE_UUID = "4fafc201-1fb5-459e-8acb-c74c965c4013";
const char* CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
// Using GPIO 15 as confirmed.
const int yellowLED = 15; 

// --- 3.a. BLE POINTERS AND STATE ---
BLEServer* pServer = nullptr;
BLECharacteristic* pTxCharacteristic = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// --- 5. CALLBACK CLASS FOR CONNECTION HANDLING ---
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Central connected.");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Central disconnected.");
    }
};

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
    BLEDevice::init("OraStretch");

    // 2. Create the BLE Server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // 3. Create the BLE Service
    BLEService* pService = pServer->createService(SERVICE_UUID);

    // 4. Create the BLE Characteristic (READ, NOTIFY)
    pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID,
                        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
                      );
    
    // 5. Add Notification Descriptor
    pTxCharacteristic->addDescriptor(new BLE2902());

    // 6. Start the Service
    pService->start();

    // 7. Start Advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
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
        // Delay to allow the disconnect event to settle before restarting the loop
        delay(500); 
    }

    // --- Data Transmission Logic (Connected State) ---
    if (deviceConnected) {
        // FIX: Re-assert the ON state (LOW) at the start of every cycle.
        digitalWrite(yellowLED, LOW); 

        // 1. Generate a random angle (e.g., between -180.00 and 180.00)
        uint32_t randomInt = esp_random();
        const float UINT32_MAX_F = 4294967295.0; 
        
        // Normalize and map to -180.0 to 180.0
        float normalized = (float)randomInt / UINT32_MAX_F; 
        float randomAngle = (normalized * 360.0) - 180.0;
        
        // 2.a. For elapsed timing
        unsigned long timestamp = millis();

        // 2.b. Format the float into a single string
        char dataBuffer[10];
        snprintf(dataBuffer, sizeof(dataBuffer), "%lu,%.2f", (unsigned int)timestamp, randomAngle);

        // 3. Transmit Data
        Serial.print("Sending Time & Angle: ");
        Serial.println(dataBuffer);

        pTxCharacteristic->setValue(dataBuffer);
        pTxCharacteristic->notify();
        
        // Blocking delay between sends (5 times per second).
        // The LED state remains LOW (ON) during this entire delay.
        delay(200);
    } 
    // --- LED Blinking Logic (Disconnected State) ---
    else {
        // Simple blocking blink: LOW = ON, HIGH = OFF
        digitalWrite(yellowLED, LOW);
        delay(750);
        digitalWrite(yellowLED, HIGH);
        delay(750);
    }
}