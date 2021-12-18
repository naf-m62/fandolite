import 'dart:async';
import 'dart:io';

import 'package:hex/hex.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

const commandMeasureDistanceFirst = 161; // A1 - hex
const commandRoundServoMotor = 177; // B1 - hex
const commandMeasureDistanceSecond = 193; // C1 - hex
const commandStartScan = 209; // D1 - hex

const timeBetweenCommand = 250; // milliseconds

// todo change uuids to custom
const bleServiceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
const bleCommandCharacteristicUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";
const bleFirstCharacteristicUuid = "19B10002-E8F2-537E-4F6C-D104768A1214";
const bleObjectCharacteristicUuid = "19B10003-E8F2-537E-4F6C-D104768A1214";
const bleContainerCharacteristicUuid = "19B10004-E8F2-537E-4F6C-D104768A1214";
const bleScannerCharacteristicUuid = "19B10005-E8F2-537E-4F6C-D104768A1214";
const bleServoCharacteristicUuid = "19B10006-E8F2-537E-4F6C-D104768A1214";

const scanNumberOfAttempts = 50;
const scanTimeout = 5100; // milliseconds
const servoTimeout = 2000;
const readCharacteristicTimeout = 5000;

const codeSuccess = 100;
const codeUnknownError = 101;
const codeTimeoutError = 102;

class BleDeviceWrapper {
  BluetoothDevice device;
  int containerID = 0;
  int startDist1 = 0;
  int startObjectVolume = 0;
  BleDeviceWrapper(BluetoothDevice device) {
    this.device = device;
  }

  bool _isFoundedService = false;
  bool _isFoundedCommandCharacteristics = false;
  bool _isFoundedFirstDistanceCharacteristics = false;
  bool _isFoundedObjectVolumeCharacteristics = false;
  bool _isFoundedScannerCharacteristics = false;
  bool _isFoundedServoCharacteristics = false;
  BluetoothService _foundedService;
  BluetoothCharacteristic _commandCharacteristic;
  BluetoothCharacteristic _firstDistanceCharacteristic;
  BluetoothCharacteristic _objectVolumeCharacteristic;
  BluetoothCharacteristic _scannerCharacteristic;
  BluetoothCharacteristic _servoCharacteristic;

  Future<void> getService() async {
    device.discoverServices();

    device.services.forEach((s) {
      s.forEach((e) {
        print(e.uuid);
        if (e.uuid.toString().toUpperCase() == bleServiceUuid) {
          _foundedService = e;
        }
      });
    });
    if (_foundedService != null) {
      _isFoundedService = true;
    } else {
      _isFoundedService = false;
    }
  }

  Future<void> getCharacteristics() async {
    if (!_isFoundedService) {
      getService();
    }
    if (!_isFoundedService) {
      return;
    }

    _foundedService.characteristics.forEach((e) async {
      switch (e.uuid.toString().toUpperCase()) {
        case bleCommandCharacteristicUuid:
          _commandCharacteristic = e;
          break;
        case bleFirstCharacteristicUuid:
          _firstDistanceCharacteristic = e;
          break;
        case bleObjectCharacteristicUuid:
          _objectVolumeCharacteristic = e;
          break;
        case bleContainerCharacteristicUuid:
          setContainerInfo(e);
          break;
        case bleScannerCharacteristicUuid:
          _scannerCharacteristic = e;
          break;
        case bleServoCharacteristicUuid:
          _servoCharacteristic = e;
          break;
      }
    });
    if (_commandCharacteristic != null) {
      _isFoundedCommandCharacteristics = true;
    } else {
      _isFoundedCommandCharacteristics = false;
    }
    if (_firstDistanceCharacteristic != null) {
      _isFoundedFirstDistanceCharacteristics = true;
    } else {
      _isFoundedFirstDistanceCharacteristics = false;
    }
    if (_objectVolumeCharacteristic != null) {
      _isFoundedObjectVolumeCharacteristics = true;
    } else {
      _isFoundedObjectVolumeCharacteristics = false;
    }
    if (_scannerCharacteristic != null) {
      _isFoundedScannerCharacteristics = true;
    } else {
      _isFoundedScannerCharacteristics = false;
    }
    if (_servoCharacteristic != null) {
      _isFoundedServoCharacteristics = true;
    } else {
      _isFoundedServoCharacteristics = false;
    }
    // just read to get start values on connect
    if (startDist1 <= 0) {
      startDist1 = await getDistanceFromFirst();
    }
    if (startObjectVolume <= 0) {
      startObjectVolume = await getObjectVolume();
    }
  }

  Future<int> measureAndGetDistanceFromFirst() async {
    measureDistanceFromFirst();
    await new Future.delayed(const Duration(milliseconds: timeBetweenCommand));
    return getDistanceFromFirst();
  }

  Future<int> measureAndGetObjectVolume() async {
    measureObjectVolume();
    await new Future.delayed(const Duration(milliseconds: timeBetweenCommand));
    return getObjectVolume();
  }

  measureDistanceFromFirst() {
    writeCommand(commandMeasureDistanceFirst);
  }

  measureObjectVolume() {
    writeCommand(commandMeasureDistanceSecond);
  }

  writeCommand(int command) {
    if (!_isFoundedCommandCharacteristics || containerID == 0) {
      getCharacteristics();
    }
    if (!_isFoundedCommandCharacteristics) {
      return;
    }

    device.discoverServices();
    sleep(const Duration(milliseconds: timeBetweenCommand));
    _commandCharacteristic.write([command]);
  }

  Future<int> getDistanceFromFirst() async {
    if (!_isFoundedFirstDistanceCharacteristics) {
      getCharacteristics();
    }
    if (!_isFoundedFirstDistanceCharacteristics) {
      return 0;
    }
    var dist = await getDistance(_firstDistanceCharacteristic);
    if (startDist1 <= 0) {
      startDist1 = dist;
    }
    return dist;
  }

  Future<int> getDistance(BluetoothCharacteristic characteristic) async {
    int prevDist = -1;
    int dist = -1;
    while (true) {
      await readCharacteristic(characteristic);

      String distance = characteristic.lastValue.toString();
      distance = distance.replaceAll("[", "");
      distance = distance.replaceAll("]", "");

      if (distance != "") {
        dist = int.parse(distance);
      }
      if (prevDist == dist) {
        break;
      }
      prevDist = dist;
    }
    return dist;
  }

  Future<int> getObjectVolume() async {
    if (!_isFoundedObjectVolumeCharacteristics) {
      getCharacteristics();
    }
    if (!_isFoundedObjectVolumeCharacteristics) {
      return 0;
    }
    await readCharacteristic(_objectVolumeCharacteristic);
    List<int> res = _objectVolumeCharacteristic.lastValue;
    List<int> newList = [];
    for (int i = res.length - 1; i >= 0; i--) {
      newList.add(res[i]);
    }
    String hex = HEX.encode(newList);
    if (hex == "") {
      return 0;
    }
    int dec = int.parse(hex, radix: 16);
    String decStr = dec.toString();
    var right = int.parse(decStr.substring(0, decStr.length - 4));
    var top = int.parse(decStr.substring(decStr.length - 4, decStr.length - 2));
    var left = int.parse(decStr.substring(decStr.length - 2));

    if (startObjectVolume <= 0) {
      startObjectVolume = right + top + left;
    }

    return right + top + left;
  }

  Future setContainerInfo(BluetoothCharacteristic characteristic) async {
    await readCharacteristic(characteristic);
    String con = characteristic.lastValue.toString();
    con = con.replaceAll("[", "");
    con = con.replaceAll("]", "");

    if (con != "") {
      containerID = int.parse(con);
    }
  }

  Future readCharacteristic(BluetoothCharacteristic characteristic) async {
    DateTime startTime = DateTime.now();
    while (!isTimeout(startTime, readCharacteristicTimeout)) {
      try {
        await characteristic.read();
      } on PlatformException catch (e) {
        if (e.code == "read_characteristic_error" &&
            e.message ==
                "unknown reason, may occur if readCharacteristic was called before last read finished.") {
          continue;
        }
      }
      break;
    }
  }

  Future<int> roundServoMotor() async {
    if (!_isFoundedServoCharacteristics) {
      getCharacteristics();
    }
    if (!_isFoundedServoCharacteristics) {
      return codeUnknownError;
    }
    writeCommand(commandRoundServoMotor);
    // wait for characteristic change
    sleep(const Duration(milliseconds: timeBetweenCommand));
    DateTime startTime = DateTime.now();
    while (true) {
      if (isTimeout(startTime, servoTimeout)) {
        return codeTimeoutError;
      }
      await readCharacteristic(_servoCharacteristic);
      String bStr = _servoCharacteristic.lastValue
          .toString()
          .replaceAll("[", "")
          .replaceAll("]", "");
      if (bStr == "1") {
        return codeSuccess;
      }
      sleep(const Duration(milliseconds: 100));
    }
  }

  disconnect() async {
    await device.disconnect();
  }

  // scanBarcode send command to start scan and read barcode from characteristic
  Future<ScanResultWrapper> scanBarcode() async {
    ScanResultWrapper scanRes = ScanResultWrapper();
    writeCommand(commandStartScan);
    DateTime startTime = DateTime.now();
    // wait while barcode be scanned. When it was scanned the container send code 'CC'
    while (true) {
      if (isTimeout(startTime, scanTimeout)) {
        return scanRes;
      }
      int tmpDist1 = await measureAndGetDistanceFromFirst();
      // it is mean hand is out. Stop scanning
      if (tmpDist1 - startDist1 >= 2 && tmpDist1 - startDist1 < 5) {
        return scanRes;
      }
      await readCharacteristic(_scannerCharacteristic);
      String bStr = _scannerCharacteristic.lastValue
          .toString()
          .replaceAll("[", "")
          .replaceAll("]", "");
      if (bStr == "204, 0, 0, 0") {
        break;
      }
    }

    // get object volume to to equal in next step
    scanRes.objectVolume = await getObjectVolume();

    // send phone is ready
    writeToScanCharacteristic([170, 0, 0, 0]);

    List<List<int>> res = [];
    for (int i = 1; i <= scanNumberOfAttempts; i++) {
      await readCharacteristic(_scannerCharacteristic);
      List<int> b = _scannerCharacteristic.lastValue;

      String bStr = b.toString().replaceAll("[", "").replaceAll("]", "");
      if (bStr.isEmpty ||
          bStr == "170, 0, 0, 0" ||
          bStr == "255, 0, 0, 0" ||
          bStr == "204, 0, 0, 0") {
        sleep(const Duration(milliseconds: timeBetweenCommand));
        continue;
      }
      // last value is BB
      if (bStr == "187, 0, 0, 0") {
        break;
      }

      res.add(b);
      writeToScanCharacteristic([255, 0, 0, 0]);
    }

    String result = "";
    for (int i = 0; i < res.length; i++) {
      List<int> newList = [];
      for (int j = res[i].length - 1; j >= 0; j--) {
        newList.add(res[i][j]);
      }
      String hex = HEX.encode(newList);
      int dec = int.parse(hex, radix: 16);
      int count = int.parse(dec.toString().substring(0, 1));
      String partCode = dec.toString().substring(1, 1 + count);
      result = result + partCode;
    }
    scanRes.scanCode = result;
    return scanRes;
  }

  writeToScanCharacteristic(List<int> list) {
    if (!_isFoundedScannerCharacteristics) {
      getCharacteristics();
    }
    if (!_isFoundedScannerCharacteristics) {
      return;
    }

    device.discoverServices();
    sleep(const Duration(milliseconds: timeBetweenCommand));
    _scannerCharacteristic.write(list);
    sleep(const Duration(milliseconds: timeBetweenCommand));
  }

  // isTimeout if timeout reach return true
  bool isTimeout(DateTime startTime, int timeout) {
    return DateTime.now()
        .isAfter(startTime.add(Duration(milliseconds: timeout)));
  }
}

class ScanResultWrapper {
  String scanCode = "";
  int objectVolume = 0;
  ScanResultWrapper() {
    scanCode = "";
    objectVolume = 0;
  }
}
