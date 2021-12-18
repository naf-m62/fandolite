#include <ArduinoBLE.h>
#include <Ultrasonic.h>
#include <Servo.h>
#include <pinDefinitions.h>

// barcode enable https://www.waveshare.com/w/upload/d/dd/Barcode_Scanner_Module_Setting_Manual_EN.pdf
// shoild scan qr-code for setting scanner
// 1) RESTORE FACTORY SETTING  - 11 page
// 2) Open Setting Code Function - 11 page
// 3) Enable UART&All-Code - 13 page
// 4) Command Mode - 21 page

Ultrasonic ultrasonic(2, 3); // назначаем выходы для Trig и Echo
Ultrasonic ultrasonicRight(4, 5); // назначаем выходы для Trig и Echo
Ultrasonic ultrasonicTop(7, 8); // назначаем выходы для Trig и Echo
Ultrasonic ultrasonicLeft(20, 21); // назначаем выходы для Trig и Echo

Servo servop;

UART mySerial(digitalPinToPinName(10), digitalPinToPinName(11), NC, NC);
#define BARCODE_SERIAL mySerial


BLEService conService("19B10000-E8F2-537E-4F6C-D104768A1214"); // BLE Service

// BLE LED Switch Characteristic - custom 128-bit UUID, read and writable by central
BLEByteCharacteristic mainCharacteristic("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEByteCharacteristic distanceFirstCharacteristic("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEIntCharacteristic distanceSecondCharacteristic("19B10003-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEByteCharacteristic containerCharacteristic("19B10004-E8F2-537E-4F6C-D104768A1214", BLERead);
BLEIntCharacteristic scannerCharacteristic("19B10005-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEByteCharacteristic servoCharacteristic("19B10006-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);

const byte LED = LED_BUILTIN;
const byte SERVO = 6;
const int delayBatch = 500;

unsigned int id = 1;
String hashCon = "qwenkscs";
bool isDebugMode = true;
int startDist;
int startDistRight;
int startDistTop;
int startDistLeft;
bool codeSent = false;

void setup() {
  Serial.begin(9600);
  while (!Serial);
  BARCODE_SERIAL.begin(9600);
  pinMode(LED, OUTPUT);
  digitalWrite(LED, LOW);
  startDist = ultrasonic.read();
  startDistRight = ultrasonicRight.read();
  startDistTop = ultrasonicTop.read();
  startDistLeft = ultrasonicLeft.read();

  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");
    while (1);
  }
  BLE.setLocalName("Plastic№1");

  BLE.setAdvertisedService(conService);

  // add the characteristic to the service
  conService.addCharacteristic(mainCharacteristic);
  conService.addCharacteristic(distanceFirstCharacteristic);
  conService.addCharacteristic(distanceSecondCharacteristic);
  conService.addCharacteristic(containerCharacteristic);
  conService.addCharacteristic(scannerCharacteristic);
  conService.addCharacteristic(servoCharacteristic);

  // add service
  BLE.addService(conService);

  // set the initial value for the characeristic:
  mainCharacteristic.writeValue(0);
  distanceFirstCharacteristic.writeValue(startDist);
  distanceSecondCharacteristic.writeValue(startDistRight * 10000 + startDistTop * 100 + startDistLeft);
  containerCharacteristic.writeValue(id);
  servoCharacteristic.writeValue(0);

  // start advertising
  BLE.advertise();

  servop.attach(SERVO);
  servop.write(0);

  Serial.println("start BLE");
}

void loop() {
  BLEDevice central = BLE.central();
  if (!central) {
    delay(delayBatch);
    return;
  }

  digitalWrite(LED, HIGH);

  // print the central's MAC address:
  printDebugMsgToSerial("Connected to central: ", central.address());

  // AUTH

  // SEND STATE

  //  work();
  int dist;

  String scanCode;
  while (central.connected()) {
    if (mainCharacteristic.written()) {
      byte val = mainCharacteristic.value();
      printDebugMsgToSerial("was written: ", String(val));
      switch (mainCharacteristic.value()) {
        case 0xA1:
          dist = ultrasonic.read();
          printDebugMsgToSerial("distance: ", String(dist));
          distanceFirstCharacteristic.writeValue((byte)dist);
          break;
        case 0xB1:
          printDebugMsgToSerial("write ", "servomotor");
          servoCharacteristic.writeValue(0);
          servop.write(90);
          delay(1500);
          servop.write(0);
          servoCharacteristic.writeValue(1);
          break;
        case 0xC1:
          setVolume();
          break;
        case 0xD1:
          {
            flushBarcodeSerial();
            // send command to start scan
            unsigned char bytes[9];
            bytes[0] = 126;
            bytes[1] = 0;
            bytes[2] = 8;
            bytes[3] = 1;
            bytes[4] = 0;
            bytes[5] = 2;
            bytes[6] = 1;
            bytes[7] = 171;
            bytes[8] = 205;
            BARCODE_SERIAL.write(bytes, sizeof(bytes));
            delay(10);
            int index = 0;
            // first 7 bytes are response of scanner module
            // 02 00 00 01 00 33 31
            while (central.connected()) {
              if (BARCODE_SERIAL.available()) {
                index++;
                BARCODE_SERIAL.read();
                if (index >= 7) {
                  break;
                }
              }
              delay(10);
            }
            break;
          }
        default:
          break;
      }
    }
    //    printDebugMsgToSerial("waiting", "avaliable");
    if (!BARCODE_SERIAL.available()) {
      delay(10);
      continue;
    }
    if (!codeSent) {
      // when barcode was scanned, send code and measure volume object
      setVolume();
      printDebugMsgToSerial("sended", " 0xCC");
      scannerCharacteristic.writeValue(0xCC);
      codeSent = true;
    }
    printDebugMsgToSerial("waiting", " for 0xAA");
    if (scannerCharacteristic.value() != 0xAA) {
      delay(10);
      continue;
    }

    int j = 7;
    int res = 0;
    int b = 0;
    while (central.connected() && BARCODE_SERIAL.available()) {
      b = BARCODE_SERIAL.read();
      printDebugMsgToSerial("read value:", String(b));

      // is \CR
      if (b == 0x0D) {
        break;
      }

      res = res + pow(10, j) * (b - 48);
      j--;

      if (j != -1) {
        continue;
      }
      // res = YXXXXXXXX, Y - length, XXXXXXXX - data
      res = res + pow(10, 8) * 8;
      printDebugMsgToSerial("write value:", String(res));
      scannerCharacteristic.writeValue(res);

      while (central.connected() && scannerCharacteristic.value() != 0xFF) {
        //        printDebugMsgToSerial("byte is not: ", "FF000000");
        //        printDebugMsgToSerial("scanner value now: ", String(scannerCharacteristic.value()));
        delay(100);
      }

      j = 7;
      res = 0;
    }
    printDebugMsgToSerial("res value on exit while:", String(res));
    printDebugMsgToSerial("j value on exit while:", String(j));

    res = res + pow(10, 8) * (7 - j);
    printDebugMsgToSerial("rest write value:", String(res));
    if (res != 0) {
      scannerCharacteristic.writeValue(res);
    }

    while (central.connected() && scannerCharacteristic.value() != 0xFF) {
      //      printDebugMsgToSerial("byte is not: ", "FF000000");
      //      printDebugMsgToSerial("scanner value now: ", String(scannerCharacteristic.value()));
      delay(100);
    }
    scannerCharacteristic.writeValue(0xBB);
  }
  return beforeReturn();
}

void printDebugMsgToSerial(String preS, String s) {
  if (!isDebugMode) {
    return;
  }
  Serial.print("DEBUG: ");
  Serial.print(preS);
  Serial.println(s);
}

void flushBarcodeSerial() {
  codeSent = false;
  // read all
  while (BARCODE_SERIAL.available()) {
    printDebugMsgToSerial("barcode available", "");
    int b = BARCODE_SERIAL.read();
    printDebugMsgToSerial("read value:", String(b));
  };
}

void setVolume() {
  int dist2 = ultrasonicRight.read();
  delay(10);
  int dist3 = ultrasonicTop.read();
  delay(10);
  int dist4 = ultrasonicLeft.read();
  printDebugMsgToSerial("distanceRight: ", String(dist2));
  printDebugMsgToSerial("distanceTop: ", String(dist3));
  printDebugMsgToSerial("distanceLeft: ", String(dist4));
  // YYXXZZ - YY-dist2, XX - dist3, ZZ - dist4
  distanceSecondCharacteristic.writeValue(dist2 * 10000 + dist3 * 100 + dist4);
}

void beforeReturn() {
  digitalWrite(LED, LOW);
  mainCharacteristic.writeValue(0);
  distanceFirstCharacteristic.writeValue((byte)startDist);
  distanceSecondCharacteristic.writeValue(startDistRight * 10000 + startDistTop * 100 + startDistLeft);
  scannerCharacteristic.writeValue(0);
  servoCharacteristic.writeValue(0);
  // flush serial
  flushBarcodeSerial();
  printDebugMsgToSerial("before return done", "");
}
