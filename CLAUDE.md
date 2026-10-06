# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This is a monorepo with several independent projects. Each has its own `pubspec.yaml` / `package.json`, so run commands inside the right folder.

| Path | What it is |
|---|---|
| `doctor_app/` | Flutter app for doctors, health workers, and admins (app label "ASHWINI Doctor") |
| `patient_app/` | Flutter app for patients |
| `doctor_app/backend/` | Azure Functions v4 (TypeScript, Node 22) REST API backed by Azure Database for PostgreSQL. **Both apps use this backend.** |
| `patient_app/backend/` | Separate Python FastAPI + SQLite service for government health-scheme matching (MyScheme.gov.in data). It is unrelated to the Postgres backend. |
| `{doctor_app,patient_app}/packages/hrx_protocol` | Local Dart package for the offline QR medical-record protocol |
| `{doctor_app,patient_app}/packages/teleconsult_vitals` | Local Dart package for vitals telemetry during teleconsults |
| repo root (`lib/`, `pubspec.yaml` named `chatbot_healthcare`) | Standalone sandbox for the offline medical chatbot. The feature is developed here and **copied** into `patient_app/lib/features/chatbot/` (see `INTEGRATION_GUIDE.md`, `context.md`). |

`doctor_app/patient_app/` is a stale local copy that is excluded through `.git/info/exclude`. Do not edit it.

The two local packages are **duplicated, not shared**. Each app depends on its own copy through `path:`. A change to `hrx_protocol` or `teleconsult_vitals` usually has to be made in both `doctor_app/packages/` and `patient_app/packages/`. The copies already differ slightly; for example, only the patient copy of `hrx_protocol.dart` has a `library hrx_protocol;` line.

## Commands

Flutter (run inside `doctor_app/`, `patient_app/`, a package folder, or the repo root):

```bash
flutter pub get
flutter analyze                                   # lints: package:flutter_lints/flutter.yaml
flutter test                                      # all tests in this project
flutter test test/qr_patient_test.dart            # one file
flutter test test/qr_patient_test.dart --plain-name "Patient QR"   # one test/group by name
dart run build_runner build --delete-conflicting-outputs   # regenerate Isar/ObjectBox code (root chatbot app)
```

Some tests in `patient_app/test/` call live external APIs: `sarvam_*`, `gemini_vision_live_test`, `comprehensive_22_languages_backtest`. They need API keys and network access, so expect them to fail offline.

Azure Functions backend (`doctor_app/backend/`):

```bash
npm install
npm run build        # tsc -> dist/
npm start            # builds, then `func start` on http://localhost:7071/api
```

The backend has no test suite. The `db-test` and `hello` routes are smoke checks. Local settings, including the Postgres connection (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `PGSSL`) and `AUTH_JWT_SECRET`, live in `local.settings.json`. That file is gitignored.

Scheme backend (`patient_app/`): `run_backend.sh` / `run_backend.bat` runs `uvicorn backend.main:app --port 8000`.

### Build-time configuration (`--dart-define`)

- `USE_AZURE_STAGING` (doctor_app, default `true`): when `true`, the app calls the deployed backend at `https://fn-ashwini-health-b5246f.azurewebsites.net/api`. When `false`, it calls the local `func start` backend: `10.0.2.2:7071` on the Android emulator, `localhost:7071` elsewhere.
- `PATIENT_API_BASE_URL` (patient_app): overrides the same Azure Functions base URL.
- `TURN_CREDENTIALS_URL` (both apps): the Metered/Open Relay TURN credential endpoint for WebRTC. Never commit it.
- `SARVAM_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY` (patient_app chatbot, translation, speech): read from a bundled `.env` first, then from dart-defines.

## Architecture

### Backend (Azure Functions + Postgres)
- `src/index.ts` imports every `src/functions/*.ts` module. Each module registers its routes with `app.http(...)`. A new function file must be imported in `index.ts`, or it is never registered.
- `src/db.ts` exposes one shared `pg` `Pool`, with `query(text, params)` as the only data-access helper. There is no ORM.
- All tables are in the Postgres schema `health`. `patient_app/backend/schema.sql` is the **SQLite scheme-matching** schema, not the Postgres one.
- Authentication is a hand-rolled HMAC JWT (`src/utils/token.ts`, signed with `AUTH_JWT_SECRET`) plus bcrypt passwords. Handlers call `authenticate(request)` from `src/utils/auth.ts`, which returns either an error `HttpResponseInit` or a `TokenPayload` (`user_id`, `role`, `patient_id`, `staff_profile_id`, …). Branch on the role in the payload.
- Route groups: `auth/*`, `me/*` (the logged-in patient's own appointments, records, and prescriptions), `patients/*`, `appointments/*` (including `pre-call-vitals` and `telehealth-access`), `staff/*` (admin), `doctors/*`, `facilities`, `inventory`, `machines`.
- `dist/` is gitignored build output. `func start` runs whatever is in `dist/`, so run `npm run build` after changing `src/` (`npm start` does this automatically).
- Postgres DDL lives in `doctor_app/backend/sql/schema.sql`. It was reconstructed from the backend queries, so update it whenever a query starts using a new table or column.

### Flutter apps
- doctor_app: all REST calls go through the static `ApiClient` (`lib/services/api_client.dart`), which attaches the Bearer token from `AuthService`. Screens are plain `StatefulWidget`s in `lib/screens/`.
- patient_app: uses `provider` for state (`lib/providers/`: appointments, health profile, language, schemes). Backend access goes through `services/patient_database_service.dart`. `SharedPreferences` holds the local profile.
- **Teleconsult video** (`*/teleconsult/` in doctor_app, `services/teleconsult/` in patient_app) uses `flutter_webrtc`, with **Firebase Firestore as the only signaling channel**. Both sides open `teleconsult_calls/{appointmentId}` and exchange offer/answer and ICE candidates in sub-collections. The doctor and the patient must use the same backend appointment ID. `firestore.rules` is a prototype and not authenticated. Firestore is the only non-Azure data store.
- **Heart-rate (rPPG) vitals**: the patient app estimates heart rate on the device from the camera (`google_mlkit_face_detection` + `flutter_onnxruntime`) and streams it to the doctor through `teleconsult_vitals`. Pre-call measurements are saved through `appointments/{id}/pre-call-vitals`.
- **Offline QR records** (`hrx_protocol`): patient and visit records are encoded with CBOR, Deflate compression, and Base45 into QR payloads (`HRX:` / `HRX:Z:` prefixes). The doctor app scans and decodes them in `qr_workflow_screen.dart`. The round-trip tests live in `packages/hrx_protocol/test/`.
- **Localization** (patient_app): there is no ARB/`intl` setup. Strings come from the large hand-maintained `services/localization/app_strings.dart` (23 languages), backed by `offline_phrase_engine.dart`, with Sarvam AI translation as an online fallback. Never feed lookup keys to the translator or transliterator.
- **Chatbot** (`features/chatbot/`, clean-architecture `domain/` + `data/` split):
  - Storage: Isar keeps chat history.
  - Retrieval (RAG): ObjectBox HNSW vector search over 768-dimension PubMedBERT embeddings, which are computed on the device through ONNX.
  - Safety: emergency-keyword triage runs before retrieval.
  - Online answers: a cloud LLM (Groq or Gemini).
  - Offline answers: an extractive fallback.

### UI copy
User-facing strings must not expose internal model or tech names such as "ME-rPPG", "ONNX", or "BlazeFace", or developer diagnostics. Use plain clinical wording, for example "Camera Heart Rate Scan".
