# Teleconsult Vitals

Pure-Dart shared contract for the teleconsultation BPM feature. It contains:

- `TimingAwareBpmEstimator` for converting timestamped BVP into BPM.
- BPM, capture, and ME-rPPG diagnostic models.
- Versioned `VitalsTelemetryMessage` codecs shared by patient and doctor apps.

It intentionally excludes camera, ML Kit, ONNX Runtime, model weights, UI, and
WebRTC setup. Those remain patient- or app-specific, preventing native inference
dependencies from increasing the doctor application size.

Add it to an app in the same repository:

```yaml
dependencies:
  teleconsult_vitals:
    path: ../packages/teleconsult_vitals
```

Encode and decode messages with `VitalsSampleTelemetry.toJson()` and
`VitalsTelemetryMessage.tryParse()`. Unknown versions and malformed messages
are rejected instead of interrupting an active call.
