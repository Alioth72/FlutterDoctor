import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

typedef FaceFrameCallback = void Function(CapturedFaceFrame frame);
typedef CaptureDiagnosticsCallback =
    void Function(BpmCaptureDiagnostics diagnostics);

class CapturedFaceFrame {
  const CapturedFaceFrame({
    required this.timestamp,
    required this.rgb,
    required this.previewJpeg,
  });

  final DateTime timestamp;
  final Float32List rgb;
  final Uint8List? previewJpeg;
}

class BpmCaptureDiagnostics {
  const BpmCaptureDiagnostics({
    required this.capturedFrames,
    required this.detectedFaces,
    required this.skippedBusyTicks,
    required this.captureRate,
    required this.preparedFaceRate,
    required this.faceHitRate,
    required this.lastProcessingTime,
    required this.lastCaptureTime,
    required this.lastDetectionTime,
    required this.lastPreparationTime,
    required this.frameWidth,
    required this.frameHeight,
    this.lastError,
  });

  const BpmCaptureDiagnostics.waiting()
    : capturedFrames = 0,
      detectedFaces = 0,
      skippedBusyTicks = 0,
      captureRate = 0,
      preparedFaceRate = 0,
      faceHitRate = 0,
      lastProcessingTime = Duration.zero,
      lastCaptureTime = Duration.zero,
      lastDetectionTime = Duration.zero,
      lastPreparationTime = Duration.zero,
      frameWidth = 0,
      frameHeight = 0,
      lastError = null;

  final int capturedFrames;
  final int detectedFaces;
  final int skippedBusyTicks;
  final double captureRate;
  final double preparedFaceRate;

  /// Percentage of periodic ML Kit checks that found a face.
  final double faceHitRate;
  final Duration lastProcessingTime;
  final Duration lastCaptureTime;
  final Duration lastDetectionTime;
  final Duration lastPreparationTime;
  final int frameWidth;
  final int frameHeight;
  final String? lastError;
}

/// Captures and prepares local WebRTC camera frames for the ME-rPPG model.
///
/// Reusing the call's local track avoids opening a second camera and processes
/// frames before WebRTC encoding, network loss, and decoder timing jitter.
class BpmFrameCaptureService {
  BpmFrameCaptureService({
    required this.onFaceFrame,
    required this.onDiagnostics,
  }) : _faceDetector = FaceDetector(
         options: FaceDetectorOptions(
           performanceMode: FaceDetectorMode.fast,
           enableClassification: false,
           enableContours: false,
           enableLandmarks: false,
           enableTracking: true,
           minFaceSize: 0.15,
         ),
       );

  // Request up to 15 samples/second from the uncompressed local track. The
  // busy guard automatically reduces this on slower devices.
  static const Duration _captureInterval = Duration(milliseconds: 66);
  static const Duration _faceRefreshInterval = Duration(seconds: 1);
  static const Duration _faceSearchInterval = Duration(milliseconds: 300);
  static const Duration _previewInterval = Duration(milliseconds: 500);
  static const Duration _logInterval = Duration(seconds: 5);

  final FaceFrameCallback onFaceFrame;
  final CaptureDiagnosticsCallback onDiagnostics;
  final FaceDetector _faceDetector;

  Timer? _timer;
  MediaStreamTrack? _track;
  File? _mlKitInputFile;
  bool _processing = false;
  bool _disposed = false;
  int _generation = 0;
  int _capturedFrames = 0;
  int _preparedFaceFrames = 0;
  int _detectionRuns = 0;
  int _detectionHits = 0;
  int _skippedBusyTicks = 0;
  Rect? _lastFaceBox;
  DateTime? _startedAt;
  DateTime? _lastLogAt;
  DateTime? _lastDetectionAt;
  DateTime? _lastPreviewAt;
  String? _lastError;
  Duration _lastProcessingTime = Duration.zero;
  Duration _lastCaptureTime = Duration.zero;
  Duration _lastDetectionTime = Duration.zero;
  Duration _lastPreparationTime = Duration.zero;
  int _frameWidth = 0;
  int _frameHeight = 0;

  Future<void> start(MediaStreamTrack track) async {
    stop();
    _track = track;
    _startedAt = DateTime.now();
    _lastLogAt = _startedAt;
    _capturedFrames = 0;
    _preparedFaceFrames = 0;
    _detectionRuns = 0;
    _detectionHits = 0;
    _skippedBusyTicks = 0;
    _lastFaceBox = null;
    _lastDetectionAt = null;
    _lastPreviewAt = null;
    _lastError = null;
    _lastProcessingTime = Duration.zero;
    _lastCaptureTime = Duration.zero;
    _lastDetectionTime = Duration.zero;
    _lastPreparationTime = Duration.zero;
    _frameWidth = 0;
    _frameHeight = 0;
    final directory = await getTemporaryDirectory();
    _mlKitInputFile = File('${directory.path}/bpm_local_frame.png');
    if (_disposed || _track != track) return;
    final generation = _generation;
    unawaited(_captureTick(generation));
    _timer = Timer.periodic(
      _captureInterval,
      (_) => unawaited(_captureTick(generation)),
    );
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _track = null;
  }

  Future<void> _captureTick(int generation) async {
    if (_disposed || generation != _generation || _track == null) return;
    if (_processing) {
      _skippedBusyTicks++;
      return;
    }

    _processing = true;
    final stopwatch = Stopwatch()..start();
    try {
      final timestamp = DateTime.now();
      final captureStopwatch = Stopwatch()..start();
      final buffer = await _track!.captureFrame();
      captureStopwatch.stop();
      _lastCaptureTime = captureStopwatch.elapsed;
      if (_isStale(generation)) return;
      final bytes = buffer.asUint8List();
      _capturedFrames++;

      final now = DateTime.now();
      if (_shouldDetectFace(now)) {
        final detectionStopwatch = Stopwatch()..start();
        await _refreshFaceBox(bytes, now);
        detectionStopwatch.stop();
        _lastDetectionTime = detectionStopwatch.elapsed;
        if (_isStale(generation)) return;
      }

      final faceBox = _lastFaceBox;
      if (faceBox != null) {
        final preparationStopwatch = Stopwatch()..start();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw const FormatException('WebRTC returned an unreadable frame.');
        }
        _frameWidth = decoded.width;
        _frameHeight = decoded.height;
        final includePreview = _lastPreviewAt == null ||
            now.difference(_lastPreviewAt!) >= _previewInterval;
        final prepared = _prepareFace(
          decoded,
          faceBox,
          includePreview: includePreview,
        );
        _preparedFaceFrames++;
        if (includePreview) _lastPreviewAt = now;
        preparationStopwatch.stop();
        _lastPreparationTime = preparationStopwatch.elapsed;
        onFaceFrame(
          CapturedFaceFrame(
            timestamp: timestamp,
            rgb: prepared.rgb,
            previewJpeg: prepared.previewJpeg,
          ),
        );
      }
      _lastError = null;
    } catch (error, stackTrace) {
      _lastError = error.toString().replaceFirst('Exception: ', '');
      debugPrint('BPM frame capture failed: $error\n$stackTrace');
    } finally {
      stopwatch.stop();
      _lastProcessingTime = stopwatch.elapsed;
      _processing = false;
      if (!_isStale(generation)) _reportDiagnostics();
    }
  }

  bool _isStale(int generation) =>
      _disposed || generation != _generation || _track == null;

  bool _shouldDetectFace(DateTime now) {
    final lastDetectionAt = _lastDetectionAt;
    if (lastDetectionAt == null) return true;
    final interval =
        _lastFaceBox == null ? _faceSearchInterval : _faceRefreshInterval;
    return now.difference(lastDetectionAt) >= interval;
  }

  Future<void> _refreshFaceBox(Uint8List bytes, DateTime now) async {
    final file = _mlKitInputFile;
    if (file == null) return;
    _lastDetectionAt = now;
    _detectionRuns++;
    await file.writeAsBytes(bytes, flush: true);
    final faces = await _faceDetector.processImage(
      InputImage.fromFilePath(file.path),
    );
    if (faces.isEmpty) {
      _lastFaceBox = null;
      return;
    }
    _detectionHits++;
    _lastFaceBox = faces
        .reduce(
          (a, b) => a.boundingBox.width * a.boundingBox.height >=
                  b.boundingBox.width * b.boundingBox.height
              ? a
              : b,
        )
        .boundingBox;
  }

  _PreparedFace _prepareFace(
    img.Image source,
    Rect boundingBox, {
    required bool includePreview,
  }) {
    final left = boundingBox.left.floor().clamp(0, source.width - 1);
    final topPadding = boundingBox.height * 0.2;
    final top = (boundingBox.top - topPadding)
        .floor()
        .clamp(0, source.height - 1);
    final right = boundingBox.right.ceil().clamp(left + 1, source.width);
    final bottom = (boundingBox.bottom + topPadding * 0.2)
        .ceil()
        .clamp(top + 1, source.height);

    final cropped = img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    final resized = img.copyResize(
      cropped,
      width: 36,
      height: 36,
      interpolation: img.Interpolation.average,
    );
    final rgb = Float32List(36 * 36 * 3);
    var index = 0;
    for (final pixel in resized) {
      rgb[index++] = pixel.r / 255.0;
      rgb[index++] = pixel.g / 255.0;
      rgb[index++] = pixel.b / 255.0;
    }
    return _PreparedFace(
      rgb: rgb,
      previewJpeg: includePreview
          ? Uint8List.fromList(img.encodeJpg(resized, quality: 85))
          : null,
    );
  }

  void _reportDiagnostics() {
    final elapsedSeconds = math.max(
      0.001,
      DateTime.now().difference(_startedAt!).inMilliseconds / 1000,
    );
    final diagnostics = BpmCaptureDiagnostics(
      capturedFrames: _capturedFrames,
      detectedFaces: _detectionHits,
      skippedBusyTicks: _skippedBusyTicks,
      captureRate: _capturedFrames / elapsedSeconds,
      preparedFaceRate: _preparedFaceFrames / elapsedSeconds,
      faceHitRate: _detectionRuns == 0 ? 0 : _detectionHits / _detectionRuns,
      lastProcessingTime: _lastProcessingTime,
      lastCaptureTime: _lastCaptureTime,
      lastDetectionTime: _lastDetectionTime,
      lastPreparationTime: _lastPreparationTime,
      frameWidth: _frameWidth,
      frameHeight: _frameHeight,
      lastError: _lastError,
    );
    onDiagnostics(diagnostics);

    final now = DateTime.now();
    if (now.difference(_lastLogAt!) >= _logInterval) {
      debugPrint(
        'BPM capture: ${diagnostics.captureRate.toStringAsFixed(1)} fps, '
        '${diagnostics.capturedFrames} frames, '
        '${diagnostics.preparedFaceRate.toStringAsFixed(1)} face fps, '
        '${(diagnostics.faceHitRate * 100).toStringAsFixed(0)}% face hits, '
        '${diagnostics.skippedBusyTicks} busy ticks',
      );
      _lastLogAt = now;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    stop();
    _disposed = true;
    await _faceDetector.close();
  }
}

class _PreparedFace {
  const _PreparedFace({required this.rgb, required this.previewJpeg});

  final Float32List rgb;
  final Uint8List? previewJpeg;
}
