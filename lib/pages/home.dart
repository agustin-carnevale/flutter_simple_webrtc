import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:simple_webrtc/utils/signaling.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Signaling _signaling = Signaling();
  String _me;
  String _username;

  @override
  void initState() {
    super.initState();
    
    //init renderers
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    _signaling.init();
    _signaling.onConnected = () {};
    _signaling.onLocalStream = (MediaStream stream){
      _localRenderer.srcObject = stream;
      _localRenderer.mirror=true;
    };
    _signaling.onRemoteStream=(MediaStream stream){
      _remoteRenderer.srcObject = stream;
      _remoteRenderer.mirror = true;
    };
    _signaling.onJoined = (bool isOK){
      if(isOK){
        _signaling.me= _username;
        setState(() {
          _me=_username;
        });
      }
    };
  }

  @override
  void dispose() {
    _signaling.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  _inputCall(){
    var username = '';
    showCupertinoDialog(context: context, builder: (context){
      return CupertinoAlertDialog(
        content: CupertinoTextField(
          placeholder: 'call to',
          onChanged: (text) => username = text ,
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('CALL'),
            onPressed: (){
              _signaling.call(username);
              Navigator.pop(context);
            },
          )
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: _me == null 
        ? Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CupertinoTextField(
                placeholder: 'your username',
                textAlign: TextAlign.center,
                onChanged: (text)=> _username=text,
              ),
              SizedBox(height: 20,),
              CupertinoButton(
                child: Text("Join"),
                color: Colors.blue,
                onPressed: (){
                  if(_username.trim().length < 2){
                    return;
                  }
                  _signaling.emit('join', _username);
                }
              )
            ],
          ),
        )
        : Stack(
          children: [
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer),
            ),
            Positioned(
              left: 20,
              bottom: 40,
              child: Transform.scale(
                scale: 0.3,
                alignment: Alignment.bottomLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 480,
                    height: 640,
                    color: Colors.black12,
                    child: RTCVideoView(_localRenderer),
                  ),
                ),
              )
            ),
            Positioned(
              right: 20,
              bottom: 40,
              child: CupertinoButton(
                child: Text("CALL"), 
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: Colors.green,
                onPressed: _inputCall,
              )
            )
          ],
        ),
      ),
    );
  }
}