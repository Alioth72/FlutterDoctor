import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';
import '../services/call_service.dart';

class PatientCallScreen extends StatefulWidget {
  const PatientCallScreen({
    required this.appointment,
    required this.repository,
    required this.firestore,
    super.key,
  });
  final Appointment appointment;
  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;

  @override
  State<PatientCallScreen> createState() => _PatientCallScreenState();
}

class _PatientCallScreenState extends State<PatientCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late final CallLog _callLog;
  CallService? _callService;
  String _status = 'Preparing call…';
  String? _error;
  bool _muted = false;
  bool _cameraOff = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _callLog = CallLog(appointmentId: widget.appointment.id);
    _start();
  }

  Future<void> _start() async {
    await Future.wait(<Future<void>>[
      _localRenderer.initialize(),
      _remoteRenderer.initialize(),
    ]);
    if (!mounted) return;
    if (widget.firestore == null) {
      setState(() {
        _status = 'Setup required';
        _error = 'Firebase is not configured. Follow SETUP.md, then relaunch.';
      });
      return;
    }
    final service = CallService(
      firestore: widget.firestore!,
      appointmentId: widget.appointment.id,
      isCaller: true,
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'Remote ended the call') {
          WidgetsBinding.instance.addPostFrameCallback((_) => _endCall());
        }
        if (status == 'Connected' && _callLog.startedAt == null) {
          _callLog.startedAt = DateTime.now();
        }
        setState(() => _status = status);
      },
      onRemoteStream: (stream) {
        if (mounted) setState(() => _remoteRenderer.srcObject = stream);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = 'Signaling error';
          _error = error.toString();
        });
      },
    );
    _callService = service;
    try {
      await service.start();
      if (mounted) {
        setState(() => _localRenderer.srcObject = service.localStream);
      }
    } catch (error) {
      _callLog.hadError = true;
      if (mounted) {
        setState(() {
          _status = 'Could not start call';
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    _callLog.endedAt = DateTime.now();
    await _callService?.hangUp();
    await widget.repository.saveCallLog(_callLog);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _callService?.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_remoteRenderer.srcObject != null)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                const _WaitingBackground(),
              Positioned(
                top: 16,
                left: 16,
                right: 136,
                child: _StatusPill(status: _status),
              ),
              Positioned(
                top: 16,
                right: 16,
                width: 108,
                height: 148,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: const Color(0xFF1F2937),
                    child: _localRenderer.srcObject == null || _cameraOff
                        ? const Icon(Icons.videocam_off, color: Colors.white)
                        : RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              ),
              if (_error != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _CallButton(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      label: _muted ? 'Unmute' : 'Mute',
                      onPressed: () {
                        setState(() => _muted = !_muted);
                        _callService?.setMicrophoneEnabled(!_muted);
                      },
                    ),
                    _CallButton(
                      icon: Icons.call_end,
                      label: 'End',
                      color: Colors.red,
                      onPressed: _endCall,
                    ),
                    _CallButton(
                      icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                      label: _cameraOff ? 'Camera on' : 'Camera off',
                      onPressed: () {
                        setState(() => _cameraOff = !_cameraOff);
                        _callService?.setCameraEnabled(!_cameraOff);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingBackground extends StatelessWidget {
  const _WaitingBackground();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF102A2D),
    child: Center(
      child: CircleAvatar(
        radius: 54,
        child: Icon(Icons.medical_services_outlined, size: 48),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(status, style: const TextStyle(color: Colors.white)),
    ),
  );
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = const Color(0xCC374151),
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.square(58),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ],
  );
}
