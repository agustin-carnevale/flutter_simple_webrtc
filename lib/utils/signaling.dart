import 'package:flutter_webrtc/webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef OnLocalStream(MediaStream stream);
typedef OnRemoteStream(MediaStream stream);
typedef OnConnected();
typedef OnJoined(bool isOk);

class Signaling {
   IO.Socket _socket;
   OnLocalStream onLocalStream;
   OnRemoteStream onRemoteStream;
   OnConnected onConnected;
   OnJoined onJoined;
   RTCPeerConnection _peer;
   MediaStream _localStream;
   String _him, _me;

  set me(String me) {
    this._me = me;
  }

  init() async {
   MediaStream stream = await navigator.getUserMedia({
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
              '480', // Provide your own width, height and frame rate here
          "minHeight": '640',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    });
    _localStream=stream;
    onLocalStream(stream);
    _connect();
  }

  _createPeer() async {
    this._peer = await createPeerConnection({
      "iceServers":[
        {
          "urls":[
            "stun:stun1.l.google.com:19302",
          ]
        }
      ]
    }, {});

    await _peer.addStream(_localStream);

    _peer.onIceCandidate=(RTCIceCandidate candidate){
      if(candidate ==null){
        return;
      }

      //send the ice Candidate
      emit('candidate',{'username': _him, 'candidate': candidate.toMap()});
    };

    _peer.onAddStream=(MediaStream remoteStream){
      remoteStream.getAudioTracks()[0].enableSpeakerphone(true);
      onRemoteStream(remoteStream);
    };
  }

  _connect(){
    _socket = IO.io('https://backend-simple-webrtc.herokuapp.com', <String, dynamic>{
      'transports': ['websocket'],
    });

    _socket.on('connect', (_) {
      print('connected');
      onConnected();
    });

    _socket.on('on-join', (isOk){
      print('EVENT on-join: $isOk');
      onJoined(isOk);
    });

    _socket.on('on-call', (data) async{
      print('EVENT on-call: $data');

      await _createPeer();
      _him = data['username'];
      final offer = data['offer'];

      final RTCSessionDescription description = RTCSessionDescription(offer['sdp'], offer['type']);
      await _peer.setRemoteDescription(description);

      final sdpConstraints = {
        'mandatory':{
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        },
        'optional': []
      };
      final RTCSessionDescription answer = await _peer.createAnswer(sdpConstraints);
      await _peer.setLocalDescription(answer);

      emit('answer',{
        'username': _him,
        'answer': answer.toMap(),
      });
    });

    _socket.on('on-answer', (answer) async{
      print('EVENT on-answer: $answer');

      final RTCSessionDescription description = RTCSessionDescription(answer['sdp'], answer['type']);
      await _peer.setRemoteDescription(description);
    });

    _socket.on('on-candidate', (data) async{
      print('EVENT on-candidate: $data');
      final RTCIceCandidate candidate = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
      await _peer.addCandidate(candidate);
    });
  }

  emit(String eventName, dynamic data){
    _socket?.emit(eventName, data);
  }

  call(String username) async{
    _him = username;
    await _createPeer();

    final sdpConstraints = {
      'mandatory':{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      },
      'optional': []
    };
    final RTCSessionDescription offer = await _peer.createOffer(sdpConstraints);

    //registro offer en mi _peer para luego de acceptada por el otro usuario, 
    //se usara en _peer.onIceCandidate()
    await _peer.setLocalDescription(offer);

    emit('call', {
      'username': username,
      'offer': offer.toMap()
    });
  }

  dispose(){
    _socket?.disconnect();
    _socket=null;
  }
}