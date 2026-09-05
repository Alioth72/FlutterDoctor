import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

typedef CallStatusCallback = void Function(String status);
typedef RemoteStreamCallback = void Function(MediaStream stream);

class CallService {
  CallService({
    required this.firestore,
    required this.appointmentId,
    required this.isCaller,
    required this.onStatus,
    required this.onRemoteStream,
  });

  final FirebaseFirestore firestore;
  final String appointmentId;
  final bool isCaller;
  final CallStatusCallback onStatus;
  final RemoteStreamCallback onRemoteStream;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candidateSub;
  String? _sessionId;
  bool _closed = false;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];

  MediaStream? get localStream => _localStream;
  RTCPeerConnection? get peerConnection => _peerConnection;

  DocumentReference<Map<String, dynamic>> get _callDoc =>
      firestore.collection('teleconsult_calls').doc(appointmentId);

  Future<List<Map<String, dynamic>>> fetchIceServers() async {
    if (!AppConfig.hasTurnCredentials) {
      throw StateError(
        'TURN_CREDENTIALS_URL is missing. Run with '
        '--dart-define=TURN_CREDENTIALS_URL=https://<app>.metered.live/'
        'api/v1/turn/credentials?apiKey=<key>',
      );
    }
    final response = await http
        .get(Uri.parse(AppConfig.turnCredentialsUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'TURN credential request failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('TURN response was not a JSON array.');
    }
    final servers = decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    if (servers.isEmpty) {
      throw const FormatException('TURN response contained no ICE servers.');
    }
    return servers;
  }

  Future<void> start() async {
    onStatus('Fetching secure relay configuration…');
    final iceServers = await fetchIceServers();
    if (_closed) return;

    onStatus('Requesting camera and microphone…');
    _localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': <String, dynamic>{'facingMode': 'user'},
    });

    _peerConnection = await createPeerConnection(<String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
    _wirePeerCallbacks();

    if (isCaller) {
      await _startCaller();
    } else {
      await _waitForOffer();
    }
  }

  void _wirePeerCallbacks() {
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams.first);
      }
    };
    _peerConnection!.onConnectionState = (state) {
      onStatus(switch (state) {
        RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'Connected',
        RTCPeerConnectionState.RTCPeerConnectionStateConnecting =>
          'Connecting…',
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
          'Connection interrupted…',
        RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
          'Connection failed',
        RTCPeerConnectionState.RTCPeerConnectionStateClosed => 'Call ended',
        _ => 'Preparing call…',
      });
    };
    _peerConnection!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null || _sessionId == null || _closed) return;
      final side = isCaller ? 'patientCandidates' : 'doctorCandidates';
      await _callDoc.collection(side).add(<String, dynamic>{
        ...candidate.toMap(),
        'sessionId': _sessionId,
      });
    };
  }

  Future<void> _startCaller() async {
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _callDoc.set(<String, dynamic>{
      'appointmentId': appointmentId,
      'sessionId': _sessionId,
      'offer': offer.toMap(),
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
    onStatus('Waiting for doctor…');
    _listenForCandidates('doctorCandidates');
    _callSub = _callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (_closed || data == null || data['sessionId'] != _sessionId) return;
      if (data['status'] == 'ended' && data['endedSessionId'] == _sessionId) {
        onStatus('Remote ended the call');
        return;
      }
      final answer = data['answer'];
      if (answer is Map && !_remoteDescriptionSet) {
        await _setRemoteDescription(Map<String, dynamic>.from(answer));
      }
    });
  }

  Future<void> _waitForOffer() async {
    onStatus('Waiting for patient to join…');
    _callSub = _callDoc.snapshots().listen((snapshot) async {
      if (_closed) return;
      final data = snapshot.data();
      if (_sessionId != null) {
        if (data?['status'] == 'ended' &&
            data?['endedSessionId'] == _sessionId) {
          onStatus('Remote ended the call');
        }
        return;
      }
      final offer = data?['offer'];
      final sessionId = data?['sessionId'];
      if (offer is! Map || sessionId is! String) return;
      _sessionId = sessionId;
      await _setRemoteDescription(Map<String, dynamic>.from(offer));
      _listenForCandidates('patientCandidates');
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      await _callDoc.set(<String, dynamic>{
        'answer': answer.toMap(),
        'answerSessionId': sessionId,
        'status': 'connecting',
        'answeredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      onStatus('Connecting…');
    });
  }

  Future<void> _setRemoteDescription(Map<String, dynamic> data) async {
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String?, data['type'] as String?),
    );
    _remoteDescriptionSet = true;
    for (final candidate in _pendingCandidates) {
      await _peerConnection!.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  void _listenForCandidates(String collection) {
    _candidateSub = _callDoc
        .collection(collection)
        .where('sessionId', isEqualTo: _sessionId)
        .snapshots()
        .listen((snapshot) async {
          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final data = change.doc.data();
            if (data == null) continue;
            final candidate = RTCIceCandidate(
              data['candidate'] as String?,
              data['sdpMid'] as String?,
              (data['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (_remoteDescriptionSet) {
              await _peerConnection?.addCandidate(candidate);
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        });
  }

  void setMicrophoneEnabled(bool enabled) {
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  void setCameraEnabled(bool enabled) {
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> hangUp() async {
    if (_closed) return;
    _closed = true;
    await _callSub?.cancel();
    await _candidateSub?.cancel();
    try {
      if (_sessionId != null) {
        await _callDoc.set(<String, dynamic>{
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'endedSessionId': _sessionId,
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Signaling the remote side is best-effort; local media must still stop.
    } finally {
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        track.stop();
      }
      await _localStream?.dispose();
      await _peerConnection?.close();
    }
  }
}
