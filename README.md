# Teleconsultation — Doctor and Patient Apps

Two standalone Flutter mobile apps that demonstrate a focused
doctor-to-patient teleconsultation flow for rural and underserved public-health
settings. The project was built for a Smart India Hackathon problem concerning
healthcare access, continuity, and quality.

The apps intentionally implement only teleconsultation. They use in-memory mock
repositories and the Jitsi Meet Flutter SDK; there is no backend, authentication,
appointment-booking system, or broader healthcare platform in this repository.

## Repository layout

| Path | App |
| --- | --- |
| `doctor_app/` | Doctor queue, consent, Jitsi call, clinical notes, prescriptions, and referral |
| `patient_app/` | Patient appointment, call-readiness details, Jitsi call, and call summary |
| `doctor_app_teleconsult_plan.md` | Original doctor-side implementation plan |

Each app is an independent Flutter project with its own `pubspec.yaml`, Android
project, iOS project, source code, tests, and build output.

## Shared call contract

Both apps use the mock appointment ID `apt_001` and independently compute the
same Jitsi room:

```text
https://meet.jit.si/consult_apt_001
```

The doctor joins as `Dr. Ananya Sharma`, and the patient joins as `Ramesh
Kumar`. Because the repositories are in-memory and independent, status changes
are not synchronized between apps; Jitsi room membership is the only shared
runtime behavior in this prototype.

Both apps disable Jitsi chat, invitations, adding people, calendar, live
streaming, recording, meeting name/password, raise hand, and tile view. The
prejoin page is disabled, while picture-in-picture remains enabled.

## Doctor app flow

1. Display today's two mock appointments in queue order.
2. Enable Join only for the first waiting patient.
3. Show patient details and require the doctor's consent.
4. Join `consult_apt_001` and log call lifecycle/status changes.
5. Open the post-call form automatically when Jitsi closes.
6. Save notes, repeatable prescription rows, and an optional referral.
7. Return to the dashboard with the first appointment completed and the next
   appointment enabled.

The doctor app uses an `AppointmentRepository` interface with an in-memory mock
implementation so a backend can replace it later without changing the UI.

## Patient app flow

1. Display Ramesh Kumar's consultation with Dr. Ananya Sharma.
2. Show the consultation time, reason, and device/readiness guidance.
3. Join the same `consult_apt_001` Jitsi room using the patient's display name.
4. Log call lifecycle/status changes in the patient mock repository.
5. Open a call-complete screen automatically and show the call duration.
6. Return to the patient home screen.

## Supported platforms

- Android API 26 or newer.
- iOS 15.1 or newer.

The Jitsi Meet Flutter SDK does not support this project's Flutter Web or
Windows desktop targets. Do not run either app with `-d chrome` or `-d windows`.

Android API 26 is required because the native Jitsi 13.1.1 artifact declares
that minimum. Both apps also use a Gradle `finalizeDsl` hook to compile Android
library modules with SDK 36. This works around Jitsi 13.1.1 compiling its plugin
at SDK 34 while its Media3 1.8 dependencies require SDK 35 or newer. It does not
change the apps' minimum or target SDK at runtime.

Kotlin incremental compilation is disabled in both Android projects because the
repository is on `D:` while the shared Pub cache is on `C:`. Without this setting,
the Jitsi plugin's Kotlin compiler cannot create relocatable incremental-cache
paths across Windows drives.

## Prerequisites

- Flutter stable. The projects were created with Flutter 3.47.2 and Dart
  3.13.2.
- Java 17 or newer.
- Android Studio or Android command-line tools with Android SDK 36.
- Two Android emulators/devices running API 26+ for app-to-app testing.
- A macOS machine with Xcode and CocoaPods for iOS builds.
- Camera, microphone, and internet access on call-testing devices.

Check the development environment:

```shell
flutter doctor
flutter devices
```

## Install dependencies

Dependencies must be resolved separately for each app:

```shell
cd doctor_app
flutter pub get
cd ../patient_app
flutter pub get
cd ..
```

## Run the apps

List device IDs first:

```shell
flutter devices
```

Run the doctor app on one Android device:

```shell
cd doctor_app
flutter run -d <doctor-device-id>
```

In a second terminal, run the patient app on another Android device:

```shell
cd patient_app
flutter run -d <patient-device-id>
```

For emulator camera testing, enable webcam passthrough in the emulator's
extended controls. Physical devices generally provide more reliable camera,
microphone, and picture-in-picture behavior.

### iOS

On macOS, prepare each app independently. For example:

```shell
cd doctor_app
flutter pub get
cd ios
pod install
cd ..
flutter run -d <doctor-ios-device-id>
```

Repeat from `patient_app/` for the patient device. Camera and microphone usage
descriptions and the iOS 15.1 deployment target are configured in both apps.

## Automated checks

Run analysis and tests in both apps:

```shell
cd doctor_app
flutter analyze
flutter test

cd ../patient_app
flutter analyze
flutter test
```

Doctor tests cover queue gating, patient details, consent gating, call duration,
repeatable prescriptions, referral fields, note saving, and completion status.

Patient tests cover the ready appointment, consultation details, join action,
call duration, and returning from the call-complete screen.

Native Jitsi calls are not exercised by Flutter widget tests and require manual
device testing.

## Build Android APKs

Build each app from its directory:

```shell
cd doctor_app
flutter build apk --debug

cd ../patient_app
flutter build apk --debug
```

Outputs:

```text
doctor_app/build/app/outputs/flutter-apk/app-debug.apk
patient_app/build/app/outputs/flutter-apk/app-debug.apk
```

Universal debug APKs are large because they include debug artifacts, Jitsi, and
native binaries for multiple Android architectures.

## Manual end-to-end test

1. Launch the doctor app and patient app on different devices.
2. In the doctor app, select Ramesh Kumar, accept the consent statement, and tap
   Start consultation.
3. In the patient app, open the appointment and tap Join consultation.
4. Grant camera and microphone permissions on both devices.
5. Confirm both participants can see and hear each other.
6. End the call on both devices.
7. Confirm the doctor app opens the clinical form and the patient app opens the
   call-complete screen with a non-zero duration.
8. Save the doctor form and verify that Sunita Devi becomes the next enabled
   appointment.

If only one mobile device is available, run either app and open
`https://meet.jit.si/consult_apt_001` in a desktop browser as the other
participant.

## Current limitations and security notice

- All records and status changes are in-memory and reset on restart.
- There is no backend synchronization between the apps.
- Rooms use predictable appointment IDs on the public `meet.jit.si` service.
- There is no JWT/JaaS authentication or assigned-user enforcement.
- There are no push notifications, persistent records, ABHA, FHIR, diagnostics,
  or booking features.
- iOS configuration is included but was not built on this Windows machine.
- Jitsi 13.1.1 emits a non-blocking warning about future Flutter support for
  plugins that apply the Kotlin Gradle Plugin directly. Reassess the Gradle
  workaround when upgrading Flutter or Jitsi.

This prototype must not be used for real patient care or sensitive health data
without authenticated rooms, secure storage, a compliant backend, access
controls, audit logging, and an appropriate privacy/security review.
