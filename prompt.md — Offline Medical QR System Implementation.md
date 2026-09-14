# Offline Medical QR System — Implementation Specification

## 1. Project Objective

Implement a complete QR-based medical record exchange system between the existing:

1. **Patient App**
2. **Doctor App**

The database/backend is a **separate entity** and will be integrated later.

For this phase, DO NOT implement or depend on:

- Firebase
- PostgreSQL
- FastAPI
- REST APIs
- Cloud storage
- Authentication servers
- Backend database
- Internet connectivity

The entire QR generation, encoding, scanning, decoding, extraction, validation, and local demonstration flow must work independently.

The architecture must be designed so that the database/API can be plugged in later without rewriting the QR protocol or QR processing engine.

---

# 2. Core Requirement

The Patient App must display exactly **6 QR records**:

### QR 1 — Patient Identity QR

This QR identifies the patient.

It must NOT contain the patient's complete medical history.

It should contain a secure opaque patient reference that can later be used by the backend to fetch the patient's complete history.

Example conceptual payload:

```json
{
  "protocol": "HRX",
  "version": 1,
  "type": "PATIENT",
  "patient_ref": "P-7A92F81C"
}
```

The actual production encoding should use a compact representation.

---

### QR 2–6 — Five Offline Visit QRs

The remaining five QRs represent the patient's five most recent medical visits.

Each QR must contain the complete **structured visit data** required for an offline doctor consultation.

The doctor must be able to scan one of these QRs with no internet connection and reconstruct the original visit record.

---

# 3. High-Level Architecture

Implement the following architecture:

```text
                         PATIENT APP
                              |
                 +------------+------------+
                 |                         |
          Patient QR Generator      Visit QR Generator
                 |                         |
                 |                  +------+------+
                 |                  |             |
                 |              Visit 1 ...    Visit 5
                 |                  |             |
                 +------------------+-------------+
                                    |
                               QR Protocol
                                    |
                         Physical QR / Camera
                                    |
                                    v
                            DOCTOR APP
                                    |
                              QR Scanner
                                    |
                         QR Type Detection
                         /               \
                        /                 \
               PATIENT QR             VISIT QR
                   |                      |
            Patient Handler        Offline Extractor
                                          |
                              +-----------+-----------+
                              |           |           |
                           Verify      Decrypt     Decompress
                              |           |           |
                              +-----------+-----------+
                                          |
                                    Deserialize
                                          |
                                    Validate Schema
                                          |
                                          v
                                  Visit Record Viewer
```

---

# 4. Important Architectural Rule

The Patient App and Doctor App MUST use the same QR protocol specification.

Do not independently invent the encoding format in each app.

Create a shared conceptual protocol:

```text
HRX — Health Record Exchange
```

Version:

```text
HRX v1
```

The Patient App implements:

```text
HRX Encoder
```

The Doctor App implements:

```text
HRX Decoder
```

Both must follow the exact same specification.

If the technology stack allows shared packages/modules, create a shared package for:

- data models
- serialization
- protocol constants
- validation rules
- encoding metadata

If a shared package is impossible because the apps use different languages, document the protocol precisely and implement compatible versions.

---

# 5. QR Types

Support exactly two QR types in Version 1.

## Type A — PATIENT

```text
type = PATIENT
```

Purpose:

Identify the patient.

Payload concept:

```json
{
  "protocol": "HRX",
  "version": 1,
  "type": "PATIENT",
  "patient_ref": "P-7A92F81C"
}
```

Do not put complete medical history in this QR.

---

## Type B — VISIT

```text
type = VISIT
```

Purpose:

Carry one complete offline medical visit.

Payload concept:

```json
{
  "protocol": "HRX",
  "version": 1,
  "type": "VISIT",
  "visit_id": "V1001",
  "patient_ref": "P-7A92F81C",
  "date": "2026-09-13",
  "doctor": "D100",
  "complaints": [],
  "diagnosis": [],
  "vitals": {},
  "medications": [],
  "tests": [],
  "advice": [],
  "notes": ""
}
```

The exact fields should be implemented as a versioned schema.

---

# 6. Patient Record Model

Create a local patient model for Phase 1.

Example:

```json
{
  "patient_ref": "P-7A92F81C",
  "patient_id": "DEMO-001",
  "name": "Demo Patient",
  "date_of_birth": "2000-01-01",
  "gender": "Other",
  "blood_group": "O+",
  "phone": "",
  "visits": []
}
```

Use fictional/demo data only during development.

Do not require a backend.

---

# 7. Visit Record Model

Create a strongly typed structured visit model.

Recommended fields:

```json
{
  "visit_id": "V1001",
  "patient_ref": "P-7A92F81C",
  "doctor_ref": "D100",
  "facility_ref": "F100",
  "timestamp": "2026-09-13T10:30:00Z",

  "chief_complaints": [
    "fever",
    "cough"
  ],

  "symptoms": [],

  "diagnosis": [
    {
      "code": "DEMO",
      "name": "Demo diagnosis"
    }
  ],

  "vitals": {
    "temperature": 38.2,
    "blood_pressure_systolic": 120,
    "blood_pressure_diastolic": 80,
    "pulse": 84,
    "spo2": 98,
    "weight": 60
  },

  "medications": [
    {
      "name": "Demo Medicine",
      "strength": "500mg",
      "dose": "1 tablet",
      "frequency": "1-0-1",
      "duration": 5,
      "duration_unit": "days",
      "route": "oral",
      "instructions": "After food"
    }
  ],

  "lab_tests": [],

  "procedures": [],

  "allergies": [],

  "advice": [
    "Rest",
    "Drink sufficient fluids"
  ],

  "follow_up": {
    "required": true,
    "date": "2026-09-20"
  },

  "notes": ""
}
```

Make fields extensible for future versions.

---

# 8. Do Not Store Medical Records as PDFs for QR

The primary QR record must be a structured data object.

Do NOT implement this pipeline:

```text
Visit
→ PDF
→ Compress PDF
→ QR
```

Instead implement:

```text
Visit Object
→ Compact Serialization
→ Compression
→ Encryption
→ Integrity Protection
→ QR Payload
→ QR
```

Large attachments such as:

- X-rays
- MRI
- CT scans
- images
- large PDFs

are OUT OF SCOPE for the first version.

The architecture should allow attachment references to be added later.

---

# 9. Serialization

Use a compact binary serialization format where supported.

Preferred:

```text
CBOR
```

Alternative:

```text
MessagePack
```

Do not rely on pretty-printed JSON inside the QR.

JSON may be used as the application-level model, but the QR payload should use compact serialization.

---

# 10. Compression

After serialization, compress the binary data.

Preferred:

```text
Zstandard
```

If Zstandard is not available in the target mobile environment, use a well-supported alternative such as:

```text
Brotli
```

or:

```text
Deflate
```

The algorithm must be recorded in the QR header.

Example:

```text
compression = "zstd"
```

Do NOT encrypt before compression.

Correct order:

```text
Serialize
    ↓
Compress
    ↓
Encrypt
```

---

# 11. Encryption

Offline medical visit data must NOT be stored in plaintext inside the QR.

Use authenticated encryption.

Preferred:

```text
AES-256-GCM
```

The implementation must generate a unique cryptographic nonce/IV for every encrypted record.

Never use a fixed nonce.

Do not hard-code production encryption keys.

---

# 12. Key Management for Phase 1

Because the database/backend does not exist yet, create a **development/demo key-management abstraction**.

Example:

```text
KeyProvider
```

Interface:

```text
getEncryptionKey()
getVerificationKey()
```

For the Phase 1 prototype, use securely generated local development keys.

Clearly separate:

```text
DEVELOPMENT KEY PROVIDER
```

from:

```text
PRODUCTION KEY PROVIDER
```

The production key system will be implemented later.

Do not hard-code secret keys directly in source code.

Do not place a master secret inside the QR.

Do not expose encryption keys in logs.

---

# 13. Integrity and Tamper Detection

Every offline visit QR must provide integrity protection.

The Doctor App must be able to detect if the QR payload has been modified.

Use authenticated encryption and, where the architecture requires independent authenticity verification, use a digital signature.

Preferred signature algorithm:

```text
Ed25519
```

The system should conceptually perform:

```text
Visit Data
    ↓
Serialize
    ↓
Compress
    ↓
Encrypt
    ↓
Generate integrity/signature information
    ↓
QR
```

Doctor:

```text
QR
 ↓
Parse
 ↓
Verify integrity/signature
 ↓
Decrypt
 ↓
Decompress
 ↓
Deserialize
```

If verification fails:

```text
DO NOT DISPLAY THE MEDICAL RECORD AS TRUSTED
```

Show an explicit error.

---

# 14. QR Packet Format

Define a versioned QR packet.

Conceptually:

```text
HRX
VERSION
TYPE
RECORD_ID
PATIENT_REF
COMPRESSION
ENCRYPTION
KEY_ID
NONCE
PAYLOAD
INTEGRITY/SIGNATURE
```

Do not simply concatenate arbitrary strings.

Implement a proper compact packet structure.

Recommended conceptual structure:

```text
HRX Packet
├── magic
├── protocol_version
├── packet_type
├── schema_version
├── record_id
├── patient_ref
├── compression_algorithm
├── encryption_algorithm
├── key_id
├── nonce
├── payload
└── signature
```

All fields must have deterministic encoding.

---

# 15. Patient QR Generation Pipeline

Implement:

```text
createPatientQR(patient)
```

Pipeline:

```text
Patient Reference
       ↓
Create Patient QR Object
       ↓
Serialize
       ↓
Generate QR
       ↓
Display QR
```

The generated QR must be scannable by the Doctor App.

---

# 16. Offline Visit QR Generation Pipeline

Implement:

```text
createVisitQR(visit)
```

Pipeline:

```text
Visit Object
       ↓
Validate Visit Schema
       ↓
Compact Serialization
       ↓
Compression
       ↓
Encryption
       ↓
Integrity/Signature
       ↓
Create HRX Packet
       ↓
Encode for QR
       ↓
Generate QR Image
```

The function should return both:

```text
QR image
```

and:

```text
encoding statistics
```

Example:

```json
{
  "original_size": 8421,
  "serialized_size": 6932,
  "compressed_size": 2148,
  "encrypted_size": 2176,
  "final_payload_size": 2241,
  "qr_version": 25,
  "status": "FITS"
}
```

---

# 17. QR Capacity Management

This is a critical requirement.

The application MUST NOT assume that compression guarantees that every visit fits into one QR.

The encoder must calculate the final payload size.

Implement:

```text
checkQRCapacity(payload)
```

If the record fits:

```text
status = FITS
```

If it does not:

```text
status = TOO_LARGE
```

Do not generate a misleading QR that cannot contain the complete record.

Show:

```text
This visit is too large for a single QR code.
Reduce the record size or use a future multi-part/attachment mechanism.
```

For Phase 1, do NOT implement multi-part QR unless explicitly requested later.

---

# 18. QR Error Correction

Use a configurable QR error correction level.

Default to a sensible level that balances:

- reliability
- physical scanning
- payload capacity

Do not automatically use the highest error correction if it unnecessarily reduces capacity.

Make this configurable.

Example:

```text
QR_ERROR_CORRECTION = M
```

---

# 19. Five Offline QR Rotation

The Patient App must maintain exactly five offline visit slots.

```text
offlineVisit1
offlineVisit2
offlineVisit3
offlineVisit4
offlineVisit5
```

When a new visit is added:

```text
New Visit → Slot 1
Old Slot 1 → Slot 2
Old Slot 2 → Slot 3
Old Slot 3 → Slot 4
Old Slot 4 → Slot 5
Old Slot 5 → Removed
```

Example:

Before:

```text
Slot 1 = Visit A
Slot 2 = Visit B
Slot 3 = Visit C
Slot 4 = Visit D
Slot 5 = Visit E
```

After Visit F:

```text
Slot 1 = Visit F
Slot 2 = Visit A
Slot 3 = Visit B
Slot 4 = Visit C
Slot 5 = Visit D
```

Visit E is removed from the five-slot offline cache.

---

# 20. Patient App UI

Add a section:

```text
My Health QR
```

Display:

```text
Patient Identity QR
```

Then:

```text
Offline Medical Records

Visit 1
Visit 2
Visit 3
Visit 4
Visit 5
```

Each visit should show:

```text
Visit Date
Doctor
Diagnosis summary
QR
```

Provide a button:

```text
View QR
```

and optionally:

```text
Save QR
Share QR
```

Sharing should only share the QR image/data, not internal application secrets.

---

# 21. Patient App QR Screen

Create a dedicated QR screen:

```text
--------------------------------
        PATIENT HEALTH QR
--------------------------------

          [ QR CODE ]

Patient Reference
P-7A92F81C

Status:
✓ Valid

--------------------------------
```

For visit:

```text
--------------------------------
        OFFLINE VISIT QR
--------------------------------

          [ QR CODE ]

Visit:
V1001

Date:
13 Sep 2026

Status:
✓ Encrypted
✓ Integrity protected
✓ Fits QR capacity

Payload:
2.2 KB
--------------------------------
```

---

# 22. Doctor App Scanner

Create a dedicated:

```text
Scan Medical QR
```

screen.

The scanner must continuously detect QR codes.

After detection:

```text
Read QR
 ↓
Parse HRX header
 ↓
Validate protocol
 ↓
Detect type
```

Then route:

```text
PATIENT → Patient QR Handler

VISIT → Offline Visit Extractor
```

---

# 23. Doctor App Patient QR Handler

When a Patient QR is scanned:

```text
Scan
 ↓
Decode
 ↓
Validate HRX
 ↓
Check type = PATIENT
 ↓
Extract patient_ref
```

For Phase 1, there is no backend.

Therefore create a local/demo lookup:

```text
patient_ref
    ↓
Local Demo Patient Repository
    ↓
Patient Record
```

Example:

```text
Patient:
Demo Patient

Patient Reference:
P-7A92F81C

Visits:
5
```

IMPORTANT:

This local lookup exists ONLY to demonstrate the UI.

Design it behind an abstraction:

```text
PatientRepository
```

Later:

```text
LocalPatientRepository
```

can be replaced/extended by:

```text
RemotePatientRepository
```

without modifying the scanner.

---

# 24. Doctor App Offline Visit Extractor

Create a dedicated component:

```text
HealthRecordQRExtractor
```

It must perform:

```text
QR Image
 ↓
QR Decoder
 ↓
HRX Packet Parser
 ↓
Protocol Validation
 ↓
Schema Version Check
 ↓
Integrity Verification
 ↓
Signature Verification
 ↓
Decryption
 ↓
Decompression
 ↓
Deserialization
 ↓
Visit Schema Validation
 ↓
VisitRecord
```

The extractor should return a structured result.

Example:

```json
{
  "success": true,
  "record": {},
  "metadata": {
    "protocol_version": 1,
    "schema_version": 1,
    "encrypted": true,
    "compressed": true,
    "integrity_verified": true,
    "signature_verified": true
  }
}
```

---

# 25. Extraction Errors

Create specific errors.

Examples:

```text
INVALID_QR
UNKNOWN_PROTOCOL
UNSUPPORTED_VERSION
INVALID_PACKET
INVALID_SIGNATURE
INTEGRITY_FAILURE
DECRYPTION_FAILURE
DECOMPRESSION_FAILURE
DESERIALIZATION_FAILURE
INVALID_SCHEMA
MISSING_FIELD
PAYLOAD_TOO_LARGE
UNKNOWN_KEY
```

Do not show raw stack traces to the user.

Instead show friendly messages.

Example:

```text
Unable to read this medical record.

The QR code may be damaged, modified, expired,
or generated by an unsupported version of the system.
```

---

# 26. Doctor App Visit Viewer

After successful extraction, display:

```text
------------------------------------
        OFFLINE VISIT RECORD
------------------------------------

Patient Reference:
P-7A92F81C

Visit ID:
V1001

Date:
13 September 2026

Doctor:
Demo Doctor

------------------------------------
CHIEF COMPLAINTS

• Fever
• Cough

------------------------------------
DIAGNOSIS

Demo Diagnosis

------------------------------------
VITALS

Temperature: 38.2 °C
Blood Pressure: 120/80
Pulse: 84
SpO2: 98%

------------------------------------
PRESCRIPTION

Demo Medicine
500mg
1 tablet
1-0-1
5 days

------------------------------------
ADVICE

Rest
Drink sufficient fluids

------------------------------------

✓ QR integrity verified
✓ Record decrypted
✓ Record decompressed
✓ Schema validated

OFFLINE RECORD
------------------------------------
```

---

# 27. Developer / Debug Screen

Implement a development-only QR diagnostics screen.

For every generated visit show:

```text
Visit ID
Original Data Size
Serialized Size
Compressed Size
Encrypted Size
Final QR Payload Size
QR Version
Error Correction Level
Compression Algorithm
Encryption Algorithm
Protocol Version
Schema Version
```

Example:

```text
QR DIAGNOSTICS

Visit ID:
V1001

Original:
8.42 KB

Serialized:
6.93 KB

Compressed:
2.15 KB

Encrypted:
2.18 KB

Final Payload:
2.24 KB

QR Version:
XX

Compression:
Zstandard

Encryption:
AES-256-GCM

Protocol:
HRX v1

Status:
✓ FITS
```

This screen is extremely important for testing.

---

# 28. End-to-End Demo Data

Create at least five demo visits.

They should vary in size.

### Visit 1

Small:

```text
Basic consultation
1 diagnosis
1 medicine
```

### Visit 2

Medium:

```text
Multiple symptoms
Multiple vitals
Multiple medicines
```

### Visit 3

Larger:

```text
Multiple diagnoses
Multiple medications
Lab tests
Doctor notes
```

### Visit 4

Large:

```text
Many structured fields
```

### Visit 5

Large stress-test record.

The purpose is to test QR capacity and compression.

---

# 29. Automated Round-Trip Test

This is mandatory.

For every demo visit:

```text
Original Visit
     ↓
Encode
     ↓
QR Payload
     ↓
Decode
     ↓
Decrypt
     ↓
Decompress
     ↓
Deserialize
     ↓
Decoded Visit
```

Then compare:

```text
Original Visit == Decoded Visit
```

The test must pass.

Example:

```text
Visit V1001
✓ Encode
✓ Compress
✓ Encrypt
✓ QR payload
✓ Decode
✓ Verify
✓ Decrypt
✓ Decompress
✓ Deserialize
✓ Original == Decoded
```

---

# 30. Tamper Test

Create an automated test that modifies one byte of the encrypted payload.

Expected result:

```text
✓ Tampering detected
✗ Record NOT displayed
```

The system must never silently accept modified medical data.

---

# 31. Wrong Key Test

Attempt to decode a visit using the wrong development key.

Expected:

```text
DECRYPTION_FAILURE
```

No medical data should be displayed.

---

# 32. Wrong Protocol Test

Create:

```text
UNKNOWN_PROTOCOL
```

QR.

Expected:

```text
Unsupported medical QR format.
```

---

# 33. Version Test

Create:

```text
HRX v999
```

QR.

Expected:

```text
Unsupported QR protocol version.
```

The application must not crash.

---

# 34. Corrupted QR Test

Corrupt the encoded payload.

Expected:

```text
INVALID_PACKET
```

or:

```text
INTEGRITY_FAILURE
```

depending on where corruption is detected.

---

# 35. Database Abstraction

Even though there is no database in Phase 1, DO NOT tightly couple the UI to local mock data.

Create interfaces/abstractions.

Example:

```text
PatientRepository
VisitRepository
```

Phase 1:

```text
LocalPatientRepository
LocalVisitRepository
```

Future:

```text
RemotePatientRepository
RemoteVisitRepository
```

The QR layer should operate on:

```text
PatientRecord
VisitRecord
```

rather than directly accessing the database.

---

# 36. Future Database Integration

The future architecture should look like:

```text
Patient App
    |
    +---- Local QR Engine
    |
    +---- Backend Repository
                 |
                 v
              Database


Doctor App
    |
    +---- QR Engine
    |
    +---- Backend Repository
                 |
                 v
              Database
```

The QR engine must remain independent.

---

# 37. Offline-First Requirement

The following must work with:

```text
Airplane Mode ON
```

for the offline visit QR flow.

Required:

```text
Patient App
→ Display Visit QR

Doctor App
→ Scan Visit QR
→ Decode
→ Decrypt
→ Decompress
→ Display Visit
```

No network call should be attempted for the offline visit extraction.

---

# 38. No Backend Calls in QR Extraction

The Doctor App must NOT do this:

```text
Scan QR
 ↓
Internet
 ↓
API
 ↓
Decode record
```

Instead:

```text
Scan QR
 ↓
Local extraction engine
 ↓
Medical record
```

The purpose of the five visit QRs is offline access.

---

# 39. Security Requirements

Never:

- log decrypted medical records
- log encryption keys
- log plaintext QR payloads
- hard-code production keys
- put master secrets inside QR codes
- put database credentials inside mobile apps
- put Firebase service-account credentials inside mobile apps
- trust an unverified QR
- display a tampered record as valid

Use secure local storage for cryptographic development keys.

Production key management will be implemented later.

---

# 40. Privacy Requirements

The Patient QR should contain the minimum information necessary.

Prefer:

```text
opaque patient_ref
```

rather than:

```text
name
phone
address
medical history
```

The five offline visit QRs necessarily contain medical information, so they must be encrypted.

Do not display the plaintext contents of a visit QR in debugging logs.

---

# 41. QR Image Requirements

The generated QR should:

- have sufficient contrast
- have a proper quiet zone
- maintain a square aspect ratio
- remain scannable after screenshotting
- remain scannable when displayed on a phone
- work across the Patient and Doctor apps
- be exportable as PNG
- be testable from another physical device

Do not generate QR codes so dense that normal phone cameras cannot reliably scan them.

---

# 42. Camera Scanner Requirements

The Doctor App scanner must:

- request camera permission
- show a scanning frame
- detect QR automatically
- prevent duplicate rapid scans
- provide vibration/visual feedback
- stop scanning after successful extraction
- allow scanning again
- display clear errors
- work in normal indoor lighting

---

# 43. UI States

The scanner must have these states:

```text
READY
SCANNING
PROCESSING
VALIDATING
DECRYPTING
SUCCESS
ERROR
```

Example:

```text
Scanning...
```

Then:

```text
Reading medical record...
```

Then:

```text
Verifying record...
```

Then:

```text
Record successfully extracted.
```

---

# 44. Architecture / Folder Structure

Adapt this structure to the existing project architecture.

Conceptually:

```text
qr/
├── protocol/
│   ├── constants
│   ├── packet
│   ├── version
│   └── schema
│
├── models/
│   ├── patient_record
│   └── visit_record
│
├── encoder/
│   ├── serializer
│   ├── compressor
│   ├── encryptor
│   ├── signer
│   ├── packet_builder
│   └── qr_generator
│
├── decoder/
│   ├── qr_reader
│   ├── packet_parser
│   ├── verifier
│   ├── decryptor
│   ├── decompressor
│   ├── deserializer
│   └── validator
│
├── repositories/
│   ├── patient_repository
│   └── visit_repository
│
└── tests/
    ├── round_trip
    ├── tamper
    ├── corruption
    ├── wrong_key
    ├── version
    └── capacity
```

Use the existing project's language/framework and conventions rather than unnecessarily migrating the application.

---

# 45. Do Not Rewrite Existing Application

Before making changes:

1. Inspect the existing Patient App.
2. Inspect the existing Doctor App.
3. Identify the current architecture.
4. Identify navigation.
5. Identify existing models.
6. Identify existing state management.
7. Identify existing local storage.
8. Identify the existing camera/scanner capabilities.
9. Identify existing dependencies.

Then integrate the QR system into the existing architecture.

Do not replace working application components unnecessarily.

Do not introduce a new framework merely for this feature.

---

# 46. Required Patient App Features

Implement:

```text
[ ] Patient QR screen
[ ] Five offline visit QR cards
[ ] Visit detail screen
[ ] Generate Patient QR
[ ] Generate Visit QR
[ ] QR capacity calculation
[ ] Compression statistics
[ ] Encryption
[ ] Integrity protection
[ ] QR image rendering
[ ] Five-visit rotation
[ ] Demo patient repository
[ ] Demo visit repository
```

---

# 47. Required Doctor App Features

Implement:

```text
[ ] QR scanner
[ ] QR protocol detector
[ ] Patient QR handler
[ ] Visit QR handler
[ ] Offline extractor
[ ] Decryption
[ ] Decompression
[ ] Deserialization
[ ] Integrity verification
[ ] Schema validation
[ ] Patient demo lookup
[ ] Offline visit viewer
[ ] Error handling
[ ] Scanner retry
```

---

# 48. Required Tests

Implement automated tests for:

```text
[ ] Patient QR generation
[ ] Patient QR scanning
[ ] Visit QR generation
[ ] Visit QR scanning
[ ] Encode/decode round trip
[ ] Compression/decompression
[ ] Encryption/decryption
[ ] Signature verification
[ ] Tamper detection
[ ] Corrupted payload
[ ] Wrong key
[ ] Unsupported protocol
[ ] Unsupported version
[ ] Invalid schema
[ ] QR capacity
[ ] Five-visit rotation
[ ] Offline mode
```

---

# 49. Acceptance Test 1 — Patient QR

1. Open Patient App.
2. Open My Health QR.
3. Display Patient QR.
4. Open Doctor App.
5. Scan QR.
6. Doctor App detects:

```text
PATIENT
```

7. Extract:

```text
patient_ref
```

8. Look up the demo patient locally.
9. Display demo patient information.

PASS condition:

```text
Patient QR works without backend.
```

---

# 50. Acceptance Test 2 — Offline Visit QR

1. Open Patient App.
2. Open Visit 1.
3. Display QR.
4. Put both devices in airplane mode.
5. Open Doctor App.
6. Scan Visit QR.
7. Decode.
8. Verify.
9. Decrypt.
10. Decompress.
11. Deserialize.
12. Display complete visit.

PASS condition:

```text
The doctor can reconstruct the visit with zero network access.
```

---

# 51. Acceptance Test 3 — Exact Round Trip

Given:

```json
{
  "visit_id": "V1001",
  "diagnosis": ["Demo"],
  "medications": [
    {
      "name": "Demo Medicine",
      "dose": "500mg",
      "frequency": "1-0-1"
    }
  ]
}
```

After:

```text
encode → QR → scan → decode
```

the resulting object must contain exactly equivalent information.

PASS:

```text
original == decoded
```

---

# 52. Acceptance Test 4 — Tampering

1. Generate valid Visit QR.
2. Modify the encoded payload.
3. Scan with Doctor App.

Expected:

```text
Record verification failed.
```

The record must NOT be displayed as valid.

---

# 53. Acceptance Test 5 — No Internet

Enable airplane mode on both devices.

Then:

```text
Patient App
→ Show Visit QR

Doctor App
→ Scan Visit QR
→ Extract Visit
```

No network access is allowed.

PASS:

```text
Complete offline extraction works.
```

---

# 54. Acceptance Test 6 — Five Visit Rotation

Initial:

```text
QR1 = Visit A
QR2 = Visit B
QR3 = Visit C
QR4 = Visit D
QR5 = Visit E
```

Add Visit F.

Expected:

```text
QR1 = Visit F
QR2 = Visit A
QR3 = Visit B
QR4 = Visit C
QR5 = Visit D
```

PASS:

```text
Exactly five offline visits remain.
```

---

# 55. Acceptance Test 7 — Oversized Visit

Create an artificially large visit.

The application must detect:

```text
TOO_LARGE
```

and explain that the visit cannot fit into a single QR.

It must NOT:

- silently truncate data
- remove medical fields
- generate an invalid QR
- pretend the record is complete

---

# 56. Future Compatibility

Design the protocol so future versions can support:

```text
HRX v2
```

and potentially:

```text
Multi-part QR
Attachment references
ABDM/FHIR mapping
Backend synchronization
Doctor authentication
Patient consent
Key rotation
QR expiration
Offline credentials
```

These are NOT required in Phase 1.

Do not implement them unless needed to support the current architecture.

---

# 57. Important Separation of Concerns

Keep these layers independent:

```text
UI
 ↓
Application Logic
 ↓
Repository
 ↓
Medical Data Model
 ↓
QR Protocol
 ↓
Crypto/Compression
 ↓
QR Generator/Scanner
```

Do not put encryption logic directly into UI widgets/components.

Do not put QR generation directly into database models.

Do not make the scanner depend on the backend.

---

# 58. Logging

Development logs may show:

```text
QR type
Protocol version
Record ID
Payload size
Compression ratio
Processing time
Success/failure
```

Do NOT log:

```text
plaintext medical records
plaintext encrypted payloads
encryption keys
private keys
patient sensitive data
```

---

# 59. Performance

QR generation and extraction should be fast enough for normal mobile usage.

Avoid blocking the UI thread during:

- compression
- encryption
- decompression
- decryption
- serialization

Use asynchronous/background processing where appropriate.

Show processing state to the user.

---

# 60. Deliverables

After implementation, provide:

### Patient App

```text
1. Patient QR screen
2. Five offline QR screens/cards
3. QR generation engine
4. Visit rotation
5. Local demo records
6. QR diagnostics
```

### Doctor App

```text
1. QR scanner
2. Patient QR handler
3. Offline visit extractor
4. Visit viewer
5. Error handling
6. Local demo repository
```

### Shared/Protocol

```text
1. HRX v1 specification
2. Patient packet schema
3. Visit packet schema
4. Serialization implementation
5. Compression implementation
6. Encryption implementation
7. Integrity/signature implementation
8. Encoder
9. Decoder
10. Validator
```

### Tests

```text
1. Round-trip tests
2. Security/tamper tests
3. Capacity tests
4. Rotation tests
5. Offline tests
```

---

# 61. Implementation Instructions to Antigravity

Before coding:

### STEP 1

Inspect the complete existing project structure.

### STEP 2

Identify:

- Patient App entry point
- Doctor App entry point
- current navigation
- current models
- local storage
- package manager
- platform targets
- existing QR/camera packages

### STEP 3

Do not ask me to manually create files that you can create yourself.

### STEP 4

Implement the QR system incrementally.

First:

```text
Data Models
```

Then:

```text
HRX Protocol
```

Then:

```text
Serialization
```

Then:

```text
Compression
```

Then:

```text
Encryption
```

Then:

```text
Integrity/Signature
```

Then:

```text
QR Generation
```

Then:

```text
QR Scanner
```

Then:

```text
QR Extraction
```

Then:

```text
UI Integration
```

Then:

```text
Automated Tests
```

### STEP 5

After every major module, run the relevant tests.

### STEP 6

Do not move forward while basic encode/decode tests are failing.

---

# 62. Final End-to-End Requirement

The final Phase 1 system must demonstrate this exact flow:

```text
                    PATIENT APP

                  Demo Patient
                       |
                 +-----+-----+
                 |           |
             Patient QR   Visit Records
                             |
              +--------------+--------------+
              |       |       |       |      |
             V1      V2      V3      V4     V5
              |       |       |       |      |
             QR      QR      QR      QR     QR
              |       |       |       |      |
              +-------+-------+-------+------+
                              |
                         PHYSICAL SCAN
                              |
                              v

                     DOCTOR APP

                       Scanner
                          |
                    Detect HRX QR
                          |
              +-----------+-----------+
              |                       |
          PATIENT QR              VISIT QR
              |                       |
       Extract patient_ref       Parse packet
              |                       |
       Local demo lookup          Verify
              |                       |
       Patient information       Decrypt
                                      |
                                  Decompress
                                      |
                                  Deserialize
                                      |
                                  Validate
                                      |
                                      v
                                Visit Viewer
```

Everything above must work **without a database and without internet access** for the offline visit flow.

---

# 63. Definition of Done

The feature is considered complete only when:

- Patient App generates a valid Patient QR.
- Patient App generates five valid Visit QRs.
- Visit data is compacted before QR generation.
- Visit data is compressed before encryption.
- Visit data is encrypted.
- Visit data has integrity protection.
- QR payload size is measured.
- Oversized records are rejected safely.
- Doctor App scans Patient QR.
- Doctor App identifies QR type.
- Doctor App scans Visit QR.
- Doctor App extracts the encrypted payload.
- Doctor App verifies integrity.
- Doctor App decrypts it.
- Doctor App decompresses it.
- Doctor App reconstructs the original visit object.
- Doctor App displays the reconstructed visit.
- All of this works without internet for Visit QRs.
- Five-visit rotation works.
- Round-trip tests pass.
- Tamper tests pass.
- Wrong-key tests pass.
- Corrupt-payload tests pass.
- Unsupported-version tests pass.
- No medical data or cryptographic secrets are leaked through logs.
- The implementation does not require the future database to function.
- Future database integration can be added through repository/API abstractions without changing the HRX QR protocol.

---

# 64. Final Instruction

Do not treat this as a mock UI-only feature.

Implement the **actual functional QR pipeline**:

```text
STRUCTURED MEDICAL DATA
        ↓
SERIALIZATION
        ↓
COMPRESSION
        ↓
ENCRYPTION
        ↓
INTEGRITY PROTECTION
        ↓
QR GENERATION
        ↓
CAMERA SCAN
        ↓
QR DECODING
        ↓
PACKET VALIDATION
        ↓
INTEGRITY VERIFICATION
        ↓
DECRYPTION
        ↓
DECOMPRESSION
        ↓
DESERIALIZATION
        ↓
SCHEMA VALIDATION
        ↓
ORIGINAL MEDICAL RECORD
```

The Phase 1 implementation must be completely functional using local/demo data.

Do not implement backend/database integration yet.

Keep the entire QR system modular and production-oriented so that the database, authentication, consent, synchronization, and ABDM/FHIR interoperability layers can be connected later.