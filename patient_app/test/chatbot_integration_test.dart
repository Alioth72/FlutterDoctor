import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sih_project/features/chatbot/chatbot_storage.dart';
import 'package:sih_project/features/chatbot/chatbot_retrieval.dart';
import 'package:sih_project/features/chatbot/chatbot_orchestrator.dart';

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

    test('LocalVectorStoreRepository initializes and manages chunks', () async {
      final store = LocalVectorStoreRepository();
      await store.init();

      expect(await store.count(), equals(0));

      final results = await store.similaritySearch([0.1, 0.2, 0.3], 3);
      expect(results.isEmpty, isTrue);

      await store.close();
    });
  });
}
