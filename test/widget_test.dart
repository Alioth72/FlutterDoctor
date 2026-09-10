import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatbot_healthcare/features/chatbot/chatbot_embedding.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_llm.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_orchestrator.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_storage.dart';
import 'package:chatbot_healthcare/main.dart';

class InMemoryChatStorageRepository implements ChatStorageRepository {
  final List<ChatMessage> _messages = [];
  final StreamController<List<ChatMessage>> _controller =
      StreamController<List<ChatMessage>>.broadcast();

  @override
  Future<void> init({String? directory}) async {}

  @override
  Future<ChatMessage> saveMessage(ChatMessage message) async {
    final msg = message.id == 0 || message.id == -1
        ? message.copyWith(id: _messages.length + 1)
        : message;
    _messages.add(msg);
    _controller.add(List.from(_messages));
    return msg;
  }

  @override
  Future<List<ChatMessage>> saveMessages(List<ChatMessage> messages) async {
    for (final m in messages) {
      await saveMessage(m);
    }
    return messages;
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(String conversationId) async {
    return _messages.where((m) => m.conversationId == conversationId).toList();
  }

  @override
  Future<ChatMessage?> getMessageById(int id) async {
    return _messages.firstWhere((m) => m.id == id);
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx != -1) {
      _messages[idx] = message;
      _controller.add(List.from(_messages));
    }
  }

  @override
  Future<bool> deleteMessage(int id) async {
    _messages.removeWhere((m) => m.id == id);
    _controller.add(List.from(_messages));
    return true;
  }

  @override
  Future<int> deleteConversation(String conversationId) async {
    final count = _messages.where((m) => m.conversationId == conversationId).length;
    _messages.removeWhere((m) => m.conversationId == conversationId);
    _controller.add(List.from(_messages));
    return count;
  }

  @override
  Future<void> clearAll() async {
    _messages.clear();
    _controller.add([]);
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(String conversationId) {
    return _controller.stream;
  }

  @override
  Future<List<ChatMessage>> getUnsyncedMessages() async {
    return _messages.where((m) => !m.isSynced).toList();
  }

  @override
  Future<void> markAsSynced(List<int> messageIds) async {
    for (int i = 0; i < _messages.length; i++) {
      if (messageIds.contains(_messages[i].id)) {
        _messages[i] = _messages[i].copyWith(isSynced: true);
      }
    }
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

class FakeVectorStoreRepository implements VectorStoreRepository {
  @override
  Future<void> init({String? directory}) async {}

  @override
  Future<bool> ingestAssetIfEmpty({String? assetPath, String? rawJsonContent}) async => false;

  @override
  Future<List<SearchResult>> similaritySearch(List<double> queryEmbedding, int topK) async {
    return [
      const SearchResult(
        text: 'Anemia is characterized by a deficiency of red blood cells.',
        source: 'MedQuAD (001)',
        score: 0.95,
      ),
    ];
  }

  @override
  Future<int> count() async => 1;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> close() async {}
}

class FakeLlmClient implements LlmClient {
  FakeLlmClient({required this.responseText, required this.branch});

  final String responseText;
  final LlmBranchType branch;

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    return LlmResponse(
      text: responseText,
      branch: branch,
    );
  }
}

void main() {
  testWidgets('HealthcareChatApp renders ChatScreen with emergency banner and suggestions',
      (WidgetTester tester) async {
    final storageRepo = InMemoryChatStorageRepository();
    final vectorRepo = FakeVectorStoreRepository();
    final embeddingService = OnnxEmbeddingService();
    final connectivityService = MockConnectivityService(initialOnline: true);
    final cloudLlm = GeminiCloudLlmClient(apiKey: 'dummy_key');
    final offlineLlm = FakeLlmClient(
      responseText: 'Offline medical response',
      branch: LlmBranchType.offline,
    );

    final orchestrator = ChatOrchestrator(
      storageRepository: storageRepo,
      vectorStoreRepository: vectorRepo,
      embeddingService: embeddingService,
      connectivityService: connectivityService,
      offlineLlmClient: offlineLlm,
      cloudLlmClient: FakeLlmClient(
        responseText: 'Anemia causes fatigue and pale skin. Consult your doctor.',
        branch: LlmBranchType.online,
      ),
    );

    await tester.pumpWidget(
      HealthcareChatApp(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        cloudLlmClient: cloudLlm,
        offlineLlmClient: offlineLlm,
        orchestrator: orchestrator,
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Emergency Banner
    expect(find.text('MediAssist AI'), findsOneWidget);
    expect(find.textContaining('Emergency Advisory'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('What are symptoms of iron-deficiency anemia?'), findsOneWidget);

    // Verify Input Bar exists
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Tapping suggestion chip sends message and displays bot response',
      (WidgetTester tester) async {
    final storageRepo = InMemoryChatStorageRepository();
    final vectorRepo = FakeVectorStoreRepository();
    final embeddingService = OnnxEmbeddingService();
    await embeddingService.init();

    final connectivityService = MockConnectivityService(initialOnline: true);
    final cloudLlm = GeminiCloudLlmClient(apiKey: 'dummy_key');
    final offlineLlm = FakeLlmClient(
      responseText: 'Offline response',
      branch: LlmBranchType.offline,
    );

    final orchestrator = ChatOrchestrator(
      storageRepository: storageRepo,
      vectorStoreRepository: vectorRepo,
      embeddingService: embeddingService,
      connectivityService: connectivityService,
      offlineLlmClient: offlineLlm,
      cloudLlmClient: FakeLlmClient(
        responseText: 'Anemia causes fatigue and weakness.',
        branch: LlmBranchType.online,
      ),
    );

    await tester.pumpWidget(
      HealthcareChatApp(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        cloudLlmClient: cloudLlm,
        offlineLlmClient: offlineLlm,
        orchestrator: orchestrator,
      ),
    );

    await tester.pumpAndSettle();

    // Tap suggestion button
    final suggestionFinder = find.text('What are symptoms of iron-deficiency anemia?');
    expect(suggestionFinder, findsOneWidget);
    await tester.tap(suggestionFinder);

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify bot response appeared
    expect(find.textContaining('Anemia causes fatigue and weakness.'), findsOneWidget);
    expect(find.text('Gemini AI'), findsOneWidget);
  });

  testWidgets('ApiKeyDialog can be opened from action bar',
      (WidgetTester tester) async {
    final storageRepo = InMemoryChatStorageRepository();
    final vectorRepo = FakeVectorStoreRepository();
    final embeddingService = OnnxEmbeddingService();
    await embeddingService.init();

    final connectivityService = MockConnectivityService(initialOnline: true);
    final cloudLlm = GeminiCloudLlmClient(apiKey: 'dummy_key');
    final offlineLlm = FakeLlmClient(
      responseText: 'Offline response',
      branch: LlmBranchType.offline,
    );

    final orchestrator = ChatOrchestrator(
      storageRepository: storageRepo,
      vectorStoreRepository: vectorRepo,
      embeddingService: embeddingService,
      connectivityService: connectivityService,
      offlineLlmClient: offlineLlm,
      cloudLlmClient: cloudLlm,
    );

    await tester.pumpWidget(
      HealthcareChatApp(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        cloudLlmClient: cloudLlm,
        offlineLlmClient: offlineLlm,
        orchestrator: orchestrator,
      ),
    );

    await tester.pumpAndSettle();

    // Tap key icon
    final keyButton = find.byIcon(Icons.vpn_key_outlined);
    expect(keyButton, findsOneWidget);
    await tester.tap(keyButton);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Gemini API Settings'), findsOneWidget);
    expect(find.text('Test & Save Key'), findsOneWidget);
  });
}
