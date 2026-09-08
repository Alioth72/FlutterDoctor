import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';
import '../services/bpm_estimator.dart';
import '../services/bpm_frame_capture_service.dart';
import '../services/call_service.dart';
import '../services/merppg_inference_service.dart';
import 'post_call_screen.dart';

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
  final List<BpmSample> _bpmSamples = <BpmSample>[];
  late final CallLog _callLog;
  CallService? _callService;
  BpmCaptureDiagnostics _captureDiagnostics =
      const BpmCaptureDiagnostics.waiting();
  MerppgDiagnostics _merppgDiagnostics = const MerppgDiagnostics.loading();
  BpmEstimate? _bpmEstimate;
  String _status = 'Preparing call…';
  String? _error;
  bool _muted = false;
  bool _cameraOff = false;
  bool _ending = false;
  bool _vitalsExpanded = false;

  @override
  void initState() {
    super.initState();
    _callLog = CallLog(appointmentId: widget.appointment.id);
    _start();
  }

  void _handleTelemetry(Map<String, dynamic> message) {
    if (!mounted || message['version'] != 1) return;
    switch (message['type']) {
      case 'captureDiagnostics':
        setState(() {
          _captureDiagnostics = BpmCaptureDiagnostics(
            capturedFrames: _intValue(message['capturedFrames']),
            detectedFaces: _intValue(message['detectedFaces']),
            skippedBusyTicks: _intValue(message['skippedBusyTicks']),
            captureRate: _doubleValue(message['captureRate']),
            preparedFaceRate: _doubleValue(message['preparedFaceRate']),
            faceHitRate: _doubleValue(message['faceHitRate']),
            lastProcessingTime: Duration(
              milliseconds: _intValue(message['processingMs']),
            ),
            lastCaptureTime: Duration(
              milliseconds: _intValue(message['captureMs']),
            ),
            lastDetectionTime: Duration(
              milliseconds: _intValue(message['detectionMs']),
            ),
            lastPreparationTime: Duration(
              milliseconds: _intValue(message['preparationMs']),
            ),
            frameWidth: _intValue(message['frameWidth']),
            frameHeight: _intValue(message['frameHeight']),
            lastError: message['lastError'] as String?,
          );
        });
        return;
      case 'vitalsSample':
        final estimateData = message['estimate'];
        final receivedAt = DateTime.now();
        setState(() {
          _merppgDiagnostics = MerppgDiagnostics(
            status: 'On-device BVP active',
            ready: true,
            processedSamples: _intValue(message['processedSamples']),
            droppedFrames: _intValue(message['droppedFrames']),
            lastInferenceTime: Duration(
              milliseconds: _intValue(message['inferenceMs']),
            ),
            latestBvp: _nullableDoubleValue(message['bvp']),
          );
          if (estimateData is Map) {
            final data = Map<String, dynamic>.from(estimateData);
            final estimate = BpmEstimate(
              timestamp: receivedAt,
              status: data['status'] as String? ?? 'Measuring pulse quality…',
              confidence: _doubleValue(data['confidence']),
              effectiveSampleRate: _doubleValue(data['effectiveSampleRate']),
              sampleCount: _intValue(data['sampleCount']),
              maximumResolvableBpm: _doubleValue(
                data['maximumResolvableBpm'],
              ),
              bpm: _nullableDoubleValue(data['bpm']),
            );
            _bpmEstimate = estimate;
            if (estimate.bpm != null) {
              _bpmSamples.add(
                BpmSample(
                  timestamp: receivedAt,
                  bpm: estimate.bpm!,
                  confidence: estimate.confidence,
                ),
              );
              final cutoff = receivedAt.subtract(const Duration(seconds: 60));
              _bpmSamples.removeWhere(
                (sample) => sample.timestamp.isBefore(cutoff),
              );
            }
          }
        });
        return;
    }
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
    await widget.repository.saveCallLog(_callLog);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PostCallScreen(
          appointment: widget.appointment,
          repository: widget.repository,
          callLog: _callLog,
          bpmSamples: _bpmSamples,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callService?.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
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
            Positioned(top: 16, left: 16, child: _Pill(text: _status)),
            if (_vitalsExpanded)
              Positioned(
                top: 160,
                right: 16,
                child: _VitalsDiagnostics(
                  diagnostics: _captureDiagnostics,
                  merppgDiagnostics: _merppgDiagnostics,
                  bpmEstimate: _bpmEstimate,
                  onClose: () => setState(() => _vitalsExpanded = false),
                ),
              )
            else
              Positioned(
                top: 160,
                right: 16,
                child: _VitalsLauncher(
                  bpmEstimate: _bpmEstimate,
                  onPressed: () => setState(() => _vitalsExpanded = true),
                ),
              ),
            if (_vitalsExpanded)
              Positioned(
                left: 16,
                right: 16,
                bottom: 118,
                height: 138,
                child: _BpmChart(samples: _bpmSamples),
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
              bottom: 26,
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

class _VitalsLauncher extends StatelessWidget {
  const _VitalsLauncher({required this.bpmEstimate, required this.onPressed});

  final BpmEstimate? bpmEstimate;
  final VoidCallback onPressed;

  bool get _hasFreshReliableBpm =>
      bpmEstimate?.reliable == true &&
      DateTime.now().difference(bpmEstimate!.timestamp) <
          const Duration(seconds: 5);

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open AI-assisted vitals',
    child: Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.favorite,
                size: 18,
                color: _hasFreshReliableBpm
                    ? Colors.lightGreenAccent
                    : Colors.white70,
              ),
              const SizedBox(width: 7),
              Text(
                _hasFreshReliableBpm
                    ? '${bpmEstimate!.bpm!.round()} BPM'
                    : 'Vitals',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VitalsDiagnostics extends StatelessWidget {
  const _VitalsDiagnostics({
    required this.diagnostics,
    required this.merppgDiagnostics,
    required this.bpmEstimate,
    required this.onClose,
  });

  final BpmCaptureDiagnostics diagnostics;
  final MerppgDiagnostics merppgDiagnostics;
  final BpmEstimate? bpmEstimate;
  final VoidCallback onClose;

  bool get _hasFreshReliableBpm =>
      bpmEstimate?.reliable == true &&
      DateTime.now().difference(bpmEstimate!.timestamp) <
          const Duration(seconds: 5);

  bool get _bpmIsStale =>
      bpmEstimate != null &&
      DateTime.now().difference(bpmEstimate!.timestamp) >=
          const Duration(seconds: 5);

  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'AI-assisted vitals',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: onClose,
              tooltip: 'Close vitals',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone_android, color: Colors.white70),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    diagnostics.capturedFrames == 0
                        ? 'Waiting for patient vitals'
                        : diagnostics.preparedFaceRate == 0
                        ? 'Finding face…'
                        : 'Face input ready',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${diagnostics.preparedFaceRate.toStringAsFixed(1)} face fps  •  '
                    '${(diagnostics.faceHitRate * 100).toStringAsFixed(0)}% hit',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${diagnostics.capturedFrames} captured at '
          '${diagnostics.captureRate.toStringAsFixed(1)} fps • '
          '${diagnostics.lastProcessingTime.inMilliseconds} ms/frame',
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        Text(
          'capture ${diagnostics.lastCaptureTime.inMilliseconds} ms • '
          'detect ${diagnostics.lastDetectionTime.inMilliseconds} ms • '
          'prepare ${diagnostics.lastPreparationTime.inMilliseconds} ms',
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        if (diagnostics.frameWidth > 0)
          Text(
            'local frame ${diagnostics.frameWidth}×${diagnostics.frameHeight}',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        if (diagnostics.lastError != null)
          Text(
            diagnostics.lastError!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
          ),
        const Divider(color: Colors.white24, height: 12),
        Text(
          merppgDiagnostics.status,
          style: TextStyle(
            color: merppgDiagnostics.error == null
                ? Colors.lightGreenAccent
                : Colors.orangeAccent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (merppgDiagnostics.latestBvp != null)
          Text(
            'BVP ${merppgDiagnostics.latestBvp!.toStringAsFixed(4)} • '
            '${merppgDiagnostics.lastInferenceTime.inMilliseconds} ms infer',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        Text(
          '${merppgDiagnostics.processedSamples} BVP samples • '
          '${merppgDiagnostics.droppedFrames} dropped',
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        if (merppgDiagnostics.error != null)
          Text(
            merppgDiagnostics.error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
          ),
        const Divider(color: Colors.white24, height: 12),
        Text(
          _hasFreshReliableBpm
              ? '${bpmEstimate!.bpm!.round()} BPM'
              : 'Measuring BPM…',
          style: TextStyle(
            color: _hasFreshReliableBpm
                ? Colors.lightGreenAccent
                : Colors.white70,
            fontSize: _hasFreshReliableBpm ? 20 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          _bpmIsStale
              ? 'Signal interrupted'
              : bpmEstimate?.status ?? 'Collecting pulse signal…',
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        if (bpmEstimate != null && !_bpmIsStale)
          Text(
            'confidence ${(bpmEstimate!.confidence * 100).round()}% • '
            '${bpmEstimate!.effectiveSampleRate.toStringAsFixed(1)} BVP fps • '
            'range ≤${bpmEstimate!.maximumResolvableBpm.round()} BPM',
            style: const TextStyle(color: Colors.white60, fontSize: 9),
          ),
        const SizedBox(height: 3),
        const Text(
          'Screening estimate only • not a diagnosis',
          style: TextStyle(color: Colors.white54, fontSize: 9),
        ),
      ],
    ),
  );
}

class _BpmChart extends StatelessWidget {
  const _BpmChart({required this.samples});

  final List<BpmSample> samples;

  @override
  Widget build(BuildContext context) {
    final reliable = samples
        .where((sample) => sample.confidence >= 0.5)
        .toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 6),
        child: reliable.isEmpty
            ? const Center(
                child: Text(
                  'Reliable BPM trend will appear after ~20 seconds',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              )
            : LineChart(_chartData(reliable)),
      ),
    );
  }

  LineChartData _chartData(List<BpmSample> reliable) {
    final now = DateTime.now();
    final spots = reliable
        .map(
          (sample) => FlSpot(
            sample.timestamp.difference(now).inMilliseconds / 1000,
            sample.bpm,
          ),
        )
        .toList(growable: false);
    return LineChartData(
      minX: -60,
      maxX: 0,
      minY: 40,
      maxY: 180,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 40,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: Colors.white12, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            reservedSize: 18,
            getTitlesWidget: (value, meta) => Text(
              '${value.round()}s',
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 40,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => Text(
              value.round().toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ),
        ),
      ),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: <LineChartBarData>[
        LineChartBarData(
          spots: spots,
          color: Colors.lightGreenAccent,
          barWidth: 2,
          isCurved: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.lightGreenAccent.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
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

int _intValue(Object? value) => (value as num?)?.toInt() ?? 0;

double _doubleValue(Object? value) => (value as num?)?.toDouble() ?? 0;

double? _nullableDoubleValue(Object? value) => (value as num?)?.toDouble();
