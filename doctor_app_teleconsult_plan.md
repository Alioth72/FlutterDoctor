# Doctor app — teleconsultation feature: implementation plan

**Context:** This is one feature of a larger Smart India Hackathon submission on rural/underserved healthcare access. This plan covers ONLY the doctor-side Flutter app's teleconsultation feature. Build exactly this scope — do not add features beyond what's listed here, and do not build the items in "Out of scope" below even if they seem like natural next steps.

Keep the implementation simple and minimal. Plain `StatefulWidget`/`setState` is sufficient — do not introduce a state management package (Bloc/Riverpod/Provider) for this scope. Do not add abstraction layers beyond the one repository interface specified in §5.

---

## 1. Objective

Build a standalone Flutter app (Android + iOS) for a doctor to:
1. See today's patient queue.
2. Review a patient's summary and give consent before starting a call.
3. Conduct a video consultation via the Jitsi Meet SDK.
4. Record notes, a prescription, and an optional referral after the call.

## 2. Out of scope — do not build

- The patient-side app.
- Any real backend/API server. Use the mock data layer in §5 instead.
- JaaS / JWT-based room authentication. Use the public `meet.jit.si` server with plain room names for this phase.
- Hashed/obfuscated room names (deferred — see §12).
- ABDM/ABHA/FHIR integration.
- Appointment booking/scheduling UI — assume appointments already exist as data.
- Push notifications.
- Any enforcement that only the assigned doctor can join a call — this phase is UI-level only.

## 3. Tech stack & platform constraints

- Flutter, current stable channel.
- Package: `jitsi_meet_flutter_sdk: ^13.1.1`.
- **Platforms: Android (minSdkVersion 24) and iOS (15.1+) only.** This package does not support Flutter Web or Windows desktop — do not attempt those build targets, and do not try to run this via `flutter run -d chrome` or `-d windows`.

## 4. Data models

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
  final DateTime doctorConfirmedAt;

  ConsentRecord({required this.appointmentId, required this.doctorConfirmedAt});
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

  ConsultationNote({
    required this.appointmentId,
    this.notes = '',
    List<PrescriptionItem>? prescriptionItems,
    this.referralNeeded = false,
    this.referralReason,
    this.referralFacility,
  }) : prescriptionItems = prescriptionItems ?? [];
}
```

## 5. Data layer — mock repository (no real backend)

Define an interface now so a real backend can implement it later without touching UI code. Ship only the mock implementation in this task.

```dart
abstract class AppointmentRepository {
  Future<List<Appointment>> getTodaysQueue();
  Future<void> recordConsent(ConsentRecord record);
  Future<void> saveCallLog(CallLog log);
  Future<void> saveConsultationNote(ConsultationNote note);
  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status);
}

class MockAppointmentRepository implements AppointmentRepository {
  final List<Appointment> _appointments = [
    Appointment(
      id: 'apt_001',
      patientName: 'Ramesh Kumar',
      patientAge: 45,
      chiefComplaint: 'Persistent cough, mild fever for 3 days',
      scheduledTime: DateTime.now(),
      queuePosition: 1,
    ),
    Appointment(
      id: 'apt_002',
      patientName: 'Sunita Devi',
      patientAge: 32,
      chiefComplaint: 'Follow-up: hypertension check',
      scheduledTime: DateTime.now().add(const Duration(minutes: 15)),
      queuePosition: 2,
    ),
  ];

  @override
  Future<List<Appointment>> getTodaysQueue() async => _appointments;

  @override
  Future<void> recordConsent(ConsentRecord record) async {
    debugPrint('Consent recorded: ${record.appointmentId} at ${record.doctorConfirmedAt}');
  }

  @override
  Future<void> saveCallLog(CallLog log) async {
    debugPrint('Call log: ${log.appointmentId}, duration: ${log.duration}, error: ${log.hadError}');
  }

  @override
  Future<void> saveConsultationNote(ConsultationNote note) async {
    debugPrint('Note saved for ${note.appointmentId}: ${note.notes}');
  }

  @override
  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    final apt = _appointments.firstWhere((a) => a.id == appointmentId);
    apt.status = status;
  }
}
```

## 6. Screens

### 6.1 Doctor dashboard (queue)

- List of `Appointment`s from the repository, sorted by `queuePosition`.
- Each row: patient name, scheduled time, chief complaint (single line, truncate if long), a status badge (`waiting` / `in progress` / `completed` / `missed`).
- Only the single appointment with the lowest `queuePosition` AND `status == waiting` has an enabled "Join" button. All other rows show a disabled/greyed join action.
- Tapping the enabled row navigates to the pre-call screen for that appointment.

### 6.2 Pre-call screen (patient summary + consent)

- Display: patient name, age, scheduled time, chief complaint.
- A `CheckboxListTile` with this exact label: *"I confirm I am the assigned practitioner and consent to conducting and logging this teleconsultation."*
- A "Start consultation" button, disabled until the checkbox is checked.
- On press: call `repository.recordConsent(ConsentRecord(appointmentId: ..., doctorConfirmedAt: DateTime.now()))`, then navigate to the in-call flow (§6.3).

### 6.3 In-call — Jitsi integration

This is not a screen you build — it's the native Jitsi UI, configured via the options below. Your job is the configuration and the surrounding lifecycle wiring, not a custom video UI.

```dart
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

Future<void> startCall(BuildContext context, Appointment appointment, AppointmentRepository repo) async {
  final callLog = CallLog(appointmentId: appointment.id);
  final jitsiMeet = JitsiMeet();

  final options = JitsiMeetConferenceOptions(
    serverURL: "https://meet.jit.si",
    room: "consult_${appointment.id}",
    configOverrides: {
      "startWithAudioMuted": false,
      "startWithVideoMuted": false,
      "subject": "Consultation",
      "prejoinPageEnabled": false,
    },
    featureFlags: {
      "chat.enabled": false,
      "invite.enabled": false,
      "add-people.enabled": false,
      "calendar.enabled": false,
      "live-streaming.enabled": false,
      "recording.enabled": false,
      "meeting-name.enabled": false,
      "meeting-password.enabled": false,
      "raise-hand.enabled": false,
      "tile-view.enabled": false,
      "pip.enabled": true,
    },
    userInfo: JitsiMeetUserInfo(displayName: "Dr. ${appointment.patientName /* replace with actual doctor name */}"),
  );

  await jitsiMeet.join(
    options,
    JitsiMeetEventListener(
      conferenceWillJoin: (url) async {
        callLog.startedAt = DateTime.now();
        await repo.updateAppointmentStatus(appointment.id, AppointmentStatus.inCall);
      },
      conferenceTerminated: (url, error) async {
        callLog.endedAt = DateTime.now();
        callLog.hadError = error != null;
        await repo.saveCallLog(callLog);
        await repo.updateAppointmentStatus(
          appointment.id,
          error == null ? AppointmentStatus.completed : AppointmentStatus.missed,
        );
      },
      readyToClose: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PostCallScreen(appointment: appointment)),
        );
      },
    ),
  );
}
```

Notes:
- `userInfo.displayName` above has a placeholder bug on purpose — wire it to the actual logged-in doctor's name, not the patient's.
- Navigate to the post-call screen from `readyToClose`, not `conferenceTerminated` — the latter fires while the native call UI is still tearing down.
- Room name is plain (`consult_<appointmentId>`) for this phase — see §12 for why this isn't final.

### 6.4 Post-call screen

- Show computed duration from the `CallLog` (read-only).
- Free-text notes field.
- Repeatable prescription rows (drug name, dosage, duration) — start with one empty row, an "add row" button, allow deleting rows.
- "Referral needed" toggle — when on, reveal reason and target facility text fields.
- "Save" button: build a `ConsultationNote` from the form, call `repository.saveConsultationNote(...)`, then pop back to the dashboard. The dashboard should reflect the appointment as `completed` and show the next `waiting` appointment as the one with an enabled Join button.

## 7. Platform setup

**`pubspec.yaml`**
```yaml
dependencies:
  jitsi_meet_flutter_sdk: ^13.1.1
```

**Android — `android/app/build.gradle`**
```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

**Android — `android/app/src/main/AndroidManifest.xml`**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        tools:replace="android:label"
        android:label="YourAppName"
        ...>
    </application>
</manifest>
```

**iOS — `ios/Podfile`**
```ruby
platform :ios, '15.1'
```

**iOS — `ios/Runner/Info.plist`**
```xml
<key>NSCameraUsageDescription</key>
<string>Needed to conduct video consultations.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Needed to conduct video consultations.</string>
```

## 8. Suggested folder structure

```
lib/
  models/
    appointment.dart
    consent_record.dart
    call_log.dart
    consultation_note.dart
  data/
    appointment_repository.dart       // interface + MockAppointmentRepository
  screens/
    dashboard_screen.dart
    pre_call_screen.dart
    post_call_screen.dart
  services/
    jitsi_call_service.dart           // the startCall() logic from §6.3
  main.dart
```

## 9. Build order

1. Data models (§4) + mock repository (§5).
2. Dashboard screen wired to the mock repository.
3. Pre-call screen with consent gating.
4. Jitsi dependency + platform setup (§7); wire `startCall()`.
5. Lifecycle listener → call log → auto-navigation to post-call.
6. Post-call screen (notes, prescription rows, referral) → save → return to dashboard.

## 10. Definition of done

- [ ] Runs on an Android emulator or device (iOS is a bonus, not required).
- [ ] Dashboard lists the two mock appointments sorted by queue position; only `apt_001` starts with an enabled Join button.
- [ ] Tapping Join shows the correct patient details on the pre-call screen.
- [ ] "Start consultation" is disabled until the consent checkbox is checked.
- [ ] Starting a call records consent, marks the appointment `inCall`, and launches Jitsi in room `consult_apt_001` on `meet.jit.si` with the exact feature flags/config from §6.3 (verify chat/invite/add-people/calendar/live-streaming/recording/meeting-name/meeting-password/raise-hand/tile-view are all absent from the in-call toolbar, and no prejoin/device-check screen appears).
- [ ] Ending the call automatically returns to the app and opens the post-call screen — no manual back navigation needed.
- [ ] Post-call screen shows a non-zero computed duration, accepts notes and at least one prescription row, and the referral toggle reveals/hides its fields correctly.
- [ ] Saving marks the appointment `completed`, returns to the dashboard, and `apt_002` now shows the enabled Join button.

## 11. Testing note

This SDK has no Web/Windows support, so testing needs an Android emulator (enable webcam passthrough in the emulator's extended controls for camera testing) or a physical device. To verify the call actually connects across a network (not just launches), open `https://meet.jit.si/consult_apt_001` in a desktop browser on a different network than the emulator/device — same room name the app computed — and confirm both sides see and hear each other.

## 12. Deferred to a later phase (do not build now)

- JaaS-hosted Jitsi with JWT-based room authentication, replacing the current plain public-server setup.
- HMAC-hashed, non-guessable room names (currently plain `appointmentId`-based).
- A real backend implementing `AppointmentRepository`, replacing the mock.
- The mirrored patient-side app.
- Push notification trigger to the next patient when a consultation ends.
- Server-side enforcement of "one active call per doctor" (currently there is no enforcement at all).
- FHIR `Encounter`/`MedicationRequest` mapping and ABHA linking for the consultation record.
