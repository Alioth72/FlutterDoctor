import '../../domain/models/search_result.dart';
import '../../domain/services/llm_client.dart';

/// Lightweight offline synthesizer for offline knowledge.
class ExtractiveOfflineLlmClient implements LlmClient {
  const ExtractiveOfflineLlmClient();

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Check if user is asking about the Ashwini App features or navigation
    final appGuideAnswer = _checkAppQuery(prompt);
    if (appGuideAnswer != null) {
      stopwatch.stop();
      return LlmResponse(
        text: appGuideAnswer,
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    if (contextChunks.isEmpty) {
      return LlmResponse(
        text: '📋 **Offline Medical Knowledge**\n\n'
            'No matching medical records were found in the local offline database.\n'
            'Please check your internet connection for online AI assistance, or consult a healthcare professional.',
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 **Verified Medical Information (Offline Mode)**\n');

    for (int i = 0; i < contextChunks.length; i++) {
      final chunk = contextChunks[i];
      buffer.writeln('### Finding ${i + 1}');
      buffer.writeln(_formatParagraph(chunk.text));
      buffer.writeln('\n📖 **Source**: ${chunk.source}\n');
    }

    buffer.writeln('---');
    buffer.writeln('⚠️ *Disclaimer: For educational reference only. Consult a doctor for medical diagnosis.*');

    stopwatch.stop();

    return LlmResponse(
      text: buffer.toString().trim(),
      branch: LlmBranchType.offline,
      latency: stopwatch.elapsed,
    );
  }

  String _formatParagraph(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.length <= 2) {
      return text.trim();
    }

    final buffer = StringBuffer();
    for (final sentence in sentences) {
      buffer.writeln('• ${sentence.trim()}');
    }
    return buffer.toString().trim();
  }

  String? _checkAppQuery(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('scan') && (lower.contains('prescription') || lower.contains('medicine') || lower.contains('rx'))) {
      return '📸 **How to Scan Prescriptions & Save Money (Jan Aushadhi)**:\n\n'
          '1. Go to the **Home Tab** and tap **"Scan Prescription"**, or switch to the **Pharmacy Tab**.\n'
          '2. Take a photo of your doctor prescription or upload one from your gallery.\n'
          '3. Our AI Vision OCR reads medicine names and matches them with government **Jan Aushadhi generic equivalents**, saving you **60% to 80%** on medicine costs!\n'
          '4. You can add the prescribed generic medicines directly to your cart for doorstep delivery or local store pickup.';
    }

    if (lower.contains('face vitals') || lower.contains('rppg') || (lower.contains('vitals') && lower.contains('camera'))) {
      return '💓 **How to Use Contactless Face Vitals (rPPG)**:\n\n'
          '1. On the **Home Tab**, tap the **"Face Vitals"** quick action card.\n'
          '2. Position your face inside the camera oval in a well-lit area without moving.\n'
          '3. Hold steady for 30 to 45 seconds while the optical sensor measures skin micro-pulsations.\n'
          '4. It accurately estimates your **Heart Rate (BPM)**, **SpO2 (Blood Oxygen)**, **HRV**, and **Breathing Rate** without wearing any smart device!';
    }

    if (lower.contains('teleconsult') || lower.contains('video call') || (lower.contains('book') && lower.contains('appointment'))) {
      return '👨‍⚕️ **How to Book a Doctor Teleconsultation**:\n\n'
          '1. Tap **"Book Teleconsultation"** on the Home Tab or switch to the **Appointments Tab**.\n'
          '2. Choose the clinical specialty (General Medicine, Cardiology, Pediatrics, Ayush, etc.).\n'
          '3. Select an available date and time slot with the doctor.\n'
          '4. At appointment time, launch the high-definition video call with live vitals display and receive your digital prescription directly in the app.';
    }

    if (lower.contains('asha') || lower.contains('home visit')) {
      return '🏡 **How to Request an ASHA Worker Home Visit**:\n\n'
          '1. Tap **"Request ASHA Visit"** on the **Home Tab**.\n'
          '2. Select the care category (Maternal/Pregnancy, Infant checkup, Elderly care, or Post-surgery recovery).\n'
          '3. Confirm your home address and contact details.\n'
          '4. A local accredited ASHA healthcare worker will be assigned to visit your home for health monitoring, immunization, or medication delivery.';
    }

    if (lower.contains('sos') || lower.contains('emergency') || lower.contains('ambulance')) {
      return '🚨 **Emergency SOS Protocol (108 / 112)**:\n\n'
          '• Tap the **red floating SOS button** at the bottom right of the screen.\n'
          '• It immediately triggers an emergency alert to local emergency services (**108 Ambulance / 112 National Emergency**).\n'
          '• It automatically broadcasts your **live GPS location** to nearest medical facilities and notifies your designated emergency contacts.';
    }

    if (lower.contains('language') || lower.contains('bhasha') || lower.contains('hindi') || lower.contains('tamil')) {
      return '🌐 **How to Change Language (22 Indian Languages)**:\n\n'
          '1. Tap the **Globe icon** at the top-right corner of the Home Tab.\n'
          '2. Choose from any of the **22 Scheduled Indian Languages** (Hindi, Tamil, Telugu, Bengali, Marathi, Gujarati, Punjabi, Kannada, Malayalam, Odia, Assamese, Urdu, etc.) or English.\n'
          '3. The entire app, buttons, prescriptions, and voice assistant switch immediately!';
    }

    if (lower.contains('what is this app') || lower.contains('about this app') || lower.contains('ashwini') || lower.contains('features')) {
      return '🏥 **About Ashwini Healthcare Portal**:\n\n'
          'Ashwini is a comprehensive digital health portal designed for rural & urban patients across India:\n'
          '• **Instant AI Assistant**: Multilingual clinical guidance with Sarvam voice.\n'
          '• **Prescription Scanner**: 60-80% savings via Jan Aushadhi generic matching.\n'
          '• **Contactless Face Vitals (rPPG)**: Check HR & SpO2 via phone camera.\n'
          '• **Video Teleconsultation**: Connect with doctors via secure WebRTC video.\n'
          '• **ASHA Home Visits**: Request community healthcare visits to your home.\n'
          '• **Emergency SOS**: 1-tap 108/112 ambulance dispatch with GPS broadcast.\n'
          '• **Government Health Schemes**: Check eligibility for Ayushman Bharat (PM-JAY).\n'
          '• **22 Indian Languages**: Complete native localization and voice support.';
    }

    return null;
  }
}
