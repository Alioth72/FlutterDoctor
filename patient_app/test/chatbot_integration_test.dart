import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/features/chatbot/chatbot_storage.dart';
import 'package:sih_project/features/chatbot/chatbot_retrieval.dart';
import 'package:sih_project/features/chatbot/chatbot_orchestrator.dart';
import 'package:sih_project/features/chatbot/chatbot_llm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chatbot Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PreferencesChatStorageRepository persists, queries, and streams messages', () async {
      final storage = PreferencesChatStorageRepository();
      await storage.init();

      final msg1 = ChatMessage(
        conversationId: 'test_conv',
        role: MessageRole.user,
        text: 'Hello, what should I take for fever?',
        timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      final saved1 = await storage.saveMessage(msg1);
      expect(saved1.id, greaterThan(0));

      final msg2 = ChatMessage(
        conversationId: 'test_conv',
        role: MessageRole.bot,
        text: 'Paracetamol 650mg is recommended.',
        timestamp: DateTime.now(),
      );

      await storage.saveMessage(msg2);

      final messages = await storage.getMessagesForConversation('test_conv');
      expect(messages.length, equals(2));
      expect(messages[0].role, equals(MessageRole.user));
      expect(messages[1].role, equals(MessageRole.bot));

      // Test streaming
      final streamMessages = await storage.watchMessagesForConversation('test_conv').first;
      expect(streamMessages.length, equals(2));

      // Test deletion
      final deleted = await storage.deleteConversation('test_conv');
      expect(deleted, equals(2));

      final afterDelete = await storage.getMessagesForConversation('test_conv');
      expect(afterDelete.isEmpty, isTrue);

      await storage.close();
    });

    test('PromptBuilder injects EHR context, allergies, and prescriptions', () {
      const builder = PromptBuilder();
      final profile = PatientProfile.demoRajeshSharma();

      final prompt = builder.buildPrompt(
        query: 'Can I take Amoxicillin?',
        chunks: [],
        patientProfile: profile,
      );

      expect(prompt.contains('Rajesh Sharma'), isTrue);
      expect(prompt.contains('CRITICAL ALLERGIES: Penicillin'), isTrue);
      expect(prompt.contains('Paracetamol 650mg'), isTrue);
      expect(prompt.contains('Cetirizine 10mg'), isTrue);
      expect(prompt.contains('ALLERGY GUARD'), isTrue);
    });

    test('PromptBuilder injects Ashwini app features and navigation guide', () {
      const builder = PromptBuilder();
      final prompt = builder.buildPrompt(
        query: 'How do I scan prescriptions for Jan Aushadhi generic savings?',
        chunks: [],
      );

      expect(prompt.contains('ASHWINI HEALTHCARE PORTAL & APP GUIDE'), isTrue);
      expect(prompt.contains('Jan Aushadhi'), isTrue);
      expect(prompt.contains('60% to 80%'), isTrue);
      expect(prompt.contains('Face Vitals'), isTrue);
      expect(prompt.contains('ASHA Worker'), isTrue);
      expect(prompt.contains('Emergency SOS Protocol'), isTrue);
      expect(prompt.contains('All 22 Scheduled Indian Languages'), isTrue);
    });

    test('ExtractiveOfflineLlmClient answers app questions when offline', () async {
      const client = ExtractiveOfflineLlmClient();

      final rxResponse = await client.generateResponse(
        prompt: 'How to scan prescription?',
        contextChunks: const [],
      );
      expect(rxResponse.text, contains('Jan Aushadhi'));
      expect(rxResponse.text, contains('60% to 80%'));

      final sosResponse = await client.generateResponse(
        prompt: 'How to use emergency SOS ambulance?',
        contextChunks: const [],
      );
      expect(sosResponse.text, contains('108 Ambulance / 112'));
      expect(sosResponse.text, contains('GPS location'));

      final vitalsResponse = await client.generateResponse(
        prompt: 'How to use face vitals scanner?',
        contextChunks: const [],
      );
      expect(vitalsResponse.text, contains('Heart Rate'));
      expect(vitalsResponse.text, contains('SpO2'));

      final ashaResponse = await client.generateResponse(
        prompt: 'How can I request an ASHA worker home visit?',
        contextChunks: const [],
      );
      expect(ashaResponse.text, contains('ASHA'));
      expect(ashaResponse.text, contains('Home Visit'));
    });
  });
}
