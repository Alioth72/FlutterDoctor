# Teleconsultation Vitals Integration Guide

## Scope

This repository is a working feature slice, not the complete doctor and patient
products. It demonstrates consent, WebRTC calling, patient-side ME-rPPG
inference, live doctor-side BPM display, and a post-call summary. Appointment,
consent, consultation-note, and call-log persistence currently use mock
repositories and must be connected to the main applications.

## Component Map

| Component | Integrate into | Responsibility |
| --- | --- | --- |
| `packages/teleconsult_vitals` | Both apps | Shared estimator, models, and telemetry codec |
| `patient_app/lib/services/bpm_frame_capture_service.dart` | Patient app | Capture and crop the local WebRTC camera track |
| `patient_app/lib/services/merppg_inference_service.dart` | Patient app | Load ME-rPPG and produce BVP samples |
| `patient_app/assets/models/` | Patient app | ONNX model, recurrent state, manifest, and licence |
| `patient_app/lib/services/call_service.dart` | Adapt into both call stacks | Create/send the vitals data channel |
| `doctor_app/lib/screens/doctor_call_screen.dart` | Doctor call UI | Decode telemetry and display BPM/quality/chart |

Do not copy ONNX Runtime, ML Kit, the model assets, or patient capture services
into the doctor application.

## 1. Add the Shared Package

Copy `packages/teleconsult_vitals` into the destination monorepo and add a path
dependency to both app `pubspec.yaml` files:

```yaml
dependencies:
  teleconsult_vitals:
    path: ../packages/teleconsult_vitals
```

If the apps are in separate repositories, publish the package privately or use
a pinned Git dependency. Keep both apps on the same telemetry contract version.

## 2. Integrate the Patient Pipeline

Add the patient dependencies listed in `patient_app/pubspec.yaml`, then copy the
two patient inference services and `patient_app/assets/models/`. Declare all
four model files under Flutter `assets`.

After the main call service obtains the front-camera `MediaStream`, pass its
existing local video track to `BpmFrameCaptureService.start()`. Do not call
`getUserMedia()` again: many phones cannot open the front camera twice. Stop
capture when the camera is disabled or the call ends, and dispose both services.

Feed each prepared face frame to `MerppgInferenceService.process()`, then pass
the resulting timestamped BVP to `TimingAwareBpmEstimator`. Allow approximately
20 seconds before expecting the first estimate. Send `VitalsSampleTelemetry`
and throttled `CaptureDiagnosticsTelemetry` messages.

## 3. Integrate the Call Transport

For direct WebRTC, the patient creates the `patient-vitals-v1` data channel
before `createOffer()`. The doctor registers `onDataChannel` before applying the
offer. Send `message.toJson()` as JSON text. The channel is deliberately
unordered and short-lived-message oriented; telemetry is best effort and must
never terminate audio/video.

If the main apps use Agora, Twilio, Jitsi, or another managed call provider,
replace the data channel with that provider's real-time messaging API while
preserving the JSON payload. Do not write per-frame BVP samples to Firestore.

The doctor must decode with `VitalsTelemetryMessage.tryParse()`. It rejects
unknown versions and malformed payloads. Use the local receive time for UI
freshness because patient and doctor clocks can differ.

## 4. Connect Real Application Data

Replace `MockAppointmentRepository` with adapters to the main backend. Use a
globally unique call/session ID rather than sample IDs such as `apt_001`.
Persist consent, participants, start/end times, reliable BPM summary, clinical
notes, prescriptions, and referrals according to the main system's schema.
Avoid storing raw video or continuous BVP unless explicitly required and
consented to.

## 5. Secure Signaling and TURN

The included Firestore rules are prototype-only and unauthenticated. Before
real use, require Firebase Authentication and verify that the authenticated UID
is the assigned patient or doctor for the call. Expire or delete old signaling
documents and ICE candidate subcollections.

Do not embed a long-lived Metered API key in a production APK. The authenticated
backend should issue short-lived TURN credentials. The client should request
them immediately before creating the peer connection.

## 6. Platform and Build Checks

- Align the destination Flutter/Dart and plugin versions before merging.
- Preserve camera, microphone, and network permissions on Android and iOS.
- Commit the patient ONNX file; the repository `.gitignore` includes the needed
  exception.
- Build release artifacts per ABI to reduce size:
  `flutter build apk --release --split-per-abi`.
- Test camera pause/resume, reconnects, low bandwidth, app backgrounding,
  thermal throttling, missing faces, dim lighting, and different skin tones.

## 7. Accuracy and Clinical Validation

Treat BPM as a screening estimate, never a diagnosis. Compare patient-side
output with a pulse oximeter using repeated static and movement trials. Record
mean absolute error, reliable-reading percentage, time to first estimate, frame
rate, dropped frames, device model, lighting, and network type. Do not advertise
medical-grade accuracy until a suitable clinical validation and regulatory
review are complete.

## Handoff Acceptance Checklist

- Both apps compile against the same shared package revision.
- Only the patient APK contains ME-rPPG/ML Kit/ONNX assets and dependencies.
- Telemetry appears on the doctor device across separate mobile networks.
- Invalid or missing telemetry does not affect the call.
- Authenticated users cannot read or modify unrelated call documents.
- Consent, logs, notes, and BPM summaries persist in the real backend.
- The displayed disclaimer remains visible in call and summary screens.
