import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_embedding.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_orchestrator.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_storage.dart';

class FakeLlmClient implements LlmClient {
  FakeLlmClient({
    required this.branch,
    required this.responseText,
    this.delay = Duration.zero,
    this.shouldThrow = false,
  });

  final LlmBranchType branch;
  final String responseText;
  final Duration delay;
  final bool shouldThrow;

  int callCount = 0;
  String? lastPrompt;
  List<SearchResult>? lastChunks;

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    callCount++;
    lastPrompt = prompt;
    lastChunks = contextChunks;

    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (shouldThrow) {
      throw const SocketException('Cloud connection failed');
    }

    return LlmResponse(
      text: responseText,
      branch: branch,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late IsarChatStorageRepository storageRepo;
  late ObjectBoxVectorStoreRepository vectorRepo;
  late OnnxEmbeddingService embeddingService;
  late MockConnectivityService connectivityService;

  setUpAll(() async {
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orchestrator_test_');

    // Initialize Storage (Isar)
    storageRepo = IsarChatStorageRepository();
    await storageRepo.init(directory: tempDir.path);

    // Initialize Vector Store (ObjectBox)
    vectorRepo = ObjectBoxVectorStoreRepository();
    await vectorRepo.init(directory: tempDir.path);

    // Ingest sample chunks
    final sampleJson = jsonEncode([
      {
        'text': 'Iron deficiency anemia causes pale skin and weakness.',
        'source': 'MedQuAD: What is anemia? (001)',
        'embedding': List<double>.filled(768, 0.1),
      },
    ]);
    await vectorRepo.ingestAssetIfEmpty(rawJsonContent: sampleJson);

    // Initialize Embedding Service
    embeddingService = OnnxEmbeddingService();
    await embeddingService.init();

    // Default to Online
    connectivityService = MockConnectivityService(initialOnline: true);
  });

  tearDown(() async {
    await storageRepo.close();
    await vectorRepo.close();
    embeddingService.close();
    connectivityService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ChatOrchestrator', () {
    test('routes to Cloud LLM when online and stores synced message in Isar', () async {
      final cloudClient = FakeLlmClient(
        branch: LlmBranchType.online,
        responseText: 'Cloud response: Anemia is treated with iron supplements.',
      );
      final offlineClient = FakeLlmClient(
        branch: LlmBranchType.offline,
        responseText: 'Offline response.',
      );

      final orchestrator = ChatOrchestrator(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        offlineLlmClient: offlineClient,
        cloudLlmClient: cloudClient,
      );

      final botMessage = await orchestrator.handleUserMessage(
        text: 'What is the treatment for anemia?',
        conversationId: 'conv_online_1',
      );

      // Verify Cloud was called, Offline was not
      expect(cloudClient.callCount, 1);
      expect(offlineClient.callCount, 0);

      // Verify Bot response content and sync flag
      expect(botMessage.text, contains('Cloud response'));
      expect(botMessage.role, MessageRole.bot);
      expect(botMessage.isSynced, isTrue);

      // Verify both User and Bot messages are saved in Isar
      final messages = await storageRepo.getMessagesForConversation('conv_online_1');
      expect(messages.length, 2);
      expect(messages[0].role, MessageRole.user);
      expect(messages[0].text, 'What is the treatment for anemia?');
      expect(messages[1].role, MessageRole.bot);
      expect(messages[1].text, contains('Cloud response'));
    });

    test('routes directly to Offline LLM when disconnected', () async {
      connectivityService.setOnline(false);

      final cloudClient = FakeLlmClient(
        branch: LlmBranchType.online,
        responseText: 'Cloud response.',
      );
      final offlineClient = FakeLlmClient(
        branch: LlmBranchType.offline,
        responseText: 'Offline response: Rest and eat iron-rich foods.',
      );

      final orchestrator = ChatOrchestrator(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        offlineLlmClient: offlineClient,
        cloudLlmClient: cloudClient,
      );

      final botMessage = await orchestrator.handleUserMessage(
        text: 'How to manage anemia offline?',
        conversationId: 'conv_offline_1',
      );

      expect(cloudClient.callCount, 0);
      expect(offlineClient.callCount, 1);
      expect(botMessage.text, contains('Offline response'));
      expect(botMessage.isSynced, isFalse); // Queued for background sync

      final unsynced = await storageRepo.getUnsyncedMessages();
      expect(unsynced.any((m) => m.text.contains('Offline response')), isTrue);
    });

    test('falls back to Offline LLM when Cloud call times out', () async {
      connectivityService.setOnline(true);

      // Cloud client hangs for 200ms
      final cloudClient = FakeLlmClient(
        branch: LlmBranchType.online,
        responseText: 'Slow cloud response.',
        delay: const Duration(milliseconds: 200),
      );
      final offlineClient = FakeLlmClient(
        branch: LlmBranchType.offline,
        responseText: 'Offline fallback response after timeout.',
      );

      final orchestrator = ChatOrchestrator(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        offlineLlmClient: offlineClient,
        cloudLlmClient: cloudClient,
        cloudTimeout: const Duration(milliseconds: 50), // 50ms timeout threshold
      );

      final botMessage = await orchestrator.handleUserMessage(
        text: 'Testing cloud timeout fallback',
        conversationId: 'conv_timeout_1',
      );

      // Offline fallback succeeded
      expect(offlineClient.callCount, 1);
      expect(botMessage.text, contains('Offline fallback response'));
      expect(botMessage.isSynced, isFalse);
    });

    test('falls back to Offline LLM when Cloud call throws an error', () async {
      connectivityService.setOnline(true);

      final cloudClient = FakeLlmClient(
        branch: LlmBranchType.online,
        responseText: 'Cloud error',
        shouldThrow: true,
      );
      final offlineClient = FakeLlmClient(
        branch: LlmBranchType.offline,
        responseText: 'Offline fallback response on cloud error.',
      );

      final orchestrator = ChatOrchestrator(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        offlineLlmClient: offlineClient,
        cloudLlmClient: cloudClient,
      );

      final botMessage = await orchestrator.handleUserMessage(
        text: 'Testing cloud error fallback',
        conversationId: 'conv_error_1',
      );

      expect(offlineClient.callCount, 1);
      expect(botMessage.text, contains('Offline fallback response on cloud error'));
    });

    test('assembles prompt with retrieved MedQuAD context chunks and citations', () async {
      final cloudClient = FakeLlmClient(
        branch: LlmBranchType.online,
        responseText: 'Answer with citations.',
      );
      final offlineClient = FakeLlmClient(
        branch: LlmBranchType.offline,
        responseText: 'Offline.',
      );

      final orchestrator = ChatOrchestrator(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        offlineLlmClient: offlineClient,
        cloudLlmClient: cloudClient,
      );

      await orchestrator.handleUserMessage(
        text: 'Tell me about anemia symptoms',
        conversationId: 'conv_prompt_1',
      );

      expect(cloudClient.lastPrompt, isNotNull);
      expect(cloudClient.lastPrompt, contains('MedQuAD: What is anemia?'));
      expect(cloudClient.lastPrompt, contains('Iron deficiency anemia causes'));
      expect(cloudClient.lastPrompt, contains('Medical Disclaimer'));
      expect(cloudClient.lastChunks?.length, 1);
    });

    test('rejects empty or whitespace query with ArgumentError without saving', () async {
      final cloudClient = FakeLlmClient(branch: LlmBranchType.online, responseText: '');
      final offlineClient = FakeLlmClient(branch: LlmBranchType.offline, responseText: '');

      final orchestrator = ChatOrchestrator(
        storageRepository: storageRepo,
        vectorStoreRepository: vectorRepo,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        offlineLlmClient: offlineClient,
        cloudLlmClient: cloudClient,
      );

      expect(
        () => orchestrator.handleUserMessage(text: '   ', conversationId: 'conv_empty'),
        throwsA(isA<ArgumentError>()),
      );

      final messages = await storageRepo.getMessagesForConversation('conv_empty');
      expect(messages, isEmpty);
    });
  });
}
