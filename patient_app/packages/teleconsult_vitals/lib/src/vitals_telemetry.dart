import 'vitals_models.dart';

const int vitalsTelemetryVersion = 1;

sealed class VitalsTelemetryMessage {
  const VitalsTelemetryMessage();

  Map<String, dynamic> toJson();

  static VitalsTelemetryMessage? tryParse(Map<String, dynamic> json) {
    if (_int(json['version']) != vitalsTelemetryVersion) return null;
    try {
      return switch (json['type']) {
        'captureDiagnostics' => CaptureDiagnosticsTelemetry.fromJson(json),
        'vitalsSample' => VitalsSampleTelemetry.fromJson(json),
        _ => null,
      };
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class CaptureDiagnosticsTelemetry extends VitalsTelemetryMessage {
  const CaptureDiagnosticsTelemetry({
    required this.timestamp,
    required this.diagnostics,
  });

  factory CaptureDiagnosticsTelemetry.fromJson(
    Map<String, dynamic> json,
  ) => CaptureDiagnosticsTelemetry(
    timestamp: _dateTime(json['timestampMicros']),
    diagnostics: BpmCaptureDiagnostics(
      capturedFrames: _int(json['capturedFrames']),
      detectedFaces: _int(json['detectedFaces']),
      skippedBusyTicks: _int(json['skippedBusyTicks']),
      captureRate: _double(json['captureRate']),
      preparedFaceRate: _double(json['preparedFaceRate']),
      faceHitRate: _double(json['faceHitRate']),
      lastProcessingTime: Duration(milliseconds: _int(json['processingMs'])),
      lastCaptureTime: Duration(milliseconds: _int(json['captureMs'])),
      lastDetectionTime: Duration(milliseconds: _int(json['detectionMs'])),
      lastPreparationTime: Duration(milliseconds: _int(json['preparationMs'])),
      frameWidth: _int(json['frameWidth']),
      frameHeight: _int(json['frameHeight']),
      lastError: json['lastError'] as String?,
    ),
  );

  final DateTime timestamp;
  final BpmCaptureDiagnostics diagnostics;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'captureDiagnostics',
    'version': vitalsTelemetryVersion,
    'timestampMicros': timestamp.microsecondsSinceEpoch,
    'capturedFrames': diagnostics.capturedFrames,
    'detectedFaces': diagnostics.detectedFaces,
    'skippedBusyTicks': diagnostics.skippedBusyTicks,
    'captureRate': diagnostics.captureRate,
    'preparedFaceRate': diagnostics.preparedFaceRate,
    'faceHitRate': diagnostics.faceHitRate,
    'processingMs': diagnostics.lastProcessingTime.inMilliseconds,
    'captureMs': diagnostics.lastCaptureTime.inMilliseconds,
    'detectionMs': diagnostics.lastDetectionTime.inMilliseconds,
    'preparationMs': diagnostics.lastPreparationTime.inMilliseconds,
    'frameWidth': diagnostics.frameWidth,
    'frameHeight': diagnostics.frameHeight,
    'lastError': diagnostics.lastError,
  };
}

class VitalsSampleTelemetry extends VitalsTelemetryMessage {
  const VitalsSampleTelemetry({
    required this.timestamp,
    required this.bvp,
    required this.inferenceTime,
    required this.processedSamples,
    required this.droppedFrames,
    this.estimate,
  });

  factory VitalsSampleTelemetry.fromJson(Map<String, dynamic> json) {
    final estimateJson = json['estimate'];
    return VitalsSampleTelemetry(
      timestamp: _dateTime(json['timestampMicros']),
      bvp: _double(json['bvp']),
      inferenceTime: Duration(milliseconds: _int(json['inferenceMs'])),
      processedSamples: _int(json['processedSamples']),
      droppedFrames: _int(json['droppedFrames']),
      estimate: estimateJson is Map
          ? _estimateFromJson(Map<String, dynamic>.from(estimateJson))
          : null,
    );
  }

  final DateTime timestamp;
  final double bvp;
  final Duration inferenceTime;
  final int processedSamples;
  final int droppedFrames;
  final BpmEstimate? estimate;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'vitalsSample',
    'version': vitalsTelemetryVersion,
    'timestampMicros': timestamp.microsecondsSinceEpoch,
    'bvp': bvp,
    'inferenceMs': inferenceTime.inMilliseconds,
    'processedSamples': processedSamples,
    'droppedFrames': droppedFrames,
    if (estimate != null) 'estimate': _estimateToJson(estimate!),
  };
}

Map<String, dynamic> _estimateToJson(BpmEstimate estimate) => <String, dynamic>{
  'timestampMicros': estimate.timestamp.microsecondsSinceEpoch,
  'status': estimate.status,
  'confidence': estimate.confidence,
  'effectiveSampleRate': estimate.effectiveSampleRate,
  'sampleCount': estimate.sampleCount,
  'maximumResolvableBpm': estimate.maximumResolvableBpm,
  'bpm': estimate.bpm,
};

BpmEstimate _estimateFromJson(Map<String, dynamic> json) => BpmEstimate(
  timestamp: _dateTime(json['timestampMicros']),
  status: json['status'] as String? ?? 'Measuring pulse quality…',
  confidence: _double(json['confidence']),
  effectiveSampleRate: _double(json['effectiveSampleRate']),
  sampleCount: _int(json['sampleCount']),
  maximumResolvableBpm: _double(json['maximumResolvableBpm']),
  bpm: _nullableDouble(json['bpm']),
);

DateTime _dateTime(Object? value) {
  if (value is! num) throw const FormatException('Missing timestamp.');
  return DateTime.fromMicrosecondsSinceEpoch(value.toInt());
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

double? _nullableDouble(Object? value) => (value as num?)?.toDouble();
