# Doctor Teleconsult

A doctor-side Flutter application for assisted teleconsultations in rural and
underserved public-health settings. It was built for a Smart India Hackathon
problem focused on improving healthcare access, continuity, and quality.

This repository currently implements only the doctor teleconsultation flow. It
uses an in-memory mock repository and the Jitsi Meet Flutter SDK; no backend or
patient application is included.

## What the app does

- Shows today's mock patient queue in queue-position order.
- Enables the Join action only for the first waiting patient.
- Presents the patient's summary and requires practitioner consent.
- Starts a native Jitsi meeting on `https://meet.jit.si` using room name
  `consult_<appointmentId>`.
- Tracks call start, end, duration, errors, and appointment status.
- Collects clinical notes, repeatable prescription rows, and an optional
  referral after the call.
- Returns to the refreshed dashboard so the next waiting patient can be joined.

The mock data contains two appointments: `apt_001` for Ramesh Kumar and
`apt_002` for Sunita Devi. All data resets when the application restarts.

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/models/` | Appointment, consent, call-log, prescription, and consultation-note models |
| `lib/data/appointment_repository.dart` | Repository contract and in-memory mock implementation |
| `lib/screens/` | Dashboard, pre-call consent, and post-call form screens |
| `lib/services/jitsi_call_service.dart` | Jitsi configuration, lifecycle listeners, and post-call navigation |
| `test/widget_test.dart` | Queue-gating and post-call form widget tests |

State is intentionally managed with `StatefulWidget` and `setState`. The only
data abstraction is `AppointmentRepository`, which can later be implemented by
a real backend.

## Supported platforms

- Android API 26 or newer.
- iOS 15.1 or newer.

Jitsi Meet does not support this app's Flutter Web or Windows desktop targets.
Do not run it with `-d chrome` or `-d windows`.

Android API 26 is required because the native Jitsi 13.1.1 artifact declares
that minimum, even though the Flutter wrapper currently documents API 24. The
root Android Gradle configuration also compiles library modules with SDK 36
through Gradle's `finalizeDsl` hook. This works around Jitsi 13.1.1 compiling
its plugin at SDK 34 while its Media3 1.8 dependencies require SDK 35 or newer.
Neither setting changes the app's target SDK at runtime.

## Prerequisites

- Flutter on the stable channel. The project was verified with Flutter 3.47.2
  and Dart 3.13.2.
- Android Studio or the Android command-line tools, including Android SDK 36.
- Java 17 or newer.
- An Android emulator/device running API 26+, or a macOS machine with Xcode and
  CocoaPods for iOS development.
- A working internet connection for dependency downloads and Jitsi calls.
- Camera and microphone access on the test device.

Check the local environment before continuing:

```shell
flutter doctor
flutter devices
```

## Setup and run

From the repository root:

```shell
flutter pub get
flutter run -d <android-device-id>
```

Replace `<android-device-id>` with an ID listed by `flutter devices`. For camera
testing on an Android emulator, enable webcam passthrough in the emulator's
extended controls. A physical Android device generally gives more reliable
camera, microphone, and picture-in-picture testing.

On macOS, the iOS flow can be prepared and run with:

```shell
flutter pub get
cd ios
pod install
cd ..
flutter run -d <ios-device-id>
```

Camera and microphone usage descriptions are already configured in
`ios/Runner/Info.plist`.

## Automated checks

Run static analysis and widget tests from the repository root:

```shell
flutter analyze
flutter test
```

The widget suite verifies that:

- only `apt_001` initially has an enabled Join action;
- the correct patient summary opens;
- the Start consultation button is gated by consent;
- call duration is displayed;
- prescription rows can be added;
- referral fields appear when enabled; and
- saving records the note and completes the appointment.

The Jitsi call itself is native functionality and is not exercised by Flutter
widget tests.

## Build an Android APK

Create a debug APK with:

```shell
flutter build apk --debug
```

The generated file is:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

The universal debug APK is large (approximately 280 MB) because it includes
debug symbols, Flutter artifacts, Jitsi, and binaries for multiple Android
architectures. This is expected for development builds.

## Test a real consultation

1. Launch the app on an Android emulator or physical device.
2. Tap Join for Ramesh Kumar.
3. Confirm the patient details and select the consent checkbox.
4. Tap Start consultation and grant camera/microphone permissions.
5. On another device or desktop browser, open
   `https://meet.jit.si/consult_apt_001`. Using a different network is useful
   for confirming that the call connects beyond the local environment.
6. Confirm that both participants can see and hear each other.
7. End the call from Jitsi. The app should automatically open the post-call
   form and display a non-zero duration.
8. Enter notes/prescription details, optionally enable a referral, and save.
9. Confirm that Ramesh is completed and Sunita now has the enabled Join action.

Also verify that the Jitsi toolbar does not expose chat, invitations, adding
people, calendar, live streaming, recording, meeting name/password, raise hand,
or tile view, and that no prejoin screen appears.

## Current limitations and security notice

- Records are mock, in-memory data and are not persisted.
- Rooms use predictable appointment IDs on the public `meet.jit.si` service.
- There is no JWT/JaaS authentication or assigned-doctor enforcement.
- There is no patient-side app, backend, push notification, ABHA, or FHIR
  integration.
- iOS configuration is present but has not been built on this Windows machine.
- Jitsi 13.1.1 emits a non-blocking warning about future Flutter support for
  plugins that apply the Kotlin Gradle Plugin directly. Reassess the Gradle
  workaround when upgrading Flutter or Jitsi.

This prototype must not be used for real patient care or sensitive health data
without authenticated rooms, secure storage, a compliant backend, access
controls, audit logging, and an appropriate privacy/security review.
