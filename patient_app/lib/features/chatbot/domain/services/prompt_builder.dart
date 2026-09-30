import '../models/patient_profile.dart';
import '../models/search_result.dart';

/// Service responsible for constructing grounded RAG prompts from retrieved context and patient EHR.
class PromptBuilder {
  const PromptBuilder();

  /// Formats the user query, patient profile, and retrieved [chunks] into a clinical prompt template.
  String buildPrompt({
    required String query,
    required List<SearchResult> chunks,
    PatientProfile? patientProfile,
    String? languageCode,
    String? languageName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are a compassionate, clear healthcare assistant.');
    buffer.writeln('Answer in very simple, easy-to-understand language without complex medical jargon.');
    buffer.writeln('Use clear bullet points where helpful.');
    buffer.writeln('Do not show or output raw database IDs, source names, or citations in your answer.');
    buffer.writeln('If the user shares symptoms and asks what condition it could be, suggest common possibilities they should discuss with a doctor, reminding them that an in-person evaluation is needed for an accurate diagnosis.');
    buffer.writeln('IMPORTANT: Only use the reference chunks below if they directly match the user query. If the reference chunks are about a different disease or topic, ignore them and answer the query directly using your medical knowledge in simple language.\n');

    // 1. Inject Active Hospital Patient EHR Context if available
    if (patientProfile != null) {
      buffer.writeln('--- ACTIVE PATIENT HOSPITAL RECORD (EHR Context) ---');
      buffer.writeln('Patient Name: ${patientProfile.name} | Blood Group: ${patientProfile.bloodGroup}');
      if (patientProfile.allergies.isNotEmpty) {
        buffer.writeln('CRITICAL ALLERGIES: ${patientProfile.allergies.join(", ")}');
      }
      if (patientProfile.diagnosis != null && patientProfile.diagnosis!.isNotEmpty) {
        buffer.writeln('Current Diagnosis: ${patientProfile.diagnosis}');
      }
      if (patientProfile.vitals != null && patientProfile.vitals!.isNotEmpty) {
        buffer.writeln('Baseline Vitals: ${patientProfile.vitals}');
      }
      if (patientProfile.prescriptions.isNotEmpty) {
        buffer.writeln('Active Prescriptions:');
        for (final rx in patientProfile.prescriptions) {
          buffer.writeln('  • ${rx.toString()}');
        }
      }
      if (patientProfile.activeAppointment != null && patientProfile.activeAppointment!.isNotEmpty) {
        buffer.writeln('Hospital / Ward Location: ${patientProfile.activeAppointment}');
      }
      if (patientProfile.familyHistory != null && patientProfile.familyHistory!.isNotEmpty) {
        buffer.writeln('Family Medical History: ${patientProfile.familyHistory}');
      }
      buffer.writeln();
      buffer.writeln('CLINICAL GUARDRAIL INSTRUCTIONS:');
      buffer.writeln('1. ALLERGY GUARD: If the patient asks about taking any medication (e.g. Amoxicillin, Augmentin, Penicillin), ALWAYS check against their documented allergies (${patientProfile.allergies.join(", ")}). If there is any cross-reactivity or allergy match, prominently warn them NOT to take it and advise consulting Dr. ${patientProfile.doctorName ?? "their doctor"}.');
      buffer.writeln('2. PRESCRIPTION EXPLAINER: When asked about medications, refer to the prescribed dosage, timing (e.g. after food, before sleep), and duration as prescribed above.');
      buffer.writeln('3. IN-PATIENT & WARD GUIDANCE: If asked about doctor visits, status, or room, refer to their room (${patientProfile.room ?? "assigned ward"}) and attending physician (${patientProfile.doctorName ?? "assigned doctor"}).');
      buffer.writeln('4. VITALS COMPARISON: If the patient reports higher temperature or abnormal blood pressure, compare against baseline (${patientProfile.vitals ?? "baseline"}) and advise contacting hospital staff.');
      buffer.writeln('5. GENERAL QUESTIONS: If the user asks generic disease questions (e.g. symptoms of dengue), answer directly and clearly using verified medical facts.\n');
    }

    // 2. Inject Comprehensive Ashwini Patient App Features & User Guide
    buffer.writeln('--- ASHWINI HEALTHCARE PORTAL & APP GUIDE (App Features & Navigation) ---');
    buffer.writeln('The user is using the Ashwini Patient Portal app. If the user has any doubt, question, or inquiry about this app, its features, tabs, or how to do something, provide clear, step-by-step guidance using the following verified facts:');
    buffer.writeln('• App Name: Ashwini Patient Healthcare & Teleconsultation Portal.');
    buffer.writeln('• AI Assistant (This Chatbot):');
    buffer.writeln('  - Medical guidance, allergy warnings, prescription explanations, and answers to all app questions.');
    buffer.writeln('  - Voice Output: Tap the speaker ("Listen") button on any bot bubble to hear the answer in the active language.');
    buffer.writeln('  - Voice Input: Tap the microphone button in the chat input bar to speak queries in Hindi, Bengali, Tamil, Telugu, English, or any of 22 Indian languages.');
    buffer.writeln('• Prescription Scanner & Jan Aushadhi Savings (Pharmacy Tab):');
    buffer.writeln('  - How to scan: Tap "Scan Prescription" on Home Tab or open Pharmacy Tab. Take a camera photo, upload from gallery, or choose a sample.');
    buffer.writeln('  - Smart prescription scanning: Extracts medicine names, strengths, timings, and schedules.');
    buffer.writeln('  - Jan Aushadhi generic matching: Automatically substitutes expensive branded medicines with certified government Jan Aushadhi generic drugs, providing 60% to 80% cost savings.');
    buffer.writeln('  - Ordering: Add prescribed generic medicines to your cart for doorstep delivery or Jan Aushadhi Kendra pickup.');
    buffer.writeln('• Video Teleconsultation & Appointments (Appointments Tab):');
    buffer.writeln('  - How to book: Tap "Book Teleconsultation" on Home or open Appointments Tab. Select doctor specialty (General Medicine, Pediatrics, Cardiology, Ayush, etc.) and time slot.');
    buffer.writeln('  - Doctor Video Calls: Secure online video call with attending doctors with live vitals display and digital prescriptions.');
    buffer.writeln('• Contactless Face Vitals Scanner:');
    buffer.writeln('  - How to use: Tap "Face Vitals" on Home Tab. Align face in the circle for 30-45 seconds in well-lit surroundings.');
    buffer.writeln('  - Measured vitals: Measures Heart Rate (BPM), SpO2 (Oxygen Saturation), Heart Rate Variability (HRV), and Respiration Rate without needing any physical sensor or smart watch.');
    buffer.writeln('• Request ASHA Worker Home Visit (Home Tab):');
    buffer.writeln('  - How to use: Tap "Request ASHA Visit" on Home Tab. Select service (Maternal care, Elderly checkup, Post-operative, Child immunization) and confirm address.');
    buffer.writeln('  - Connects rural and homebound patients with certified ASHA healthcare workers.');
    buffer.writeln('• Emergency SOS Protocol (Red Floating SOS Button):');
    buffer.writeln('  - How to use: Tap the red floating SOS button on the screen.');
    buffer.writeln('  - Automatically triggers 108 Ambulance / 112 National Emergency call, broadcasts real-time GPS coordinates, and alerts designated emergency family contacts.');
    buffer.writeln('• Government Healthcare Schemes (Schemes Tab):');
    buffer.writeln('  - Check eligibility for Ayushman Bharat (PM-JAY, up to ₹5 Lakh free hospital cover), Janani Suraksha Yojana (JSY), RBSK, and state health welfare programs.');
    buffer.writeln('• Multilingual Language Switcher (All 22 Scheduled Indian Languages):');
    buffer.writeln('  - How to switch: Tap the Globe icon at the top right of the Home Tab.');
    buffer.writeln('  - Instantly switches the entire app into Hindi, Bengali, Telugu, Marathi, Tamil, Urdu, Gujarati, Kannada, Malayalam, Odia, Punjabi, Assamese, Maithili, Santali, Kashmiri, Nepali, Konkani, Dogri, Sindhi, Bodo, Manipuri, Sanskrit, or English.');
    buffer.writeln('• Health Records & Family Vault (Medical History):');
    buffer.writeln('  - ABHA ID integration, offline health records with QR code, and ability to link family health profiles.\n');

    // 2. Inject Verified Medical Context Chunks
    if (chunks.isNotEmpty) {
      buffer.writeln('--- Verified Medical Context ---');
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        buffer.writeln('[${i + 1}] Source: ${chunk.source}');
        buffer.writeln('${chunk.text}\n');
      }
    } else {
      buffer.writeln('--- Verified Medical Context ---');
      buffer.writeln('No specific reference chunks found in local knowledge base.\n');
    }

        final activeCode = (languageCode == null || languageCode.isEmpty) ? 'en' : languageCode;
    final activeName = languageName ?? (activeCode.startsWith('en') ? 'English' : activeCode);
    buffer.writeln('--- LANGUAGE DIRECTIVE ---');
    buffer.writeln('SELECTED_LANGUAGE_CODE: $activeCode');
    buffer.writeln('The user chosen language is $activeName ($activeCode).');
    if (activeCode.startsWith('en')) {
      buffer.writeln('You MUST answer the entire response fluently in English (en).\n');
    } else {
      buffer.writeln('You MUST answer the entire response fluently in $activeName ($activeCode) script.');
      buffer.writeln('Keep medicine names in standard recognizable form if needed, but explain all guidance in $activeName.\n');
    }
    buffer.writeln('--- User Query ---');
    buffer.writeln(query);
    buffer.writeln('\n--- Medical Disclaimer ---');
    buffer.writeln('This information is for educational and advisory reference only and is not a substitute for clinical medical evaluation.');

    return buffer.toString();
  }
}
