#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <AS5600.h>

// -------- Bluetooth Setup --------
const char* SERVICE_UUID = "4fafc201-1fb5-459e-8acb-c74c965c4013";
const char* CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const char* CMD_CHARACTERISTIC_UUID = "0000ff01-0000-1000-8000-00805f9b34fb";
BLEServer* pServer = nullptr;
BLECharacteristic* pTxCharacteristic = nullptr;
BLECharacteristic* pCmdCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;
volatile bool calibrationRequested = false;
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
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.print("Command received: ");
      Serial.println(rxValue);
      if (rxValue[0] == 'C') {
        calibrationRequested = true;
      }
    }
  }
};

// -------- Data Measuring Setup --------

//---notes---
// ADS_1 0x48 //ground
// ADS_2 0x49 //VDD
// ADS_3 0x4A //SDA
// ADS_4 0x4B //SCL

// A0 - A3 = 0x9B
// A1 - A3 = 0xAB
// A2 - A3 = 0xBB

int BLE_LED = 17;
int Batt_LED = 19;
int Board_LED = 15;

float fs = 8; // sampling frequency in Hz, max of 8Hz
int last_i2c_config = -1;
const unsigned long measPeriod = 1000/fs;
unsigned long lastDataMeas = 0;
const unsigned long battCheckPeriod = 5*1000; //number of seconds
unsigned long lastBattCheck = 0;
float battPercent = 100;
bool battLow = false;
bool battLEDon = true;
const unsigned long battBlinkPeriod = 1*1000; //number of seconds
unsigned long lastBattBlink = 0;

AS5600 encoder;
float distanceOffset = 0;

struct ChipArray {
  int i2c_config; // reference to the I2C bus config
  uint8_t address; // I2C address
  uint8_t diffPair; // the A#-A3 differential pair
  String toothNumber; // label for serial monitor
  float offset; // offset constant
  float a; // "a" coefficient of 2nd order polynomial a*x^2 + b*x + c
  float b; // "b" coefficient of 2nd order polynomial a*x^2 + b*x + c
  float c; // "c" coefficient of 2nd order polynomial a*x^2 + b*x + c
  float force; // stored current force (N)
};

ChipArray ADS_Chips[] = {
  {0, 0x48, 0xAB, "Garbage", 0.0}, //Skip zero index
  {0, 0x4B, 0x9B, "Upper 1st Position", 0.0, 0.2737, 6.7839, 0.0, 0.0}, // #1 ADS_4, A0
  {0, 0x4A, 0xBB, "Upper 2nd Position", 0.0, 0.2103, 10.191, 0.0, 0.0}, // #2 ADS_3, A2
  {0, 0x4A, 0x9B, "Upper 3rd Position", 0.0, -0.1478, 12.208, 0.0, 0.0}, // #3 ADS_3, A0
  {0, 0x4A, 0xAB, "Upper 4th Position", 0.0, -0.3439, 15.832, 0.0, 0.0}, // #4 ADS_3, A1
  {0, 0x49, 0xBB, "Upper 5th Position", 0.0, -0.213, 14.474, 0.0, 0.0}, // #5 ADS_2, A2
  {0, 0x49, 0x9B, "Upper 6th Position", 0.0, -0.213, 14.474, 0.0, 0.0}, // #6 ADS_2, A0
  {0, 0x49, 0xAB, "Upper 7th Position", 0.0, -0.3439, 15.832, 0.0, 0.0}, // #7 ADS_2, A1
  {0, 0x48, 0xBB, "Upper 8th Position", 0.0, -0.1478, 12.208, 0.0, 0.0}, // #8 ADS_1, A2
  {0, 0x48, 0x9B, "Upper 9th Position", 0.0, 0.2103, 10.191, 0.0, 0.0}, // #9 ADS_1, A0
  {0, 0x48, 0xAB, "Upper 10th Position", 0.0, 0.2737, 6.7839, 0.0, 0.0}, // #10 ADS_1, A1
  
  {1, 0x4B, 0x9B, "Lower 1st Position", 0.0, 0.4633, 13.001, 0.0, 0.0}, // #11 ADS_8, A0
  {1, 0x4A, 0xBB, "Lower 2nd Position", 0.0, 2.246, 2.5583, 0.0, 0.0}, // #12 ADS_7, A2
  {1, 0x4A, 0x9B, "Lower 3rd Position", 0.0, 0.1863, 10, 0.0, 0.0}, // #13 ADS_7, A0
  {1, 0x4A, 0xAB, "Lower 4th Position", 0.0, 2.0009, 3.0338, 0.0, 0.0}, // #14 ADS_7, A1
  {1, 0x49, 0xBB, "Lower 5th Position", 0.0, 1.6375, 5.4747, 0.0, 0.0}, // #15 ADS_6, A2
  {1, 0x49, 0x9B, "Lower 6th Position", 0.0, 1.6375, 5.4747, 0.0, 0.0}, // #16 ADS_6, A0
  {1, 0x49, 0xAB, "Lower 7th Position", 0.0, 2.0009, 3.0338, 0.0, 0.0}, // #17 ADS_6, A1
  {1, 0x48, 0xBB, "Lower 8th Position", 0.0, 0.1863, 10, 0.0, 0.0}, // #18 ADS_5, A2
  {1, 0x48, 0x9B, "Lower 9th Position", 0.0, 2.246, 2.5583, 0.0, 0.0}, // #19 ADS_5, A0
  {1, 0x48, 0xAB, "Lower 10th Position", 0.0, 0.4633, 13.001, 0.0, 0.0}, // #20 ADS_5, A1
};

#define SDA_0 23
#define SCL_0 16
#define SDA_1 21
#define SCL_1 22






// const int NUM_BITES = 20;

// float randomBites[NUM_BITES];

// float angleSum = 0.0;
// float angleMax = -180.0;
// unsigned long angleCount = 0;

// float biteSum = 0.0;
// float biteMax = 0.0;
// unsigned long biteCount = 0;

// // --- Simulated Battery ---
// float batteryPercent = 100.0;
// unsigned long lastBatteryDrop = 0;

// const unsigned long BATTERY_DROP_INTERVAL = 30000;  // 30 seconds
// const float BATTERY_DROP_AMOUNT = 0.10;             // slow drain

// // --- Helper: Compute Top Quartile Average ---
// float smartAvgBF(float* data, int size) {

//   // Copy array so we don't modify original
//   float temp[NUM_BITES];

//   for (int i = 0; i < size; i++) {
//     temp[i] = data[i];
//   }

//   // Simple bubble sort (small array, fast enough)
//   for (int i = 0; i < size - 1; i++) {
//     for (int j = 0; j < size - i - 1; j++) {
//       if (temp[j] > temp[j + 1]) {
//         float t = temp[j];
//         temp[j] = temp[j + 1];
//         temp[j + 1] = t;
//       }
//     }
//   }

//   int quartileSize = size / 4;  // Top 25%
//   float sum = 0.0;

//   for (int i = size - quartileSize; i < size; i++) {
//     sum += temp[i];
//   }

//   return sum / quartileSize;
// }


void setup() {

  Serial.begin(115200);
  delay(1000);

  // -------- Bluetooth Setup in Setup --------
  BLEDevice::init("OraStretch");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService* pService = pServer->createService(SERVICE_UUID);
  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE | 
    BLECharacteristic::PROPERTY_READ | 
    BLECharacteristic::PROPERTY_NOTIFY);
  pTxCharacteristic->addDescriptor(new BLE2902());
  pCmdCharacteristic = pService->createCharacteristic(
    CMD_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  pCmdCharacteristic->addDescriptor(new BLE2902());
  pCmdCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pService->start();
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();


  // -------- Data Measuring Setup --------
  pinMode(BLE_LED, OUTPUT);
  pinMode(Batt_LED, OUTPUT);
  pinMode(Board_LED, OUTPUT);
  pinMode(A0, INPUT); // battery read pin analog input

  digitalWrite(BLE_LED, HIGH);
  digitalWrite(Batt_LED, HIGH);
  digitalWrite(Board_LED, HIGH); // (off because reversed)

  Wire.begin(21, 22);  // SDA = 21, SCL = 22 (lower)
  encoder.begin();
  encoder.setDirection(AS5600_CLOCK_WISE);

  calcOffset();
}

float readADC(int i) {

  if (ADS_Chips[i].i2c_config != last_i2c_config){
    Wire.end();
    delay(5);
    if (ADS_Chips[i].i2c_config == 0) {
      Wire.begin(SDA_0, SCL_0);
    } else {
      Wire.begin(SDA_1, SCL_1);
    }
    delay(10);
    last_i2c_config = ADS_Chips[i].i2c_config;
  }

  Wire.beginTransmission(ADS_Chips[i].address); //starts drafting a message to ADS_1
  Wire.write(0x01); //sets the data pointed to configs
  Wire.write(ADS_Chips[i].diffPair); //writes record a oneshot A# - A3 measurment
  Wire.write(0xE3); //take a sample within 1.2ms (860 SPS, but a oneshot was asked for above) (used to be 0x83 and 8ms)
  Wire.endTransmission(); //sends the message to ADS_1
  delay(4); //saftey net delay to allow time for the 1.2ms measurment to be completed

  Wire.beginTransmission(ADS_Chips[i].address); //starts drafting another message to ADS_1
  Wire.write(0x00); //sets the data pointer to results
  Wire.endTransmission(); //sends the message to ADS_1

  Wire.requestFrom(ADS_Chips[i].address, 2); //Requests the number at the pointed memory register
  if (Wire.available() == 2) { //if we successfully get 2 bytes (the length of our number)
    int16_t raw = (Wire.read() << 8) | Wire.read();
    return raw * 0.0078125; //converts ADC level into a raw miliVoltage (also deamplifies the x16)
  }
  return -99; //an error occured
}

void calcOffset() {
  int samples = 10;
  for (int i = 0; i <= 20; i++) ADS_Chips[i].offset = 0.0;
  for(int s = 0; s < samples; s++) {
    for (int i = 1; i <= 20; i++) {
      ADS_Chips[i].offset += readADC(i);
    }
    delay(20); 
  }
  for (int i = 1; i <= 20; i++) {
    ADS_Chips[i].offset = ADS_Chips[i].offset / samples;
  }
  distanceOffset = 0;
  for(int s = 0; s < samples; s++) {
    distanceOffset += encoder.rawAngle();
    delay(10); 
  }
  distanceOffset = distanceOffset / samples;
}

float smartAvgCalc() {
  float sum = 0;
  int count = 0;
  float maxBF = 0;
  for (int i = 1; i <= 20; i++) {
    if (ADS_Chips[i].force > maxBF) {
      maxBF = ADS_Chips[i].force;
    }
  }
  for (int i = 1; i <= 20; i++) {
    if (ADS_Chips[i].force > 0.8 * maxBF && ADS_Chips[i].force > 1) {
      sum += ADS_Chips[i].force;
      count++;
    }
  }
  float avg = sum / count;
  if (count > 0 && avg > 2) {
    return avg;
  } else {
    return 0.00;
  }
}

void loop() {
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = true;
    //LOGIC FOR WHEN CONNECTED
  }

  if (!deviceConnected && oldDeviceConnected) {
    oldDeviceConnected = false;
    //LOGIC FOR WHEN DISCONNECTED
    BLEDevice::startAdvertising();
    delay(500);
  }

  if (deviceConnected) {
    unsigned long currentTime = millis();

    if (currentTime - lastDataMeas >= measPeriod) {
      lastDataMeas = currentTime;

      if (currentTime - lastBattCheck >= battCheckPeriod) {
        lastBattCheck = currentTime;
        int A0_read = analogRead(A0);
        float BatVoltage = A0_read * (3.9523 / 4095.0) * 2.06;
        battPercent = 83.333 * BatVoltage - 250;
        if (battPercent < 0) {
          battPercent = 0;
        } else if (battPercent > 100) {
          battPercent = 100;
        }
        bool battLow = false;
        bool battLEDon = true;
        if (battPercent < 30) {
          battLow = true;
        } else {
          battLow = false;
          battLEDon = false;
          digitalWrite(Batt_LED, HIGH); //Switch to low in real case
        }
      }
      if (battLow) {
        if (currentTime - lastBattBlink >= battBlinkPeriod) {
          lastBattBlink = currentTime;
          if (battLEDon) {
            digitalWrite(Batt_LED, LOW);
            battLEDon = false;
          } else {
            digitalWrite(Batt_LED, HIGH);
            battLEDon = true;
          }
        }
      }
      
      digitalWrite(BLE_LED, HIGH);

      if (calibrationRequested) {
        calcOffset();
        Serial.println("calibration requested");
        calibrationRequested = false;
      }
      
      for (int i = 1; i <= 20; i++) {
        float x = readADC(i) - ADS_Chips[i].offset;
        ADS_Chips[i].force = (ADS_Chips[i].a * x * x) + (ADS_Chips[i].b * x) + ADS_Chips[i].c;
        ADS_Chips[i].force = ADS_Chips[i].force * 3.75;
        if (ADS_Chips[i].force < 0) {
          ADS_Chips[i].force = 0;
        }
        //Serial.print(ADS_Chips[i].force, 2);
        if (i < 20) {
          //Serial.print(",");
        }
      }
      //Serial.println();

      float distance = 0.1398 * (encoder.rawAngle() - distanceOffset) + 13.28;
      Serial.println(distance);
      if (distance < 0){
        distance = 0;
      } else if (distance > 60){
        distance = 60;
      }

      float smartAvgBF = smartAvgCalc();

      unsigned long timestamp = millis();

      // Data buffer
      char dataBuffer[600];
      snprintf(
        dataBuffer,
        sizeof(dataBuffer),
        "%lu,%.2f,"
        "%.2f,%.2f,%.2f,%.2f,%.2f,"
        "%.2f,%.2f,%.2f,%.2f,%.2f,"
        "%.2f,%.2f,%.2f,%.2f,%.2f,"
        "%.2f,%.2f,%.2f,%.2f,%.2f,"
        "%.2f,%.1f",

        timestamp,
        distance,
        ADS_Chips[10].force, ADS_Chips[9].force, ADS_Chips[8].force, ADS_Chips[7].force, ADS_Chips[6].force,
        ADS_Chips[5].force, ADS_Chips[4].force, ADS_Chips[3].force, ADS_Chips[2].force, ADS_Chips[1].force,
        ADS_Chips[11].force, ADS_Chips[12].force, ADS_Chips[13].force, ADS_Chips[14].force, ADS_Chips[15].force,
        ADS_Chips[16].force, ADS_Chips[17].force, ADS_Chips[18].force, ADS_Chips[19].force, ADS_Chips[20].force,
        smartAvgBF,
        battPercent
      );
      pTxCharacteristic->setValue(dataBuffer);
      pTxCharacteristic->notify();

    }
  } else {
    // --- LED Blinking Logic (Disconnected State) ---
    digitalWrite(BLE_LED, LOW);
    delay(500);
    digitalWrite(BLE_LED, HIGH);
    delay(500);
  }
}
