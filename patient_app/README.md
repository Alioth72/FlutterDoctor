# FlutterDoctor - Patient Portal

A Flutter healthcare application featuring patient onboarding, doctor appointment booking with dynamic calendar schedules, and digital OPD receipt token generation.

## 🚀 Features

- **Patient Onboarding & Profile**: Form validation (Name, Age, Gender, 10-digit Phone Number) with local persistence via `SharedPreferences`.
- **Doctor Directory & Schedules**: Doctors across multiple specialties (General Physician, Cardiologist, Pediatrician, Orthopedic, etc.) with real-time weekday calendar availability.
- **Appointment Booking**: Select appointment date and available OPD time slots with symptom reason notes.
- **Digital Receipt / OPD Token Slip**: Instant confirmation receipt with unique Booking ID, Queue Token Number, hospital location, and guidelines.
- **My Appointments Dashboard**: View, manage, and re-open booked appointment slips anytime.

## 🛠️ Tech Stack & State Management

- **Framework**: Flutter (Material 3)
- **State Management**: `provider` (`HealthProfileProvider`, `AppointmentProvider`)
- **Local Storage**: `shared_preferences`

## 📦 Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Alioth72/FlutterDoctor.git
   cd FlutterDoctor
   git checkout Mayank
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run
   ```

4. **Run tests**:
   ```bash
   flutter test
   ```
