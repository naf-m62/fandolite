import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart'
    as scanBarcode;
import 'package:flutter_fando/connect_device/bluetooth.dart';
import 'package:flutter_fando/connect_device/device_wrapper.dart';
import 'package:flutter_fando/fando_client/client.dart';

const relativeErrForDist1 = 2;
const relativeErrForObject = 5; // in cm

const codeSuccess = 100;
const codeUnknownError = 101;
const codeTimeoutError = 102;

class Controller extends StatefulWidget {
  const Controller({Key key, this.deviceWrapper, this.userID})
      : super(key: key);

  final BleDeviceWrapper deviceWrapper;
  final int userID;

  @override
  _ControllerState createState() => _ControllerState(deviceWrapper);
}

class _ControllerState extends State<Controller> {
  _ControllerState(BleDeviceWrapper deviceWrapper) {
    this._deviceWrapper = deviceWrapper;
  }
  bool _inProgress = false;
  int _dist1 = 0;
  int _objectVolume = 0;
  int _scannedObjectVolume = 0;
  int _startDist1 = 0;
  int _startObjectVolume = 0;
  bool _holeIsEmpty = false;
  bool _handInHole = false;
  bool _objectInHole = false;
  bool _objectDetected = false;
  bool _objectDetectedAndHandOut = false;
  bool _isDebug = true;
  List<String> _log = [];
  String _scanBarcode = 'Unknown';
  int _counter = 0;
  Client _client = Client();
  BleDeviceWrapper _deviceWrapper;

  // for debug
  _logging(String text) {
    if (!_isDebug) {
      return;
    }
    if (_log.length > 20) {
      _log.removeAt(0);
    }
    _log.add(DateTime.now().toString().substring(0, 23) + ' ' + text);
    setState(() {
      return;
    });
  }

  String printLog() {
    String s = "";
    _log.forEach((element) {
      s = s + element + '\n';
    });
    return s;
  }

  clearLog() {
    _log = [];
    setState(() {
      return;
    });
  }

  Future<void> start() async {
    _inProgress = true;
    while (_inProgress) {
      if (!_holeIsEmpty) {
        await checkHoleIsEmpty();
      }
      if (!_holeIsEmpty) {
        continue;
      }

      if (!_handInHole) {
        await checkHandInHole();
      }
      if (!_handInHole) {
        continue;
      }

      if (!_objectDetected) {
        await scanBarcodeNormal();
      }
      if (!_objectDetected) {
        continue;
      }

      if (!_objectDetectedAndHandOut) {
        await checkHandOutHole();
      }
      if (!_objectDetectedAndHandOut) {
        continue;
      }

      await roundServoMotor();

      // check object was dropped down
      await checkHoleIsEmpty();
      if (!_holeIsEmpty) {
        popError('Object was not dropped down. Please try again');
      } else {
        await addBalls();
      }

      setInitState();
    }
  }

  checkHoleIsEmpty() async {
    _logging('checkHoleIsEmpty, volume:' + _objectVolume.toString());

    _objectVolume = await _deviceWrapper.measureAndGetObjectVolume();
    if (_objectVolume < 0) {
      return;
    }
    // при первом обращении заполняется стартовая дистанция,
    // на микроконтроллере оно вычисляется при включении
    // при дисконнекте возвращается в стартовое значение
    if (_startObjectVolume <= 0) {
      _startObjectVolume = _deviceWrapper.startObjectVolume;
      return;
    }

    if (_objectVolume <= _startObjectVolume - relativeErrForObject) {
      _holeIsEmpty = false;
      return;
    }

    _holeIsEmpty = true;

    setState(() {
      return;
    });
  }

  // addBalls добавляет баллы
  addBalls() async {
    await _client.addBall(widget.userID);
    if (_client.statusCode != StatusSuccess) {
      popError('Internal server error');
      return;
    }
    _counter++;
    setState(() {
      return;
    });
  }

  Future<void> stop() async {
    _inProgress = false;

    setInitState();

    setState(() {
      return;
    });
  }

  checkHandInHole() async {
    _logging('checkHandInHole, _dist1:' + _dist1.toString());

    _dist1 = await _deviceWrapper.measureAndGetDistanceFromFirst();
    if (_dist1 < 0) {
      return;
    }
    // при первом обращении заполняется стартовая дистанция,
    // на микроконтроллере оно вычисляется при включении
    // при дисконнекте возвращается в стартовое значение
    if (_startDist1 <= 0) {
      _startDist1 = _deviceWrapper.startDist1;
    }

    if (_dist1 >= _startDist1 - relativeErrForDist1) {
      return;
    }

    _handInHole = true;
    _objectInHole = true;

    setState(() {
      return;
    });
  }

  // todo тащить проверку объема в отдельный метод
  checkHandOutHole() async {
    _logging('checkHandOutHole, _dist1:' + _dist1.toString());

    // check the hand not in hole
    _dist1 = await _deviceWrapper.measureAndGetDistanceFromFirst();
    if (_dist1 < 0) {
      return;
    }
    if (_dist1 < _startDist1 - relativeErrForDist1) {
      return;
    }

    // check the object is in and it's volume the same
    _objectVolume = await _deviceWrapper.measureAndGetObjectVolume();
    if (_objectVolume < 0) {
      return;
    }
    if (_objectVolume > _startObjectVolume - relativeErrForObject) {
      _logging('object not found inside, volume:' + _objectVolume.toString());
      popError('Object not found inside. Please try again');
      setInitState();
      return;
    }
    var volumeDiff = (_scannedObjectVolume - _objectVolume).abs();
    if (volumeDiff > relativeErrForObject) {
      _logging(
          'not the same object inside, volume:' + _objectVolume.toString());
      _logging('not the same object inside, scannedVolume:' +
          _scannedObjectVolume.toString());
      popError('Not the same object inside. Please try again');
      setInitState();
      return;
    }

    _objectDetectedAndHandOut = true;
    setState(() {
      return;
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> scanBarcodeNormal() async {
    _logging('scanBarcodeNormal');
    // String barcodeScanRes;
    // // Platform messages may fail, so we use a try/catch PlatformException.
    // try {
    //   barcodeScanRes = await scanBarcode.FlutterBarcodeScanner.scanBarcode(
    //       '#ff6666', 'Cancel', true, scanBarcode.ScanMode.BARCODE);
    //   print(barcodeScanRes);
    // } on PlatformException {
    //   barcodeScanRes = 'Failed to get platform version.';
    // }
    //
    // // If the widget was removed from the tree while the asynchronous platform
    // // message was in flight, we want to discard the reply rather than calling
    // // setState to update our non-existent appearance.
    // if (!mounted) return;

    // _scanBarcode = barcodeScanRes;

    ScanResultWrapper srw = ScanResultWrapper();
    srw = await _deviceWrapper.scanBarcode();

    // remember scanned object volume
    _scanBarcode = srw.scanCode;
    _scannedObjectVolume = srw.objectVolume;

    if (_scanBarcode == "-1" ||
        _scanBarcode == "Unknown" ||
        _scanBarcode.isEmpty ||
        _scanBarcode == "") {
      setInitState();
      popError('Nothing was scanned, please try again');
      return;
    }
    setState(() {
      return;
    });
    await _client.sendOperationCreate(
        _scanBarcode, widget.userID, _deviceWrapper.containerID);
    if (_client.statusCode != StatusSuccess) {
      setInitState();
      String err = _client.statusCode == StatusNotAccept
          ? 'Not accept this object'
          : 'Internal error';
      popError(err);
      return;
    }

    _objectDetected = true;

    setState(() {
      return;
    });
  }

  roundServoMotor() async {
    _logging('roundServoMotor');
    int code = await _deviceWrapper.roundServoMotor();
    if (code != codeSuccess) {
      if (code == codeTimeoutError) {
        popError(
            "Perhaps servomotor wasn't stand back to start position. Please, call us");
      }
      if (code == codeUnknownError) {
        popError("Something wrong with servomotor. Please, call us");
        setInitState();
        return;
      }
    }

    setState(() {
      return;
    });
  }

  setInitState() {
    _holeIsEmpty = false;
    _handInHole = false;
    _objectDetected = false;
    _objectInHole = false;
    _objectDetectedAndHandOut = false;
    _dist1 = _startDist1;
    _objectVolume = _startObjectVolume;
    _scannedObjectVolume = 0;
    _scanBarcode = 'Unknown';

    setState(() {
      return;
    });
  }

  Future popError(String error) {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error occurred'),
            content: Text('Error: $error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: new Text('OK', style: TextStyle(fontSize: 18)),
              ),
            ],
          );
        });
  }

  disconnect() async {
    await stop();
    await _deviceWrapper.disconnect();
    Navigator.popUntil(context, ModalRoute.withName('/'));
    return;
  }

  Future<bool> _onWillPop() async {
    return (await showDialog(
          context: context,
          builder: (context) => new AlertDialog(
            title: new Text('Are you sure?'),
            content: new Text('Do you want to finish'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: new Text('No', style: TextStyle(fontSize: 18)),
              ),
              TextButton(
                onPressed: () => disconnect(),
                child: new Text('Yes', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_deviceWrapper.device.name),
            backgroundColor: Theme.of(context).primaryColor,
            actions: [
              ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                        Theme.of(context).primaryColor)),
                child: Text(
                  'Disconnect',
                  style: TextStyle(fontSize: 20),
                ),
                onPressed: disconnect,
              ),
            ],
          ),
          body: Center(
              child: Flex(
                  direction: Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                Row(
                  children: [
                    _holeIsEmpty
                        ? Icon(Icons.done_all,
                            color: Theme.of(context).primaryColor)
                        : Icon(Icons.remove_done, color: Colors.grey),
                    Text(
                      ' Hole inside is empty',
                      style: TextStyle(
                        color: _holeIsEmpty
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 20,
                      ),
                    )
                  ],
                ),
                Row(
                  children: [
                    _objectInHole
                        ? Icon(Icons.done_all,
                            color: Theme.of(context).primaryColor)
                        : Icon(Icons.remove_done, color: Colors.grey),
                    Text(
                      ' Set object inside',
                      style: TextStyle(
                        color: _objectInHole
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 20,
                      ),
                    )
                  ],
                ),
                Row(
                  children: [
                    _objectDetected
                        ? Icon(Icons.done_all,
                            color: Theme.of(context).primaryColor)
                        : Icon(Icons.remove_done, color: Colors.grey),
                    Text(
                      !_objectDetected
                          ? ' Scan the object'
                          : ' Scanned the object: $_scanBarcode',
                      style: TextStyle(
                        color: _objectDetected
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 20,
                      ),
                    )
                  ],
                ),
                Row(
                  children: [
                    _objectDetectedAndHandOut
                        ? Icon(Icons.done_all,
                            color: Theme.of(context).primaryColor)
                        : Icon(Icons.remove_done, color: Colors.grey),
                    Text(
                      ' Get your hand out ',
                      style: TextStyle(
                        color: _objectDetectedAndHandOut
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 20,
                      ),
                    )
                  ],
                ),
                ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          !_inProgress
                              ? Theme.of(context).primaryColor
                              : Colors.red)),
                  child:
                      !_inProgress ? Icon(Icons.play_arrow) : Icon(Icons.pause),
                  onPressed: !_inProgress ? start : stop,
                ),
                if (_isDebug)
                  Text('Local log:\n ' + printLog(),
                      style: TextStyle(fontSize: 15)),
                if (_isDebug)
                  ElevatedButton(
                      onPressed: () => clearLog(), child: Text('Clear log')),
              ])),
          bottomSheet: LimitedBox(
              maxHeight: 80,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text('You got balls for the session: $_counter',
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).primaryColor,
                      )),
                ),
              )),
          // a ,
        ));
  }
}
