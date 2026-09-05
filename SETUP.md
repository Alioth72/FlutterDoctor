# Beginner setup guide: Firebase, FlutterFire, TURN, and real-device testing

This guide is written for the current project at:

```text
C:\Users\Faaiz\Desktop\SIH_v2
```

Follow the sections in order. Do not start the BPM/model work yet. The video call
must first work between two real Android phones on different networks.

## Current progress — updated 6 September 2026

- [x] Firebase project `sih-teleconsultation` created.
- [ ] Confirm the Firebase Console shows the Cloud Firestore **Data** tab (Step 2).
- [x] Firebase CLI and FlutterFire CLI setup completed.
- [x] Patient Android app registered as `in.sih.patient_app`.
- [x] Doctor Android app registered as `in.sih.doctor_app`.
- [x] Both generated `firebase_options.dart` files wired into `main.dart`.
- [x] Both apps pass `flutter analyze` and widget tests.
- [x] Doctor APK builds with Firebase; the patient Google Services task also
  completes successfully.
- [ ] Metered/Open Relay credential setup.
- [ ] Two-phone same-network call test.
- [ ] Two-phone different-network call test.

**Continue at Step 8.** Steps 1–7 are complete and should not be repeated unless
the Firebase project or Android application IDs change.

## What these services mean

### Firebase project

A Firebase project is a cloud workspace owned by your Google account. In this
prototype it provides **Cloud Firestore**, which acts like a temporary mailbox:

- the patient app writes a WebRTC call offer;
- the doctor app reads it and writes an answer;
- both apps exchange network connection candidates;
- the audio and video do **not** pass through Firestore.

Both Flutter apps must connect to the **same** Firebase project. The mock
appointment ID `apt_001` then points both apps to the same signaling document.

### Firebase CLI

The Firebase command-line interface lets your computer sign in to Firebase and
see the projects belonging to your Google account. Its command is `firebase`.

### FlutterFire CLI

FlutterFire is a configuration tool for connecting a Flutter app to Firebase.
Its command is `flutterfire`. It generates a `firebase_options.dart` file with
the correct Firebase project identifiers. Those identifiers are configuration,
not an administrator password.

### TURN / Open Relay

WebRTC normally tries to connect the two phones directly. Some mobile networks,
routers, and firewalls prevent that. A TURN server relays the already-encrypted
WebRTC media when a direct connection is impossible. This project uses
Metered/Open Relay for that job.

## What is already installed

The following are already available on this computer:

- Flutter and Dart;
- Android Studio and the Android SDK;
- Node.js 24;
- both Flutter projects and their dependencies.

The following still need to be installed/configured:

- Firebase CLI;
- FlutterFire CLI;
- one Firebase project with Firestore;
- one Metered/Open Relay TURN credential;
- two physical Android devices for the end-to-end test.

## Step 0 — make enough free disk space

The first Android builds used approximately 2 GB of temporary files per app and
the C: drive ran out of space. Before installing or building anything, open:

```text
Windows Settings → System → Storage
```

Try to have at least **5 GB free on C:**. More is preferable.

Flutter build folders are reproducible and safe to clear. If necessary, open
PowerShell and run:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2\patient_app
flutter clean

cd C:\Users\Faaiz\Desktop\SIH_v2\doctor_app
flutter clean
```

`flutter clean` removes generated build files, not source code. The APK can be
rebuilt later.

## Step 1 — create the Firebase project

You need a Google account and a web browser.

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Sign in with the Google account you want to use for the hackathon.
3. Click **Create a project** or **Add project**.
4. Give it a recognizable name, such as `SIH Teleconsultation`.
5. Firebase also creates a project ID. It may look like
   `sih-teleconsultation-12345`. Record this exact project ID; the display name
   and project ID are not the same thing.
6. Google Analytics is optional for this prototype. You may disable it to keep
   setup simple.
7. Accept the terms and click **Create project**.
8. Wait for project creation to finish, then click **Continue**.

Do not create a separate Firebase project for each app. Patient and doctor must
use the same project.

Official reference: [Get started with Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)

## Step 2 — enable Cloud Firestore

1. In your new Firebase project, use the left menu and open
   **Build → Firestore Database**. In a newer console it may appear under
   **Databases & Storage → Firestore**.
2. Click **Create database**.
3. Choose the standard/default Firestore database if an edition is requested.
4. Choose **Start in test mode**.
5. Select a database location near the intended users. Read the warning before
   confirming because the location normally cannot be changed later.
6. Click **Create** or **Enable** and wait until the data screen appears.

Test mode is deliberately being used only for the hackathon prototype. It lets
mobile clients read and write without authentication. It is unsafe for real
patient data and must not be used for a production healthcare deployment. Do
not enter real patient information during these tests.

Firebase may give test rules an expiry date. If calls later fail with
`permission-denied`, inspect the **Rules** tab and check whether the temporary
test period expired.

Official reference: [Create a Cloud Firestore database](https://firebase.google.com/docs/firestore/quickstart#create)

## Step 3 — install the Firebase CLI

Open a **new PowerShell window**. You may also use the terminal inside Android
Studio.

This computer blocks PowerShell `.ps1` scripts, so use `npm.cmd` exactly as shown
instead of `npm`.

### Repair the stale Administrator/NVM PATH entries first

On this computer, `npm.cmd --version` was tested and initially failed with:

```text
EPERM: operation not permitted, lstat 'C:\Users\Administrator\AppData'
```

This happens because the **system PATH** contains three entries belonging to an
old Administrator account:

```text
C:\Users\Administrator\AppData\Local\nvm
C:\nvm4w\nodejs
C:\Users\Administrator\AppData\Local\nvm
```

`C:\nvm4w\nodejs` is also a symbolic link back into the inaccessible
Administrator directory. The valid Node installation for the current account is:

```text
C:\Users\Faaiz\node
```

#### Permanent fix (recommended)

1. Close any installer or terminal currently using Node.
2. Press the Windows key and search for **Edit the system environment variables**.
3. Open it, select the **Advanced** tab, then click **Environment Variables**.
4. Under **System variables**, select `Path` and click **Edit**. Administrator
   approval may be requested.
5. Remove both copies of:

   ```text
   C:\Users\Administrator\AppData\Local\nvm
   ```

6. Also remove:

   ```text
   C:\nvm4w\nodejs
   ```

7. Do not delete any folders from the disk; remove only these PATH rows.
8. Under **User variables for Faaiz**, select `Path` and click **Edit**. If a
   user `Path` does not exist, click **New** to create it.
9. Make sure this row exists in the user PATH:

   ```text
   C:\Users\Faaiz\node
   ```

10. Click **OK** on every dialog.
11. Close every PowerShell/Android Studio terminal and open a new PowerShell
    window so it receives the corrected PATH.
12. Verify the exact executables selected by Windows:

    ```powershell
    where.exe node
    where.exe npm.cmd
    node --version
    npm.cmd --version
    ```

The first two commands should point to `C:\Users\Faaiz\node`. The expected
versions currently installed are Node `v24.13.0` and npm `11.6.2`.

#### Temporary fix (use only if you cannot edit the system PATH yet)

Run this in the current PowerShell window:

```powershell
$env:Path = (($env:Path -split ';' | Where-Object {
  $_ -ne 'C:\Users\Administrator\AppData\Local\nvm' -and
  $_ -ne 'C:\nvm4w\nodejs'
}) -join ';')
$env:Path += ';C:\Users\Faaiz\node'
npm.cmd --version
```

This temporary command was verified on this computer and returns `11.6.2`. It
changes only the current PowerShell process and is lost when that window closes.

First verify Node and npm:

```powershell
node --version
npm.cmd --version
```

Then install the Firebase CLI:

```powershell
npm.cmd install -g firebase-tools
```

The download may take a few minutes. After it finishes, close PowerShell, open a
new PowerShell window, and verify:

```powershell
firebase --version
```

If `firebase` is not recognized, find npm's global directory:

```powershell
npm.cmd config get prefix
```

The returned directory contains `firebase.cmd`. Add that directory to the
Windows user `Path`, or invoke `firebase.cmd` from that directory. Do not change
the system-wide PowerShell execution policy just to run npm.

Official reference: [Install the Firebase CLI on Windows](https://firebase.google.com/docs/cli#windows)

## Step 4 — sign the Firebase CLI into your Google account

Run:

```powershell
firebase login
```

1. A browser should open.
2. Select the same Google account used in Step 1.
3. Approve the Firebase CLI permission request.
4. Return to PowerShell after the success page appears.

Verify that the project is visible:

```powershell
firebase projects:list
```

Find the project ID recorded in Step 1. If it is missing, the CLI is signed into
the wrong Google account. Run `firebase logout`, then `firebase login` again.

If the browser cannot return to the CLI, try:

```powershell
firebase login --no-localhost
```

and follow the displayed instructions.

## Step 5 — install the FlutterFire CLI

Run this from any directory:

```powershell
dart pub global activate flutterfire_cli
```

Then verify:

```powershell
flutterfire --version
```

If `flutterfire` is not recognized, add Dart's executable directory to the
current PowerShell session:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
flutterfire --version
```

For a permanent fix:

1. Search Windows for **Edit environment variables for your account**.
2. Select the user variable named `Path` and click **Edit**.
3. Add this entry:

   ```text
   C:\Users\Faaiz\AppData\Local\Pub\Cache\bin
   ```

4. Save the dialogs and open a new PowerShell window.

Official reference: [Install and use FlutterFire](https://firebase.google.com/docs/flutter/setup#install-cli-tools)

## Step 6 — configure the patient app

Replace `YOUR_FIREBASE_PROJECT_ID` below with the exact project ID from Step 1.
Do not include `<` or `>` characters.

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2\patient_app
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID --platforms=android
```

During the questions:

1. Select the Firebase project created in Step 1 if asked.
2. Select or confirm **Android** only for this first milestone.
3. Confirm the detected Android application ID:

   ```text
   in.sih.patient_app
   ```

4. If it asks whether to create/register a Firebase Android app, answer yes.

When it succeeds, this file should exist:

```text
C:\Users\Faaiz\Desktop\SIH_v2\patient_app\lib\firebase_options.dart
```

## Step 7 — configure the doctor app

Use the **same Firebase project ID**:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2\doctor_app
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID --platforms=android
```

Confirm the detected Android application ID:

```text
in.sih.doctor_app
```

The doctor app must be registered as a second Android app inside the existing
Firebase project. Do not create another Firebase project.

When it succeeds, this file should exist:

```text
C:\Users\Faaiz\Desktop\SIH_v2\doctor_app\lib\firebase_options.dart
```

### Stop and return to Codex here

This checkpoint was completed on 6 September 2026. Both generated files were
verified, connected to the apps, analyzed, tested, and checked by Gradle. If you
are following the live project, continue directly to Step 8.

For a fresh setup, after both `firebase_options.dart` files exist, tell Codex:

```text
FlutterFire is configured for both apps. My Firebase project ID is ______.
```

The project ID is safe to share. Do not paste passwords or account secret keys.
Codex must connect the generated options to both `main.dart` files and run the
checks before you continue to the call test.

## Step 8 — create a Metered/Open Relay account

You can prepare this while Codex wires Firebase into the apps.

1. Open [Metered Open Relay](https://www.metered.ca/tools/openrelay/).
2. Create an account or sign in.
3. Create a Metered application/domain if the dashboard asks for one.
4. Open the **TURN Server** area in the Metered dashboard.
5. Click **Generate your first credential** or **Add credential**.
6. Give it a label such as `sih-development`.
7. Find **Show API Key** for that TURN credential.

Use the credential-scoped **API Key**. Never put the account-level **Secret
Key** from the Developers page in a Flutter app. Metered documents the
credential API key as suitable for frontend use; the account Secret Key is not.

Construct this URL by replacing both uppercase placeholders:

```text
https://YOUR_APP_NAME.metered.live/api/v1/turn/credentials?apiKey=YOUR_TURN_API_KEY
```

Test it by pasting the completed URL into a browser. A successful response is a
JSON array similar to this shape:

```json
[
  {"urls": "stun:..."},
  {
    "urls": "turn:...",
    "username": "...",
    "credential": "..."
  }
]
```

If you see an error object, an HTML login page, or an empty list, do not continue.
Recheck the application name and credential API key.

Official references:

- [Open Relay credential endpoint](https://www.metered.ca/tools/openrelay/)
- [Create TURN credentials](https://www.metered.ca/docs/turn-server-service/creating-turn-credentials/)

## Step 9 — keep the TURN URL out of source code

Do not paste the completed TURN URL into a Dart file or commit it. Set it only in
each terminal used to run an app:

```powershell
$env:TURN_CREDENTIALS_URL = 'PASTE_THE_COMPLETE_URL_HERE'
```

Keep the single quotes. Verify only that the variable is non-empty:

```powershell
if ($env:TURN_CREDENTIALS_URL) { 'TURN URL is set' } else { 'TURN URL is missing' }
```

Do not run `Write-Output $env:TURN_CREDENTIALS_URL` during screen sharing because
that displays the credential API key.

The variable lasts only for the current PowerShell window. Repeat the assignment
in every new terminal used to run an app.

## Step 10 — prepare two Android phones

Use two physical phones. An emulator is not sufficient for validating a rural
mobile-network video call or the later remote-video frame capture.

On each phone:

1. Open **Settings → About phone**.
2. Tap **Build number** seven times. Some brands place it under
   **Software information**.
3. Enter the phone PIN if requested.
4. Return to Settings and open **Developer options**.
5. Enable **USB debugging**.
6. Connect the phone to the computer with a data-capable USB cable.
7. Accept the **Allow USB debugging** prompt on the phone.

Check detection:

```powershell
flutter devices
```

You should see two Android device IDs. Record which ID belongs to the patient
phone and which belongs to the doctor phone. If a phone says `unauthorized`,
unlock it and accept the USB debugging prompt. On Windows, some phone brands
also require their OEM USB driver.

Official references:

- [Flutter: set up a physical Android device](https://docs.flutter.dev/platform-integration/android/setup#set-up-an-android-device)
- [Android: run apps on a hardware device](https://developer.android.com/studio/run/device)

## Step 11 — run both apps

Complete this section only after Codex has wired the generated Firebase options
and confirmed the checks pass.

### Terminal A: patient app

Open PowerShell:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2\patient_app
$env:TURN_CREDENTIALS_URL = 'PASTE_THE_COMPLETE_URL_HERE'
flutter run -d PATIENT_DEVICE_ID --dart-define="TURN_CREDENTIALS_URL=$env:TURN_CREDENTIALS_URL"
```

Replace `PATIENT_DEVICE_ID` with the exact ID printed by `flutter devices`.

### Terminal B: doctor app

Open a second PowerShell window:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2\doctor_app
$env:TURN_CREDENTIALS_URL = 'PASTE_THE_COMPLETE_URL_HERE'
flutter run -d DOCTOR_DEVICE_ID --dart-define="TURN_CREDENTIALS_URL=$env:TURN_CREDENTIALS_URL"
```

Replace `DOCTOR_DEVICE_ID` with the doctor phone's ID.

When Android asks for camera and microphone permissions, choose **Allow while
using the app** on both phones.

## Step 12 — perform the first same-network test

Keep both phones on the same Wi-Fi network for the first test. This makes basic
signaling problems easier to diagnose.

1. On the doctor app, open the first queue entry, `Asha Devi / apt_001`.
2. Tick the doctor consent checkbox and tap **Start consultation**. The doctor
   app can wait for the patient.
3. On the patient app, tick the consent checkbox and tap **Join call**.
4. Wait up to 20 seconds for initial negotiation.
5. Confirm that each phone can see and hear the other.
6. Test mute, camera off/on, and hang-up from each side.
7. Complete and save the doctor post-call form.
8. Start `apt_001` again without restarting the apps to check repeat-call
   signaling. The code uses a new session ID for every attempt.

In the Firebase Console, **Firestore Database → Data** should show something like:

```text
teleconsult_calls
└── apt_001
    ├── offer
    ├── answer
    ├── sessionId
    ├── patientCandidates (subcollection)
    └── doctorCandidates (subcollection)
```

These are signaling records, not stored audio/video.

## Step 13 — perform the different-network test

After the same-Wi-Fi call works:

1. Leave one phone on Wi-Fi.
2. Turn Wi-Fi off on the other phone and use mobile data.
3. Keep USB connected; USB debugging does not force the phone to use the
   computer's internet connection.
4. Repeat the complete `apt_001` call.
5. Test at least two minutes of audio/video, mute, camera toggle, remote hang-up,
   and a second call.
6. Put each app in the background briefly and record what happens when it
   returns. Do not claim reconnection works unless you observed it.

A successful different-network call validates real ICE negotiation, but it does
not by itself prove that TURN was the selected route. After this test, Codex can
add a small WebRTC statistics/debug panel to report whether the selected
candidate type is `relay`.

## Step 14 — report the result to Codex

Send the following information:

```text
Firebase project ID:
Both firebase_options.dart files exist: yes/no
TURN endpoint returns a JSON array: yes/no
Patient phone model and Android version:
Doctor phone model and Android version:
Same-Wi-Fi call result:
Different-network call result:
Two-way video works: yes/no
Two-way audio works: yes/no
Mute/camera/end controls work: yes/no
Second call without app restart works: yes/no
Background/foreground result:
Any error text or terminal log:
```

Do not send:

- your Google password;
- the Metered account Secret Key;
- the completed TURN URL or TURN API key;
- any real patient's information.

## Common problems

### `npm.ps1 cannot be loaded because running scripts is disabled`

Use `npm.cmd`, for example:

```powershell
npm.cmd install -g firebase-tools
```

### `EPERM ... lstat 'C:\Users\Administrator\AppData'`

The system PATH still contains the old Administrator/NVM entries. Follow
**Step 3 → Repair the stale Administrator/NVM PATH entries first**. As a quick
check, `where.exe npm.cmd` should resolve to:

```text
C:\Users\Faaiz\node\npm.cmd
```

### `firebase is not recognized`

Close and reopen PowerShell. If it remains missing, run
`npm.cmd config get prefix` and add that directory to the user `Path`.

### `flutterfire is not recognized`

Run:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

Then retry `flutterfire --version`.

### The app says Firebase setup is required

Both `firebase_options.dart` files must exist and Codex must wire them into the
two `main.dart` files. Stop and return to Codex after Step 7.

### Firestore reports `permission-denied`

Check **Firestore Database → Rules** in the Firebase Console. Confirm this is the
test project and that its temporary test-mode access has not expired. Never make
a production healthcare database public.

### The call says `TURN_CREDENTIALS_URL is missing`

The environment variable was not passed to that app. Set it again in the same
terminal and include the `--dart-define` argument in `flutter run`.

### One app stays on “Waiting for patient/doctor”

Check all of these:

- both apps were configured with the same Firebase project ID;
- both use appointment `apt_001`;
- Firestore test access is active;
- the Firebase Console shows `teleconsult_calls/apt_001` after the patient joins;
- both phones have internet access;
- the terminal shows no `permission-denied` or Firebase initialization error.

### Camera or microphone does not work

Open the phone's **Settings → Apps → Swasthya Connect → Permissions** and allow
Camera and Microphone. Close any other app currently using the camera.

### Build fails with “There is not enough space on the disk”

Run `flutter clean` in the app that you are not currently building and free at
least 5 GB on C:. This exact machine encountered that issue during the initial
doctor build.

## What happens after these steps

Only after the two-device video call is stable should BPM work begin. The next
phase will be:

1. capture timestamped frames from the doctor's incoming patient video;
2. detect/crop the face and measure capture/hit rates;
3. obtain the exact ME-rPPG model and recurrent-state configuration;
4. add ONNX inference;
5. add timing-aware BPM extraction, confidence gating, and the rolling chart.

Do not download an arbitrary file named `model.onnx`. The correct model must have
known input/output tensor names, shapes, preprocessing, recurrent state layout,
and a license that permits use. Once the video-call milestone passes, provide
the intended ME-rPPG repository or paper implementation link and Codex can help
verify or convert the checkpoint safely.
