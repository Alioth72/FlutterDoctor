# Teleconsultation + video-based BPM: implementation plan

**Context:** Smart India Hackathon problem statement on rural/underserved public healthcare access. This plan covers two Flutter apps — patient and doctor — implementing a 1:1 video teleconsultation, plus a doctor-side feature that estimates the patient's heart rate (BPM) from the incoming call video using the ME-rPPG model, displayed as a live number and rolling chart on the doctor's screen.

Keep the implementation simple and minimal. Plain `StatefulWidget`/`setState` is sufficient — do not introduce a state management package. Do not add abstractions beyond what's specified below. Build and validate the plain video call end-to-end (§9, steps 1–6) before touching the BPM pipeline — it's the foundation everything else sits on.

---

## 1. Objective

- **Patient app**: consent, join a call, be seen/heard by the doctor.
- **Doctor app**: see today's queue, consent, join the same call, see/hear the patient, see a live BPM reading and BPM chart derived from the patient's video, and record notes/prescription/referral afterward.
- **BPM feature**: runs entirely on the doctor's device. It captures frames from the *already-connected* call video, crops the face, runs them through the ME-rPPG model on-device, and displays the result. Nothing about this feature touches the patient app's UI.

## 2. Out of scope — do not build

- Any real backend/API server. Use mock repositories (§6).
- JaaS/Jitsi — this project uses raw `flutter_webrtc`, not any Jitsi variant.
- Production-grade auth: Firestore security rules beyond a permissive default, and backend-issued (vs. direct-fetched) TURN credentials. Both are named explicitly in §12 as deferred.
- ABDM/ABHA/FHIR integration.
- Appointment booking/scheduling UI — assume appointments already exist as data.
- Push notifications.
- Multi-party calls — this is 1:1 only.
- Any BPM display or processing on the **patient** app — BPM is doctor-facing only.
- The classical-vs-ME-rPPG accuracy benchmark under varying bandwidth — that's a separate side-experiment for the pitch deck, not part of the shipped app (§12).

## 3. Architecture overview

```
Patient app  ──(camera/mic)──►  flutter_webrtc peer connection  ──►  Doctor app
                                        ▲
                         Firestore (signaling: offer/answer/ICE)
                         Open Relay (TURN relay when direct P2P fails)

Doctor app, once remote track is flowing:
  captureFrame() ──► face crop ──► ME-rPPG (on-device ONNX) ──► timing-aware
  BPM extraction ──► SQI confidence gate ──► live overlay + chart
```

Two independent concerns, built and tested in that order: get the call working reliably first (§9 steps 1–6), then add BPM on top of a call that already works (§9 steps 7–11).

## 4. Tech stack & dependencies

```yaml
dependencies:
  flutter_webrtc: ^latest
  firebase_core: ^latest
  cloud_firestore: ^latest
  http: ^latest
  google_mlkit_face_detection: ^latest
  flutter_onnxruntime: ^latest   # NOT the old `onnxruntime` package — that one is
                                  # confirmed unmaintained upstream. flutter_onnxruntime
                                  # is the actively maintained option (masic.ai,
                                  # ONNX Runtime 1.22+, modern async API).
  fl_chart: ^latest
```

Platforms: **Android and iOS only.** None of this stack (flutter_webrtc's frame-capture APIs, flutter_onnxruntime, ML Kit face detection) is being targeted at Web or Windows desktop for this feature.

## 5. One-time account setup (do this before writing app code)

1. **Firebase**: create a project, register both the patient and doctor apps, enable Firestore in test mode (permissive rules — production rules are a deferred item, §12).
2. **Open Relay (Metered.ca)**: sign up free, get your app name and API key from the dashboard. TURN/STUN credentials are fetched at runtime from:
   `GET https://YOUR_APPNAME.metered.live/api/v1/turn/credentials?apiKey=YOUR_API_KEY`
   This returns a ready-to-use `iceServers` array — pass it straight into `createPeerConnection`.
3. **ME-rPPG model**: obtain `model.onnx` (and its accompanying state/config file) from the model's repository, bundle it as a Flutter asset (`assets/models/`), and declare it in `pubspec.yaml`.

## 6. Data models

```dart
enum AppointmentStatus { waiting, inCall, completed, missed }

class Appointment {
  final String id;
  final String patientName;
  final int patientAge;
  final String chiefComplaint;
  final DateTime scheduledTime;
  final int queuePosition;
  AppointmentStatus status;

  Appointment({
    required this.id,
    required this.patientName,
    required this.patientAge,
    required this.chiefComplaint,
    required this.scheduledTime,
    required this.queuePosition,
    this.status = AppointmentStatus.waiting,
  });
}

class ConsentRecord {
  final String appointmentId;
  final DateTime confirmedAt;
  final bool isDoctor; // true = doctor's declaration, false = patient's

  ConsentRecord({required this.appointmentId, required this.confirmedAt, required this.isDoctor});
}

class CallLog {
  final String appointmentId;
  DateTime? startedAt;
  DateTime? endedAt;
  bool hadError;

  CallLog({required this.appointmentId, this.hadError = false});

  Duration? get duration =>
      (startedAt != null && endedAt != null) ? endedAt!.difference(startedAt!) : null;
}

class BpmSample {
  final DateTime timestamp;
  final double bpm;
  final double confidence; // 0.0–1.0, from the SQI-style gate

  BpmSample({required this.timestamp, required this.bpm, required this.confidence});
}

class PrescriptionItem {
  String drugName;
  String dosage;
  String duration;

  PrescriptionItem({this.drugName = '', this.dosage = '', this.duration = ''});
}

class ConsultationNote {
  final String appointmentId;
  String notes;
  List<PrescriptionItem> prescriptionItems;
  bool referralNeeded;
  String? referralReason;
  String? referralFacility;
  // BPM summary only — do not persist the full per-frame sample list, it's
  // a live-display concern, not a permanent record for this phase.
  double? avgBpm;
  double? minBpm;
  double? maxBpm;
  int? bpmSampleCount;

  ConsultationNote({
    required this.appointmentId,
    this.notes = '',
    List<PrescriptionItem>? prescriptionItems,
    this.referralNeeded = false,
    this.referralReason,
    this.referralFacility,
    this.avgBpm,
    this.minBpm,
    this.maxBpm,
    this.bpmSampleCount,
  }) : prescriptionItems = prescriptionItems ?? [];
}
```

## 7. Data layer — mock repositories (no real backend)

Each app gets its own mock repository implementing a shared interface, so a real backend can drop in later without touching UI code. For this phase, hardcode the *same* appointment IDs and details in both apps' mocks so they line up for testing (e.g. both use `apt_001` for the first test appointment).

```dart
abstract class AppointmentRepository {
  Future<List<Appointment>> getTodaysQueue(); // doctor app only
  Future<Appointment> getAppointment(String id); // patient app only
  Future<void> recordConsent(ConsentRecord record);
  Future<void> saveCallLog(CallLog log);
  Future<void> saveConsultationNote(ConsultationNote note);
  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status);
}
```

Implement `MockAppointmentRepository` in each app with `debugPrint` stand-ins for the write methods, same pattern as read methods returning hardcoded sample data — see the doctor-only plan from earlier in this project for the exact shape if you have it; otherwise this signature is enough to implement directly.

## 8. Screens

### 8.1 Patient app

**Pre-call / consent screen**
- Shows the appointment's scheduled time and the doctor's name (mocked).
- Consent checkbox, exact wording: *"I consent to this video consultation, including AI-based heart rate estimation from my video by my doctor during the call."* This wording matters — it names the BPM processing specifically, not just "the call."
- "Join call" button, disabled until checked. On press: `recordConsent(...)`, then navigate to the call screen.

**In-call screen**
- Local camera preview (small, corner) and remote video (doctor) full-screen, both via `RTCVideoView`.
- Controls: mute, camera toggle, end call. No BPM UI anywhere on this app.
- On screen entry: acts as the **caller** — creates the offer, writes it to Firestore, fetches Open Relay ICE servers, sets up the peer connection, adds local audio/video tracks, listens for the answer and the doctor's ICE candidates (full code in §9, wired here).

### 8.2 Doctor app

**Dashboard (queue)** — unchanged from a standard queue screen: list of `Appointment`s sorted by `queuePosition`, only the front-of-queue `waiting` appointment has an enabled Join button, tapping it opens the pre-call screen.

**Pre-call / consent screen**
- Shows patient name, age, chief complaint.
- Consent checkbox, exact wording: *"I confirm I am the assigned practitioner and consent to conducting and logging this teleconsultation, including AI-based heart rate estimation from the patient's video."*
- "Start consultation" button, disabled until checked. On press: `recordConsent(...)`, navigate to the call screen.

**In-call screen** — the most involved screen in this plan. Two independent layers on top of each other:

*Layer 1 — the call itself:*
- Acts as the **callee** — reads the existing offer from Firestore, creates the answer, fetches Open Relay ICE servers, sets up the peer connection, listens for the patient's ICE candidates.
- `RTCVideoView` for the remote (patient) stream, full-screen; local preview, small corner; mute/camera/end controls, all custom-built (there is no pre-built call UI here, unlike a Jitsi-style SDK — you own this screen entirely).

*Layer 2 — the BPM pipeline, active once the remote track is confirmed flowing:*
1. `Timer.periodic` (e.g. every 200ms) calls `captureFrame()` on the remote video track. Record `DateTime.now()` as the real capture time for every frame — this actual timestamp is what makes the timing correction in step 4 possible, so don't skip recording it even during early development.
2. Run `google_mlkit_face_detection` on the captured frame. If no face is found, skip this step entirely — do not feed a frame with no face into the model, and do not fabricate a BPM value for that tick.
3. Crop to the detected face region, resize to the model's expected input (36×36 per the ME-rPPG paper), and feed it into the ONNX session via `flutter_onnxruntime`, carrying the model's internal state forward from the previous step (this is a recurrent, step-by-step model — each call needs the prior call's output state as input). This produces one BVP (blood volume pulse) value per step.
4. Maintain a rolling buffer of `(timestamp, bvp)` pairs. Before converting to BPM, apply the timing-aware correction from Álvarez Casado et al. (2023): don't assume a fixed nominal frame rate for this buffer — recompute the effective sample rate for the current analysis window from the *actual* elapsed time between the real timestamps you recorded in step 1. Only after that correction, run a bandpass filter (0.7–4 Hz) and frequency-domain peak detection (Welch's-method-style, mirroring `open-rppg`'s `get_hr` function) to get a BPM estimate.
5. Compute a confidence score for that estimate — an autocorrelation-based signal-quality check, mirroring `open-rppg`'s `SQI` function (score 0.0–1.0 based on how dominant/periodic the extracted signal is). Package this as a `BpmSample`.
6. Append the `BpmSample` to a rolling display buffer (last ~60 seconds). Only update the visible BPM number when confidence is above a threshold (e.g. 0.5) — otherwise show a "measuring…" or greyed-out state. **Never display a number the confidence check would flag as unreliable** — an incorrect but confident-looking number is worse than no number.

*UI for layer 2:* a `Stack` over the remote `RTCVideoView` —
- Top-right: current BPM as text (or "measuring…" per the gate above).
- Bottom: a live `fl_chart` `LineChart` of the rolling `BpmSample` buffer, x-axis time, y-axis BPM, redrawn as new samples land.

**Post-call screen**
- Duration (from `CallLog`), notes field, repeatable prescription rows, referral toggle — same shape as a standard post-call form.
- Additionally: compute and display `avgBpm`/`minBpm`/`maxBpm`/`bpmSampleCount` from the call's `BpmSample` buffer (only counting samples that passed the confidence gate), save them onto the `ConsultationNote`.
- Save → `updateAppointmentStatus(..., completed)` → back to dashboard.

## 9. Build order

**Current implementation status (6 September 2026):** steps 1–6 have passed on
two real devices using different networks. Step 7 is implemented in the doctor
app. Its first Realme Narzo 60 Pro 5G test produced 2.8 fps, 323 ms/frame, and an
89% detection hit rate. Periodic face-box refresh was then added to remove ML Kit
from most frame ticks. A retest reached 3.5 face fps and 100% detection, still
below the target, so the patient stream was reduced from the plugin's 1280×720
default to 640×480 and stage-specific timing diagnostics were added. That
reached 5.4 fps at 480×640 incoming resolution, so a final 320×240 constraint
was applied to target at least 8 fps. The final optimised cadence is awaiting
the repeat APK test in `SETUP.md` Step 15. The official ME-rPPG weights/state
have been located and inspected, but model inference remains deliberately
gated on that check.

**Step 8 update (7 September 2026):** the 320×240 retest passed at 8.3 face fps
and 97% detection. The official ONNX model is now bundled with a lossless compact
version of its 36 recurrent states. Timestamp-aware streaming inference and raw
BVP diagnostics are implemented and awaiting the two-minute device test in
`SETUP.md` Step 16. BPM conversion remains disabled until that test passes.

**Steps 9–10 update (7 September 2026):** raw inference passed on-device at
about 79 ms with 787 finite BVP samples. The app now resamples using real frame
timestamps, applies a 0.7 Hz high-pass and sample-rate-safe low-pass, calculates
a Hann-windowed Welch-style spectrum, combines spectral concentration with
normalized autocorrelation for confidence, suppresses stale/low-confidence
numbers, and charts only accepted readings. Device validation is in `SETUP.md`
Step 17.

1. Firebase project set up, both apps registered, Firestore enabled.
2. Open Relay account created; write and test the `fetchIceServers()` function in isolation (just print the result) before wiring it into a call.
3. Data models + mock repositories in both apps.
4. Patient app: consent screen (static) → call screen shell (UI only, no WebRTC yet).
5. Doctor app: dashboard → consent screen (static) → call screen shell (UI only, no WebRTC yet, no BPM yet).
6. **Wire the actual call**: Firestore signaling (offer/answer/ICE exchange) both sides, `getUserMedia`, `addTrack`, `onTrack`. Test on two real devices on two different networks before moving on — confirm audio and video genuinely flow both directions and reconnect sensibly if one side backgrounds the app. Do not proceed to BPM work until this is solid; every BPM problem is much harder to debug on top of a shaky call.
7. Doctor app: implement frame capture + face crop (steps 1–2 above) with `debugPrint` logging of capture rate and face-detection hit rate — no model yet. Verify you're actually getting a workable capture cadence before investing in the model integration.
8. Bundle the ME-rPPG ONNX model, wire `flutter_onnxruntime`, implement the step-by-step inference producing raw BVP values (step 3). Verify it runs without crashing and produces plausible-looking (not necessarily accurate yet) output.
9. Implement the timing-aware BPM extraction and SQI gating (steps 4–5).
10. Build the overlay + chart UI (step 6), wire to the live pipeline.
11. Post-call screen with BPM summary save.
12. Full end-to-end test: two real devices, two different networks, complete flow from consent through post-call, BPM visibly updating during the call.

## 10. Definition of done

- [ ] Patient and doctor apps each run standalone on Android.
- [ ] A call connects between two physical devices on two different networks (confirms Open Relay TURN is actually being exercised, not just direct P2P on a shared network).
- [ ] Doctor sees and hears the patient; patient sees and hears the doctor.
- [ ] Both consent screens gate call start correctly and record consent via the mock repository.
- [ ] Frame capture is confirmed running at a logged, non-trivial rate against the live remote track.
- [ ] ME-rPPG produces a continuous BVP stream without crashing across a multi-minute call.
- [ ] The BPM overlay shows a live-updating number once enough valid samples have accumulated, and visibly suppresses/greys out during low-confidence periods rather than showing a fabricated value.
- [ ] The BPM chart updates live with a rolling ~60-second window.
- [ ] Ending the call returns the doctor to the post-call screen automatically; saving records notes, prescription, referral, and BPM summary stats together.
- [ ] The full flow is repeatable for a second appointment without restarting either app.

## 11. Known limitations — state these honestly, including in UI copy

- ME-rPPG was validated by its authors on direct, uncompressed camera capture at a fixed ~30fps. This deployment — compressed WebRTC video, irregular capture timing via polling — is genuinely untested territory in the published research. Treat accuracy as unproven, not guaranteed, and say so in your submission.
- The paper's own ablation shows frame-wise/streaming inference (what this feature uses) is less accurate than its batched mode, even on clean, uncompressed video.
- No clinical validation exists for this model on patients with cardiovascular conditions.
- `captureFrame()` has a documented color-artifact bug on some platform/version combinations — test early on your actual target devices, not just an emulator.
- Any doctor-facing label text should frame this as a screening aid ("AI-assisted vitals estimate"), not a diagnostic measurement — this is both more honest and a better fit for the PS's actual "digital triage" framing than a clinical-accuracy claim would be.

## 12. Deferred to a later phase (do not build now)

- Firestore security rules beyond permissive test-mode defaults.
- Backend-issued, short-lived TURN credentials (currently fetched directly from the client).
- A real backend replacing the mock repositories, shared between both apps.
- Hashed/non-guessable appointment and room IDs.
- A small, controlled benchmark comparing ME-rPPG against a classical baseline (CHROM/POS) across a few bandwidth conditions, using a pulse oximeter for ground truth — valuable as a pitch-deck side-experiment, deliberately not part of the shipped app.
- Push notifications, server-side queue enforcement, FHIR/ABDM mapping.
- Patient-side BPM capture as an alternative/fallback mode, discussed earlier in this project's design process but not part of this build.
