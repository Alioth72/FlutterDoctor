# 🏥 Healthcare AI Chatbot — Integration Guide

Welcome to the Healthcare Chatbot module! This module provides a clinical-grade, offline-first AI health assistant with built-in **Allergy Guards**, **Prescription Explainers**, **Ward Guidance**, and **EHR Context Integration**.

Follow this 3-step guide to integrate this chatbot into your **Patient App** in under 2 minutes.

---

## 🚀 Quick Integration (In Under 2 Minutes)

### Step 1: Copy Files to Your Patient App
1. Copy the `lib/features/chatbot/` folder into your Patient App's `lib/features/` directory.
2. Copy `assets/data/medical_knowledge_embeddings.json` into your Patient App's `assets/data/` folder.

---

### Step 2: Add Dependencies to `pubspec.yaml`
Ensure your Patient App's `pubspec.yaml` includes:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Local storage & offline vector engine
  objectbox: ^4.1.0
  objectbox_flutter_libs: ^4.1.0
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  path_provider: ^2.1.6
  path: ^1.9.1

flutter:
  uses-material-design: true
  assets:
    - assets/data/   # MedQuAD offline knowledge embeddings
```
Run `flutter pub get` after saving.

---

### Step 3: Connect to Your "AI Assistance" Button
On your Patient App's Dashboard, Home Screen, or Profile screen, find your **"AI Assistance"** button and add this single line of navigation:

```dart
// 1. Import the chatbot UI
import 'features/chatbot/chatbot_ui.dart';

// 2. On your AI Assistance Button's onPressed / onTap:
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatbotPage(), // 🌟 Single line plug-and-play!
      ),
    );
  },
  child: const Text("AI Assistance"),
)
```

> **That's it!** The chatbot will launch with a loading indicator, initialize all background engines, and present the chat interface with pre-loaded mock patient data (*Rajesh Sharma*). The back button (`←`) will return the patient to your Home screen.

---

## 🔌 Connecting Azure Database / Backend API (When Ready)

Right now, the chatbot defaults to `MockPatientRepository()` (*Rajesh Sharma, Penicillin allergy, Ward 304, Paracetamol, Cetirizine*).

When your Azure Functions / PostgreSQL backend is deployed or running locally, simply pass the `AzureFunctionPatientRepository`:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ChatbotPage(
      // Connects live to your friend's Azure Functions endpoint:
      patientRepository: AzureFunctionPatientRepository(
        baseUrl: 'http://10.0.2.2:7071/api', // Local Android Emulator
        // or 'https://<your-app>.azurewebsites.net/api', // Deployed Azure
      ),
      patientId: loggedInUserId, // Optional: defaults to active user
    ),
  ),
);
```

---

## 🛡️ Built-In Features & How to Test

| Feature | How It Works | How to Test in Chat |
| :--- | :--- | :--- |
| **Allergy Guard** | Checks any requested drug against patient allergies. | Ask: *"Can I take Amoxicillin for my cold?"* $\rightarrow$ Gives prominent **Penicillin Allergy Warning**! |
| **Prescription Explainer** | Explains exact dosage, food rules, and timings as prescribed by the doctor. | Ask: *"When should I take Cetirizine?"* $\rightarrow$ Explains 10mg, **0-0-1 before sleep**, 5 days! |
| **Ward / In-Patient Guide** | Guides the patient about their room and doctor. | Ask: *"Where is my room or appointment?"* $\rightarrow$ References **IPD Ward 304, Bed 12** and **Dr. Rajesh V. Sharma**! |
| **Generic Medical Q&A** | Answers general disease questions using MedQuAD knowledge. | Ask: *"What are the symptoms of dengue?"* $\rightarrow$ Gives verified clinical bullet points! |
| **Clean Markdown UI** | Renders bold titles and bullets cleanly with zero asterisks (`**`). | Automatic on all responses. |

---

## 📁 Architecture Overview

```
lib/features/chatbot/
├── domain/
│   ├── models/
│   │   ├── patient_profile.dart       # Patient EHR model (Allergies, Rx, Vitals, Ward)
│   │   └── search_result.dart         # Vector search chunks
│   ├── repositories/
│   │   └── patient_repository.dart    # Abstract contract for Patient EHR
│   └── services/
│       ├── chat_orchestrator.dart     # Central query coordinator
│       └── prompt_builder.dart        # Clinical prompt assembly & guardrails
├── data/
│   └── repositories/
│       ├── mock_patient_repository.dart            # In-memory testing repository
│       └── azure_function_patient_repository.dart  # Native HTTP Azure Functions connector
└── presentation/
    ├── screens/
    │   ├── chatbot_page.dart          # Plug-and-play entry screen
    │   └── chat_screen.dart           # Primary chat UI with patient header card
    └── widgets/
        └── formatted_message_view.dart # Custom markdown layout & alert styling
```
