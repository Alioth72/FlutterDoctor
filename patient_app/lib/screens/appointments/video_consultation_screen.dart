import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:teleconsult_vitals/teleconsult_vitals.dart';

import '../../firebase_options.dart';
import '../../models/appointment.dart';
import '../../models/teleconsult_models.dart';
import '../../services/teleconsult/bpm_frame_capture_service.dart';
import '../../services/teleconsult/call_service.dart';
import '../../services/teleconsult/merppg_inference_service.dart';
import '../../services/teleconsult/teleconsult_sync_service.dart';

/// Interactive Teleconsultation Video Consultation Screen with
/// In-Build ME-rPPG Camera Heart-Rate Tracking.
class VideoConsultationScreen extends StatefulWidget {
  final Appointment appointment;

  const VideoConsultationScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen>
    with SingleTickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TimingAwareBpmEstimator _bpmEstimator = TimingAwareBpmEstimator();
  final TeleconsultSyncService _syncService = TeleconsultSyncService();

  late final CallLog _callLog;
  late final BpmFrameCaptureService _frameCaptureService;
  late final MerppgInferenceService _merppgInferenceService;

  CallService? _callService;
  FirebaseFirestore? _firestore;

  BpmCaptureDiagnostics _captureDiagnostics = const BpmCaptureDiagnostics.waiting();
  MerppgDiagnostics _merppgDiagnostics = const MerppgDiagnostics.loading();
  BpmEstimate? _bpmEstimate;
  final List<double> _bpmSamples = [];

  String _status = 'Preparing consultation…';
  String? _error;
  bool _muted = false;
  bool _cameraOff = false;
  bool _ending = false;
  bool _hasConsented = false;
  bool _checkingConsent = true;

  // Heartbeat pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _callLog = CallLog(appointmentId: widget.appointment.id);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _merppgInferenceService = MerppgInferenceService(
      onResult: _handleBvpResult,
      onDiagnostics: (diagnostics) {
        if (!mounted) return;
        setState(() => _merppgDiagnostics = diagnostics);
      },
    );

    _frameCaptureService = BpmFrameCaptureService(
      onFaceFrame: (frame) {
        if (!mounted) return;
        unawaited(_merppgInferenceService.process(frame));
      },
      onDiagnostics: _handleCaptureDiagnostics,
    );

    _checkConsentAndInit();
  }

  Future<void> _checkConsentAndInit() async {
    final alreadyConsented = await _syncService.hasConsented(widget.appointment.id);
    if (mounted) {
      setState(() {
        _hasConsented = alreadyConsented;
        _checkingConsent = false;
      });
    }

    if (alreadyConsented) {
      _initTeleconsultation();
    }
  }

  Future<void> _initTeleconsultation() async {
    unawaited(_merppgInferenceService.initialize());

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[VideoConsultationScreen] Firebase init note: $e');
    }

    _startCall();
  }

  Future<void> _grantConsentAndStart() async {
    await _syncService.recordConsent(
      appointmentId: widget.appointment.id,
      isDoctor: false,
    );
    if (mounted) {
      setState(() => _hasConsented = true);
    }
    _initTeleconsultation();
  }

  void _handleBvpResult(MerppgResult result) {
    if (!mounted) return;
    final estimate = _bpmEstimator.addSample(result.timestamp, result.bvp);
    if (estimate != null) {
      setState(() {
        _bpmEstimate = estimate;
        final bpm = estimate.bpm;
        if (bpm != null && bpm >= 40 && bpm <= 200) {
          _bpmSamples.add(bpm);
        }
      });
    }

    unawaited(
      _callService?.sendTelemetry(
        VitalsSampleTelemetry(
          timestamp: result.timestamp,
          bvp: result.bvp,
          inferenceTime: result.inferenceTime,
          processedSamples: _merppgDiagnostics.processedSamples + 1,
          droppedFrames: _merppgDiagnostics.droppedFrames,
          estimate: estimate,
        ).toJson(),
      ),
    );
  }

  void _handleCaptureDiagnostics(BpmCaptureDiagnostics diagnostics) {
    if (!mounted) return;
    setState(() => _captureDiagnostics = diagnostics);
  }

  Future<void> _startCall() async {
    await Future.wait([
      _localRenderer.initialize(),
      _remoteRenderer.initialize(),
    ]);

    if (!mounted) return;

    if (_firestore == null) {
      setState(() {
        _status = 'Local camera & vitals active';
      });
    }

    final service = CallService(
      firestore: _firestore ?? FirebaseFirestore.instance,
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
          _status = 'Local preview mode';
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
      await _startLocalVitals();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Local vitals tracking active';
        _error = error.toString();
      });
      // Fallback: try capturing local stream directly
      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {'facingMode': 'user', 'width': 320, 'height': 240, 'frameRate': 20},
        });
        if (mounted) {
          setState(() => _localRenderer.srcObject = stream);
          final videoTracks = stream.getVideoTracks();
          if (videoTracks.isNotEmpty) {
            await _frameCaptureService.start(videoTracks.first);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _startLocalVitals() async {
    final tracks = _callService?.localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty && !_cameraOff) {
      await _frameCaptureService.start(tracks.first);
    }
  }

  void _toggleMic() {
    setState(() {
      _muted = !_muted;
      _callService?.setMicrophoneEnabled(!_muted);
    });
  }

  void _toggleCamera() {
    setState(() {
      _cameraOff = !_cameraOff;
      _callService?.setCameraEnabled(!_cameraOff);
    });
    if (_cameraOff) {
      _frameCaptureService.stop();
    } else {
      unawaited(_startLocalVitals());
    }
  }

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    _frameCaptureService.stop();
    _merppgInferenceService.dispose();
    await _callService?.hangUp();

    _callLog.endedAt = DateTime.now();
    if (_bpmSamples.isNotEmpty) {
      _callLog.avgBpm =
          _bpmSamples.reduce((a, b) => a + b) / _bpmSamples.length;
      _callLog.bpmSampleCount = _bpmSamples.length;
    }
    await _syncService.saveCallLog(_callLog);

    if (!mounted) return;
    _showSummarySheet();
  }

  void _showSummarySheet() {
    final duration = _callLog.duration ?? Duration.zero;
    final minutes = (duration.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final avgBpmStr = _callLog.avgBpm != null ? '${_callLog.avgBpm!.toStringAsFixed(0)} BPM' : 'N/A';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'Consultation Completed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Dr. ${widget.appointment.doctorName} • ${widget.appointment.doctorSpecialty}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Call Duration', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('$minutes:$seconds', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Container(width: 1, height: 36, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Avg Heart Rate', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(avgBpmStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFE11D48))),
                    ],
                  ),
                  Container(width: 1, height: 36, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Vitals Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      const Text('Synced', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done & Return to Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _frameCaptureService.stop();
    _merppgInferenceService.dispose();
    _callService?.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String get _doctorDisplayName {
    final name = widget.appointment.doctorName.trim();
    if (name.toLowerCase().startsWith('dr.') || name.toLowerCase().startsWith('dr ')) {
      return name;
    }
    return 'Dr. $name';
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingConsent) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    if (!_hasConsented) {
      return _buildConsentScreen();
    }

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
              // 1. Remote Doctor Video or Waiting Background
              if (_remoteRenderer.srcObject != null)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                _buildWaitingDoctorPlaceholder(),

              // 2. Doctor status pill (Top-Left)
              Positioned(
                top: 16,
                left: 16,
                right: 136,
                child: _StatusPill(status: _status, doctorName: _doctorDisplayName),
              ),

              // 3. Local patient camera PIP (Top-Right)
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
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              ),

              // 4. Patient live vitals pill (Right, below PIP)
              Positioned(
                top: 174,
                right: 16,
                child: _PatientVitalsPill(
                  estimate: _bpmEstimate,
                  captureDiagnostics: _captureDiagnostics,
                  inferenceDiagnostics: _merppgDiagnostics,
                  pulseAnimation: _pulseAnimation,
                ),
              ),

              // 5. Error banner (if any)
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

              // 6. Call action buttons (Bottom Row)
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
                      onPressed: _toggleMic,
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
                      onPressed: _toggleCamera,
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

  Widget _buildWaitingDoctorPlaceholder() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF7C3AED), width: 2),
              ),
              child: const Icon(Icons.person_rounded, size: 50, color: Color(0xFFA78BFA)),
            ),
            const SizedBox(height: 20),
            Text(
              _doctorDisplayName,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.appointment.doctorSpecialty,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA78BFA)),
                  ),
                  const SizedBox(width: 10),
                  Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teleconsultation Consent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded, color: Color(0xFF7C3AED), size: 40),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Connect with $_doctorDisplayName',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${widget.appointment.doctorSpecialty} • ${widget.appointment.hospitalName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Patient Consent & AI Vitals Telemetry',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9D5FF), width: 1),
              ),
              child: const Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF7C3AED), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Encrypted Video Call: Audio and video streams are transmitted directly and securely.',
                          style: TextStyle(fontSize: 12.5, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.favorite_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'On-Device Heart Rate Estimation: Your front camera detects facial micro-pulsations (ME-rPPG) to estimate your heart rate (BPM) for your doctor in real time.',
                          style: TextStyle(fontSize: 12.5, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Privacy First: No video is recorded or stored. All vital processing is performed locally on your device.',
                          style: TextStyle(fontSize: 12.5, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _grantConsentAndStart,
                icon: const Icon(Icons.videocam_rounded, color: Colors.white),
                label: const Text(
                  'I Consent • Start Video Call',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.doctorName});
  final String status;
  final String doctorName;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white24, width: 0.8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFF7C3AED),
            child: Icon(Icons.medical_services_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doctorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: status.contains('Connected')
                        ? const Color(0xFF34D399)
                        : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PatientVitalsPill extends StatelessWidget {
  const _PatientVitalsPill({
    required this.estimate,
    required this.captureDiagnostics,
    required this.inferenceDiagnostics,
    required this.pulseAnimation,
  });

  final BpmEstimate? estimate;
  final BpmCaptureDiagnostics captureDiagnostics;
  final MerppgDiagnostics inferenceDiagnostics;
  final Animation<double> pulseAnimation;

  bool get _hasFreshReliableBpm =>
      estimate?.reliable == true &&
      DateTime.now().difference(estimate!.timestamp) < const Duration(seconds: 5);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: _hasFreshReliableBpm ? const Color(0xFF10B981) : Colors.white24,
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScaleTransition(
            scale: pulseAnimation,
            child: Icon(
              Icons.favorite,
              size: 17,
              color: _hasFreshReliableBpm
                  ? Colors.lightGreenAccent
                  : (captureDiagnostics.preparedFaceRate > 0 ? const Color(0xFFF43F5E) : Colors.white70),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _hasFreshReliableBpm
                ? '${estimate!.bpm!.round()} BPM'
                : captureDiagnostics.preparedFaceRate > 0
                ? 'Measuring vitals…'
                : inferenceDiagnostics.error != null
                ? 'Vitals unavailable'
                : 'Finding face…',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
          minimumSize: const Size.square(56),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ],
  );
}

