# ASHWINI Healthcare Apps

This repository contains the two production-facing Flutter applications:

- `doctor_app/` — doctor, healthcare worker, and admin application, including
  the doctor-side WebRTC teleconsult room, live patient BPM telemetry, chart,
  consent, and post-call clinical documentation.
- `patient_app/` — patient application, including appointment booking,
  WebRTC teleconsultation, on-device ME-rPPG processing, and vitals telemetry.

Both applications use the same Firebase project for WebRTC signaling. A patient
and doctor must open the same backend appointment ID so they resolve to the same
`teleconsult_calls/{appointmentId}` room.

## Local setup

Run `flutter pub get` inside each application folder. Supply the Metered/Open
Relay credential endpoint at build or run time without committing it:

```powershell
flutter run --dart-define=TURN_CREDENTIALS_URL=$env:TURN_CREDENTIALS_URL
```

The Firestore rules in this repository are prototype-only and must be replaced
with authenticated participant rules before handling real patient data.
