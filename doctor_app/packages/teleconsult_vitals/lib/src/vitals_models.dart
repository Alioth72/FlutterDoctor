class BpmEstimate {
  const BpmEstimate({
    required this.timestamp,
    required this.status,
    required this.confidence,
    required this.effectiveSampleRate,
    required this.sampleCount,
    required this.maximumResolvableBpm,
    this.bpm,
  });

  final DateTime timestamp;
  final String status;
  final double confidence;
  final double effectiveSampleRate;
  final int sampleCount;
  final double maximumResolvableBpm;
  final double? bpm;

  bool get reliable => bpm != null && confidence >= 0.5;
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
  final double faceHitRate;
  final Duration lastProcessingTime;
  final Duration lastCaptureTime;
  final Duration lastDetectionTime;
  final Duration lastPreparationTime;
  final int frameWidth;
  final int frameHeight;
  final String? lastError;
}

class MerppgDiagnostics {
  const MerppgDiagnostics({
    required this.status,
    required this.ready,
    required this.processedSamples,
    required this.droppedFrames,
    required this.lastInferenceTime,
    this.latestBvp,
    this.error,
  });

  const MerppgDiagnostics.loading()
    : status = 'Calibrating vitals sensor…',
      ready = false,
      processedSamples = 0,
      droppedFrames = 0,
      lastInferenceTime = Duration.zero,
      latestBvp = null,
      error = null;

  final String status;
  final bool ready;
  final int processedSamples;
  final int droppedFrames;
  final Duration lastInferenceTime;
  final double? latestBvp;
  final String? error;
}
