import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_fando/connect_device/bluetooth.dart';
import 'package:flutter_fando/fando_client/client.dart';
import 'package:flutter_fando/partners/partners_list.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FandoLite',
      theme: ThemeData(
          primaryColor: const Color(0xFFFFD573), primaryColorDark: Colors.grey),
      home: FandoLite(title: 'FandoLite'),
    );
  }
}

class FandoLite extends StatefulWidget {
  FandoLite({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _FandoLiteState createState() => _FandoLiteState();
}

class _FandoLiteState extends State<FandoLite> {
  int _balls = 0;
  User _user;
  Client client = Client();
  bool _isConnected = false;
  bool _isRefreshBalls = false;

  void _sessionCreate() async {
    _user = await client.sessionCreate("user@example.com", "password");

    if (_user.id == null) {
      popError('Creating session error. Please check internet connection');
    } else {
      _isConnected = true;
      _balls = _user.balls;
      setState(() {
        return;
      });
    }
  }

  void _refreshBalls() {
    _isRefreshBalls = true;
    setState(() {
      return;
    });
    _getUserInfo();
  }

  void _getUserInfo() async {
    _user = await client.getUserInfo(_user.id);

    _isRefreshBalls = false;
    if (_user.id == null) {
      popError('Get info from server error. Please check internet connection');
    } else {
      _isConnected = true;
      _balls = _user.balls;
    }
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
              ]);
        });
  }

  void _connectDevice(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => FlutterBlueApp(
              userID: _user.id,
            )));
  }

  void _partnersList(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => PartnersList(
              client: client,
            )));
  }

  @override
  void initState() {
    super.initState();
    if (_user == null || _user.id == 0) {
      _sessionCreate();
    } else {
      _getUserInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ElevatedButton(
            style: ButtonStyle(
                backgroundColor:
                    MaterialStateProperty.all(Theme.of(context).primaryColor)),
            child: Text(
              'Reload',
              style: TextStyle(fontSize: 20),
            ),
            onPressed: _sessionCreate,
          ),
        ],
      ),
      body: Center(
          child: Column(
              // direction: Axis.vertical,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
            Expanded(child: Container(), flex: 6),
            Expanded(
                child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          _isConnected ? const Color(0xCC37DE6A) : Colors.grey),
                      minimumSize: MaterialStateProperty.all(Size(200, 100)),
                      // shape: MaterialStateProperty.all<CircleBorder>(
                      //     CircleBorder())
                    ),
                    onPressed: () =>
                        _isConnected ? _connectDevice(context) : null,
                    child: Text(
                      'Start',
                      style: TextStyle(fontSize: 40),
                    )),
                flex: 3),
            Expanded(child: Container(), flex: 1),
            Expanded(
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                        _isConnected
                            ? Theme.of(context).primaryColor
                            : Colors.grey),
                    minimumSize: MaterialStateProperty.all(Size(150, 80)),
                  ),
                  onPressed: () => _isConnected ? _partnersList(context) : null,
                  child: Text(
                    'Partners',
                    style: TextStyle(fontSize: 30),
                  ),
                ),
                flex: 2),
            Expanded(child: Container(), flex: 6),
          ])),

      bottomSheet: LimitedBox(
          maxHeight: 80,
          child: Container(
            color: Colors.white,
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text('You have: $_balls balls',
                      style: TextStyle(
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).primaryColor,
                      )),
                  !_isRefreshBalls
                      ? IconButton(
                          icon: Icon(
                            Icons.refresh,
                            size: 32,
                          ),
                          color: Theme.of(context).primaryColor,
                          onPressed: _refreshBalls)
                      : Container(
                          padding: EdgeInsets.only(left: 20),
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor)))
                ],
              ),
            ),
          )), // a makes auto-formatting nicer for build methods.
    );
  }
}
