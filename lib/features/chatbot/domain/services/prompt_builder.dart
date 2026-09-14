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

    buffer.writeln('--- User Query ---');
    buffer.writeln(query);
    buffer.writeln('\n--- Medical Disclaimer ---');
    buffer.writeln('This information is for educational and advisory reference only and is not a substitute for clinical medical evaluation.');

    return buffer.toString();
  }
}
