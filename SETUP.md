# Beginner setup guide: Firebase, FlutterFire, TURN, and real-device testing

This guide is written for the current project at:

```text
C:\Users\Faaiz\Desktop\SIH_v2
```

Follow the sections in order. Do not start the BPM/model work yet. The video call
must first work between two real Android phones on different networks.

## Current progress — updated 6 September 2026

- [x] Firebase project `sih-teleconsultation` created.
- [x] Cloud Firestore default database and **Data** tab confirmed.
- [x] Prototype signaling rules deployed from `firestore.rules`.
- [x] Firebase CLI and FlutterFire CLI setup completed.
- [x] Patient Android app registered as `in.sih.patient_app`.
- [x] Doctor Android app registered as `in.sih.doctor_app`.
- [x] Both generated `firebase_options.dart` files wired into `main.dart`.
- [x] Both apps pass `flutter analyze` and widget tests.
- [x] Doctor APK builds with Firebase; the patient Google Services task also
  completes successfully.
- [x] Metered/Open Relay credential setup completed by the participant.
- [ ] Build the two TURN-enabled shareable APKs (Step 10).
- [ ] Two-phone same-network call test.
- [ ] Two-phone different-network call test.

**Continue at Step 9.** Steps 1–8 are complete and should not be repeated unless
the Firebase project, Android application IDs, or TURN credential changes.

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

## Step 9 — set the TURN URL for the APK build

Do not paste the completed TURN URL into a Dart file or commit it. Open a new
PowerShell window and set it only for that window:

```powershell
$env:TURN_CREDENTIALS_URL = 'PASTE_THE_COMPLETE_URL_HERE'
```

Keep the single quotes. Verify only that the variable is non-empty:

```powershell
if ($env:TURN_CREDENTIALS_URL) { 'TURN URL is set' } else { 'TURN URL is missing' }
```

Do not run `Write-Output $env:TURN_CREDENTIALS_URL` during screen sharing because
that displays the credential API key.

The variable lasts only for the current PowerShell window. The APK build embeds
the credential-scoped frontend key because the app must fetch TURN servers at
runtime. Never use Metered's account-level Secret Key here.

## Step 10 — build two shareable APKs

The repository includes `build_test_apks.ps1`. It validates that the environment
variable looks like the expected Metered endpoint, builds the apps sequentially
to limit disk/memory usage, and copies them to clearly named output files.

In the **same PowerShell window** where Step 9 set the TURN URL, run:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2
.\build_test_apks.ps1
```

The builds run one after the other. They can take several minutes even when the
terminal is quiet. With 9.12 GB free on C:, there should be enough room for both,
but do not start other large downloads during the build.

Successful output files:

```text
C:\Users\Faaiz\Desktop\SIH_v2\test_apks\Swasthya-Patient-debug.apk
C:\Users\Faaiz\Desktop\SIH_v2\test_apks\Swasthya-Doctor-debug.apk
```

The `test_apks` directory is ignored by Git. Do not upload these development APKs
to the public repository because the TURN credential-scoped key is embedded in
them. They are suitable for controlled hackathon testing, not production release.

If PowerShell blocks the script itself, run only this temporary command in that
window and retry:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\build_test_apks.ps1
```

`-Scope Process` affects only the current PowerShell process and reverts when the
window closes.

## Step 11 — share and install the APKs without USB debugging

USB debugging is not required for this test. Use two physical Android phones;
an emulator is not sufficient for validating mobile-network behavior or the
later remote-video frame capture.

Share the files using Google Drive, Quick Share, email, a messaging service, or a
normal USB file transfer:

1. Send `Swasthya-Patient-debug.apk` to the patient phone.
2. Send `Swasthya-Doctor-debug.apk` to the doctor phone.
3. On each phone, open the downloaded APK.
4. If Android blocks it, open the shown settings page and enable **Allow from
   this source** for the app that opened the APK (for example Files or Drive).
5. Return to the installer and tap **Install**.
6. If Android reports a conflicting signature or refuses to update an older
   test build, uninstall that app and install the new APK again.
7. Open each app and allow Camera and Microphone **while using the app**.

The apps have different Android package IDs, so installing one does not overwrite
the other. Make sure each phone receives the correct role-specific APK.

Keep the APK files private within the test team. Anyone holding a debug APK can
extract its client-side configuration, which is expected for mobile apps but is
another reason this prototype must not contain real patient data.

### Limitation of APK-only testing

APK-only installation is convenient, but the computer will not receive live
Flutter logs. First use the on-screen status and Firestore Data tab. If a call
fails without a clear message, connect only the affected phone by USB later and
collect logs; USB is a debugging fallback, not a prerequisite.

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
3. Repeat the complete `apt_001` call using the already-installed APKs.
4. Test at least two minutes of audio/video, mute, camera toggle, remote hang-up,
   and a second call.
5. Put each app in the background briefly and record what happens when it
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

The project now stores its signaling rules in the root `firestore.rules` file.
They allow unauthenticated prototype access only to `teleconsult_calls` and its
patient/doctor ICE-candidate subcollections; all unrelated paths remain denied.

The rules were deployed to `sih-teleconsultation` on 6 September 2026. If they
are changed in the Firebase Console later, keep the local file synchronized to
avoid overwriting those edits. To redeploy the checked-in rules deliberately:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2
firebase.cmd deploy --only firestore:rules --project sih-teleconsultation
```

Rules may take a short time to affect new listeners. Force-close both apps and
reopen them before retesting. Never use these unauthenticated prototype rules or
real patient information in a production healthcare deployment.

### The call says `TURN_CREDENTIALS_URL is missing`

That APK was built without the required define. Uninstall it, set the environment
variable, rerun `build_test_apks.ps1`, and install the newly generated APK.

### Android says “App not installed”

An older copy may have the same package ID but a different signing certificate.
Uninstall the old patient/doctor test app, then install the new APK. Also confirm
the phone has enough free storage and permits installation from the file source.

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

## Step 15 — test BPM frame capture and face preparation

The call milestone is complete. The first BPM pipeline stage is now implemented
in the **doctor app only**. It captures the incoming patient's WebRTC video,
detects the largest face on-device, and prepares a normalized 36×36 RGB crop.
It does not calculate or display BPM yet.

Build fresh APKs from the same PowerShell window in which your private Metered
URL is set:

```powershell
cd C:\Users\Faaiz\Desktop\SIH_v2
$env:TURN_CREDENTIALS_URL = 'YOUR_EXISTING_COMPLETE_METERED_URL'
.\build_test_apks.ps1
```

Do not paste that URL into chat or commit it. Install the new APKs from
`test_apks` on both phones. If Android refuses to update an existing install,
uninstall that app first and install the fresh APK again.

Start a call normally. On the doctor screen, the **AI-assisted vitals** card now
shows:

- a 36×36 preview of the detected patient face;
- the actual frame capture rate in frames per second (`fps`);
- face-detection hit percentage (`hit`);
- total captured frames and processing time per frame;
- a short orange error if capture or detection fails.

Test for at least 60 seconds in bright, even light. The patient should keep one
face visible, reasonably still, and large enough to occupy roughly one quarter
of the video height. Then briefly turn away, cover the camera, and return to the
same position; the hit rate should fall and recover rather than inventing data.

For this checkpoint, a useful result is:

- the frame count rises continuously;
- the face preview resembles the patient's face and has sensible colour;
- steady-face hit rate is usually at least 70%;
- capture rate is at least 3 fps, preferably 6 fps or more;
- there is no repeated orange error or call instability.

Send Codex this result before model inference is added:

```text
Doctor phone model and Android version:
Capture rate after 60 seconds:
Face hit percentage after 60 seconds:
Typical milliseconds/frame:
Face preview looks correctly cropped and coloured: yes/no
Rate/hit recovers after face leaves and returns: yes/no
Any orange error text:
Call audio/video remained stable: yes/no
```

A capture rate below 3 fps does not mean the experiment has failed. It means the
PNG polling or per-frame face detection needs optimisation before ONNX inference;
adding the model first would make that bottleneck harder to diagnose.

### Step 15 first device result and optimisation

On a Realme Narzo 60 Pro 5G running Android 15, the initial implementation
measured about 2.8 fps after 521 frames (4.2 fps briefly at startup), 323 ms per
frame, and an 89% face-detection hit rate. Detection quality passed, but the
model-ready cadence was marginal.

The doctor app now runs ML Kit periodically and reuses the most recent face box
for intermediate frames. The card separately reports raw capture fps and `face
fps` (the rate of 36×36 model-ready inputs). Rebuild both APKs and repeat the
60-second test. Report both rates; `face fps` is the important ONNX input rate.

The first optimised retest reached 3.5 capture/face fps with 100% detection, but
the periodic detection frame took about 697 ms. The patient app now requests a
640×480, 20 fps camera stream instead of flutter_webrtc's 1280×720, 30 fps
Android default. This preserves much more detail than the model's final 36×36
input while reducing remote JPEG capture work by roughly two thirds.

The diagnostics now show `capture`, `detect`, and `prepare` milliseconds plus
the actual incoming frame dimensions. In the next 60-second retest, send a
screenshot from an ordinary frame and another when the `detect` time has just
updated. The incoming dimensions should be approximately 640×480 or 480×640,
depending on phone orientation.

That retest reached 5.4 capture/face fps, 100% detection, 150 ms capture, 114 ms
detection, and 59 ms preparation at 480×640. This is a substantial improvement
but remains below the 8 fps minimum needed to sample the full 0.7–4 Hz analysis
band without aliasing. The patient stream is therefore now 320×240 at 20 fps;
the next incoming frame should be about 240×320 in portrait. Keep the patient's
face fairly close and occupying at least one quarter of the frame height.

The call status also now allows a transient failed/disconnected ICE route eight
seconds to recover. During this grace period it shows **Finding another network
route…** or **Reconnecting…**. It only displays **Connection failed** if no route
recovers, avoiding the misleading failure message observed before a successful
connection.

## Remaining BPM stages

After Step 15 passes:

1. bundle the verified official ME-rPPG model and recurrent state — complete;
2. run recurrent, timestamp-aware ONNX inference and inspect raw BVP — ready
   for Step 16 testing;
3. implement timing-aware BPM extraction and signal-quality gating;
4. add the reliable-reading overlay, rolling chart, and post-call summary;
5. repeat the two-device/different-network end-to-end test.

The official source supplied for this project has been checked: its model input
is a 36×36 RGB face image scaled to 0–1, and inference carries 36 state tensors
plus a real elapsed-time input between frames. Keep the medical limitation clear:
this is an experimental screening estimate from compressed call video, not a
diagnostic or clinical-grade measurement.

## Step 16 — test ME-rPPG raw BVP inference

The 320×240 capture retest passed with 8.3 model-ready face fps, 97% detection,
36 ms capture time, and 240×320 incoming frames on the Realme Narzo 60 Pro 5G.
The official ME-rPPG model and its 36 recurrent states are now integrated into
the doctor app. Only the doctor APK needs to change for this step.

Rebuild using `build_test_apks.ps1` and reinstall the doctor APK. During a call,
the diagnostics should progress from **Loading ME-rPPG model…** to **Raw BVP
active**. The card will show:

- the latest raw BVP value;
- ONNX inference time in milliseconds;
- total BVP samples processed;
- frames dropped while the model was loading or busy.

Run the call for at least two minutes. Keep the patient's head and lighting
steady for the first minute, then make a small head movement and return to the
original position. Confirm that the BVP sample count rises continuously and the
raw BVP value changes without `NaN`, `Infinity`, crashes, or an orange model
error. Do **not** interpret the BVP number as heart rate; this checkpoint only
validates recurrent inference.

Send Codex:

```text
Status reaches Raw BVP active: yes/no
Typical ONNX inference time:
BVP samples after two minutes:
Dropped frames after two minutes:
Face fps while inference is active:
Raw BVP changes and remains finite: yes/no
Any orange ME-rPPG error:
Call audio/video remained stable: yes/no
```

Once this passes, the next implementation adds the timestamp-aware signal
window, BPM extraction, confidence gating, and rolling chart.

## Step 17 — test confidence-gated BPM and chart

The Step 16 device test passed with 8.5 face fps, 91% face-detection hits,
approximately 79 ms ONNX inference, 787 finite BVP samples, and a stable call.
Timing-aware BPM extraction is now enabled in the doctor app.

Rebuild and reinstall the doctor APK. Start a call with the patient seated,
reasonably still, their face close to the phone, and even front lighting. The
doctor card will collect 20 seconds of raw BVP before attempting an estimate.
After that:

- a BPM number appears only when confidence is at least 50%;
- low-quality or stale input shows **Measuring BPM…** instead of retaining a
  potentially misleading number;
- the displayed `BVP fps` is calculated from real capture timestamps;
- `range ≤… BPM` reports the highest rate resolvable at that sample cadence;
- the bottom chart contains only confidence-approved readings from the latest
  60 seconds.

Test for three minutes. Remain steady for the first minute. For the next 15
seconds, turn away or cover the camera and confirm the number disappears. Return
to the original position and allow a fresh analysis window to form. If a pulse
oximeter is available, record its reading only as a rough comparison; do not
treat agreement in one test as clinical validation.

Send Codex:

```text
First BPM appeared after approximately how many seconds:
Displayed BPM and confidence while steady:
Displayed BVP fps and resolvable range:
Chart updated: yes/no
BPM disappeared after face was removed: yes/no
BPM recovered after returning: yes/no
Approximate pulse-oximeter/manual reference, if available:
Any crash, orange error, or call degradation:
```
