import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/features/chatbot/data/services/extractive_offline_llm_client.dart';
import 'package:sih_project/features/chatbot/domain/models/search_result.dart';

void main() {
  group('ExtractiveOfflineLlmClient Multilingual Tests', () {
    late ExtractiveOfflineLlmClient client;

    setUp(() {
      client = const ExtractiveOfflineLlmClient();
    });

    test('Answers fever query in Bengali when language directive is Bengali', () async {
      const prompt = '''
The user is using the Ashwini Patient Portal app.
--- LANGUAGE DIRECTIVE ---
The user chosen language is Bengali (bn).
You MUST answer the entire response fluently in Bengali (bn) script.
--- User Query ---
I have fever help me
--- Medical Disclaimer ---
This information is for educational and advisory reference only.
''';

      final response = await client.generateResponse(
        prompt: prompt,
        contextChunks: const <SearchResult>[],
      );

      expect(response.text, isNotEmpty);
      // Must contain Bengali characters for fever guidance, NOT English text
      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(response.text), isTrue,
          reason: 'Expected Bengali response for Bengali language setting');
      expect(response.text.contains('জ্বর'), isTrue);
      expect(response.text.contains('প্যারাসিটামল'), isTrue);
    });

    test('Answers cough and cold query in Bengali when language directive is Bengali', () async {
      const prompt = '''
--- LANGUAGE DIRECTIVE ---
The user chosen language is Bengali (bn).
You MUST answer the entire response fluently in Bengali (bn) script.
--- User Query ---
I have cold and cough
--- Medical Disclaimer ---
''';

      final response = await client.generateResponse(
        prompt: prompt,
        contextChunks: const <SearchResult>[],
      );

      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(response.text), isTrue);
      expect(response.text.contains('কাশি') || response.text.contains('সর্দি'), isTrue);
    });

    test('Answers allergy alert in Bengali when penicillin allergy is present', () async {
      const prompt = '''
CRITICAL ALLERGIES: Penicillin
--- LANGUAGE DIRECTIVE ---
The user chosen language is Bengali (bn).
--- User Query ---
Can I take Amoxicillin?
--- Medical Disclaimer ---
''';

      final response = await client.generateResponse(
        prompt: prompt,
        contextChunks: const <SearchResult>[],
      );

      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(response.text), isTrue);
      expect(response.text.contains('অ্যালার্জি'), isTrue);
    });

    test('Answers fever query in Hindi when language directive is Hindi', () async {
      const prompt = '''
--- LANGUAGE DIRECTIVE ---
The user chosen language is Hindi (hi).
--- User Query ---
I have fever
--- Medical Disclaimer ---
''';

      final response = await client.generateResponse(
        prompt: prompt,
        contextChunks: const <SearchResult>[],
      );

      expect(RegExp(r'[\u0900-\u097F]').hasMatch(response.text), isTrue);
      expect(response.text.contains('बुखार'), isTrue);
    });

    test('Answers fever query in Tamil when language directive is Tamil', () async {
      const prompt = '''
--- LANGUAGE DIRECTIVE ---
The user chosen language is Tamil (ta).
--- User Query ---
I have fever
--- Medical Disclaimer ---
''';

      final response = await client.generateResponse(
        prompt: prompt,
        contextChunks: const <SearchResult>[],
      );

      expect(RegExp(r'[\u0B80-\u0BFF]').hasMatch(response.text), isTrue);
      expect(response.text.contains('காய்ச்சல்'), isTrue);
    });

    test('Strictly answers in English when English is selected, ignoring app guide mentions of Bengali', () async {
      // Simulate prompt with full app guide mentioning all Indian languages
      const prompt = '''
--- ASHWINI HEALTHCARE PORTAL & APP GUIDE (App Features & Navigation) ---
• Voice Input: Tap the microphone button in the chat input bar to speak queries in Hindi, Bengali, Tamil, Telugu, English.
• Multilingual Language Switcher: Instantly switches the entire app into Hindi, Bengali, Telugu, Marathi, Tamil, Urdu.
--- Verified Medical Context ---
No specific reference chunks found in local knowledge base.
--- LANGUAGE DIRECTIVE ---
SELECTED_LANGUAGE_CODE: en
The user chosen language is English (en).
You MUST answer the entire response fluently in English (en).
--- User Query ---
I have a general health question
--- Medical Disclaimer ---
This information is for educational and advisory reference only.
''';

      final response = await client.generateResponse(
        prompt: prompt,
        contextChunks: const <SearchResult>[],
      );

      expect(response.text, isNotEmpty);
      // MUST NOT contain Bengali script
      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(response.text), isFalse,
          reason: 'English query must never produce Bengali text');
      // MUST contain English welcome or health guidance
      expect(response.text.contains('Ashwini Healthcare Assistant') || response.text.contains('Wellness'), isTrue);
    });
  });
}
