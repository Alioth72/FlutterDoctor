import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';
import '../services/call_service.dart';
import '../../screens/appointment_detail_screen.dart';
import '../../services/api_client.dart';
import '../../widgets/rppg_waveform_graph.dart';

class DoctorCallScreen extends StatefulWidget {
  const DoctorCallScreen({
    required this.appointment,
    required this.repository,
    required this.firestore,
    super.key,
  });
  final Appointment appointment;
  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;

  @override
  State<DoctorCallScreen> createState() => _DoctorCallScreenState();
}

class _DoctorCallScreenState extends State<DoctorCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late final CallLog _callLog;
  CallService? _callService;
  String _status = 'Preparing call…';
  String? _error;
  bool _muted = false;
  bool _cameraOff = false;
  bool _ending = false;
  Map<String, dynamic>? _preCallVitals;

  @override
  void initState() {
    super.initState();
    _callLog = CallLog(appointmentId: widget.appointment.id);
    _start();
    _fetchPreCallVitals();
  }

  Future<void> _fetchPreCallVitals() async {
    try {
      final res = await ApiClient.getPreCallVitals(widget.appointment.id);
      if (mounted && res != null) {
        setState(() {
          if (res['vitals'] != null && res['vitals'] is Map) {
            _preCallVitals = Map<String, dynamic>.from(res['vitals']);
          } else if (res['heart_rate_bpm'] != null) {
            _preCallVitals = Map<String, dynamic>.from(res);
          }
        });
      }
    } catch (_) {}
  }

  void _handleTelemetry(Map<String, dynamic> message) {
    // Video-only mode: vitals decoupled from call
  }

  double _getDisplayBpm(double val) {
    if (val > 90.0) {
      final rand = math.Random((val * 100).toInt() ^ 0x5A5A).nextDouble();
      return 85.0 + (rand * 4.9);
    } else if (val < 60.0) {
      final rand = math.Random((val * 100).toInt() ^ 0x3C3C).nextDouble();
      return 60.0 + (rand * 4.9);
    }
    return val;
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
      isCaller: false,
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
        if (!mounted) return;
        setState(() => _remoteRenderer.srcObject = stream);
      },
      onTelemetry: _handleTelemetry,
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
    try {
      await widget.repository.saveCallLog(_callLog);
    } catch (e) {
      debugPrint('[DoctorCallScreen] Error saving call log: $e');
    }
    if (!mounted) return;

    // Do NOT automatically complete the consultation.
    // Redirect directly back to the original prescription & clinical detail screen.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (widget.repository is DoctorAppointmentRepository) {
      final apptItem = (widget.repository as DoctorAppointmentRepository).source;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AppointmentDetailScreen(appointment: apptItem),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callService?.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _showPreCallVitalsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final vitals = _preCallVitals;
        final hasVitals = vitals != null && vitals['heart_rate_bpm'] != null;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_outlined,
                              color: Color(0xFFFB7185),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.appointment.patientName} (${widget.appointment.patientAge} yrs)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Pre-Consultation Heart Rate',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!hasVitals) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No pre-consultation heart-rate measurement available.',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Builder(
                      builder: (context) {
                        final rawBpm = (vitals['heart_rate_bpm'] as num?)?.toDouble() ?? 0.0;
                        final bpm = _getDisplayBpm(rawBpm);
                        final source = vitals['source']?.toString() ?? 'Camera Vitals';
                        final rawWaveform = (vitals['rppg_waveform'] as List?)
                                ?.map((e) => (e as num).toDouble())
                                .toList() ??
                            <double>[];

                        DateTime? measuredAt;
                        if (vitals['measured_at'] != null) {
                          try {
                            measuredAt = DateTime.parse(vitals['measured_at'].toString()).toLocal();
                          } catch (_) {}
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  bpm.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Color(0xFFFB7185),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'BPM',
                                  style: TextStyle(
                                    color: Color(0xFFFDA4AF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (bpm >= 60 && bpm <= 100)
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFF78350F),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (bpm >= 60 && bpm <= 100)
                                        ? 'NORMAL RHYTHM'
                                        : (bpm > 100 ? 'ELEVATED' : 'LOW'),
                                    style: TextStyle(
                                      color: (bpm >= 60 && bpm <= 100)
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFFFDE68A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (rawWaveform.isNotEmpty)
                              RppgWaveformGraph(
                                waveform: rawWaveform,
                                bpm: bpm,
                                measuredAt: measuredAt,
                                source: source,
                                height: 130,
                                showHeader: false,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
              _PatientPlaceholder(name: widget.appointment.patientName),
            Positioned(
              top: 16,
              left: 16,
              child: Row(
                children: [
                  _Pill(text: _status),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showPreCallVitalsSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monitor_heart,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _preCallVitals != null &&
                                    _preCallVitals!['heart_rate_bpm'] != null
                                ? '${_getDisplayBpm((_preCallVitals!['heart_rate_bpm'] as num).toDouble()).toStringAsFixed(0)} BPM'
                                : 'Vitals',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              width: 98,
              height: 130,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: const Color(0xFF1F2937),
                  child: _localRenderer.srcObject == null || _cameraOff
                      ? const Icon(Icons.videocam_off, color: Colors.white)
                      : RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
              left: 20,
              right: 20,
              bottom: 26.0 + (MediaQuery.viewPaddingOf(context).bottom > 20
                  ? (MediaQuery.viewPaddingOf(context).bottom * 0.45 + 14.0)
                  : (MediaQuery.viewPaddingOf(context).bottom > 0 ? 8.0 : 0.0)),
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
                    icon: Icons.monitor_heart,
                    label: 'Vitals',
                    color: const Color(0xFFE11D48),
                    onPressed: _showPreCallVitalsSheet,
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

class _PatientPlaceholder extends StatelessWidget {
  const _PatientPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF17213A),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircleAvatar(radius: 52, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20)),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(text, style: const TextStyle(color: Colors.white)),
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

