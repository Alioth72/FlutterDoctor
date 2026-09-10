import '../repositories/chat_storage_repository.dart';
import '../repositories/patient_repository.dart';
import '../repositories/vector_store_repository.dart';
import 'connectivity_service.dart';
import 'embedding_service.dart';
import 'llm_client.dart';
import 'prompt_builder.dart';

/// Central coordinator handling the entire query-to-answer healthcare pipeline.
class ChatOrchestrator {
  ChatOrchestrator({
    required this.storageRepository,
    required this.vectorStoreRepository,
    required this.embeddingService,
    required this.connectivityService,
    required this.offlineLlmClient,
    required this.cloudLlmClient,
    this.patientRepository,
    this.promptBuilder = const PromptBuilder(),
    this.cloudTimeout = const Duration(seconds: 35),
    this.topKRetrieval = 3,
  });

  /// Patient EHR repository (Mock or Azure Function).
  final PatientRepository? patientRepository;

  /// Local message persistence layer (Isar).
  final ChatStorageRepository storageRepository;

  /// Knowledge chunk retrieval layer (ObjectBox HNSW).
  final VectorStoreRepository vectorStoreRepository;

  /// Query embedding generator (PubMedBERT 768-dim).
  final EmbeddingService embeddingService;

  /// Network connectivity evaluator.
  final ConnectivityService connectivityService;

  /// On-device quantized generation engine (offline).
  final LlmClient offlineLlmClient;

  /// Cloud API generation engine (online).
  final LlmClient cloudLlmClient;

  /// Context-grounded RAG prompt assembler.
  final PromptBuilder promptBuilder;

  /// Maximum duration to await cloud response before falling back to offline engine.
  final Duration cloudTimeout;

  /// Number of top medical chunks to retrieve from knowledge base.
  final int topKRetrieval;

  /// Processes a user query end-to-end:
  ///
  /// 1. Persists user query to Isar.
  /// 2. Generates 768-dim query embedding on-device.
  /// 3. Searches local ObjectBox HNSW index for top-K medical chunks.
  /// 4. Assembles clinical RAG prompt with citations.
  /// 5. Checks connectivity & routes to Online Cloud API or Offline On-Device engine.
  /// 6. Automatically falls back to offline engine if online times out.
  /// 7. Persists and returns the generated bot response.
  Future<ChatMessage> handleUserMessage({
    required String text,
    required String conversationId,
    String? patientId,
  }) async {
    final query = text.trim();
    if (query.isEmpty) {
      throw ArgumentError('Message text cannot be empty or whitespace-only.');
    }

    // 1. Save User Message in local storage
    final userMessage = ChatMessage(
      conversationId: conversationId,
      role: MessageRole.user,
      text: query,
      timestamp: DateTime.now(),
    );
    await storageRepository.saveMessage(userMessage);

    // 2. Fetch active patient clinical profile (Allergies, Prescriptions, Vitals)
    final patientProfile =
        await patientRepository?.getActivePatientProfile(patientId: patientId);

    // 3. Generate on-device query embedding (Step 3)
    final queryVector = await embeddingService.embedQuery(query);

    // 4. Retrieve relevant medical knowledge chunks (Step 2)
    final retrievedChunks = await vectorStoreRepository.similaritySearch(
      queryVector,
      topKRetrieval,
    );

    // 5. Build augmented medical context prompt with Patient EHR
    final prompt = promptBuilder.buildPrompt(
      query: query,
      chunks: retrievedChunks,
      patientProfile: patientProfile,
    );

    // 5. Check connectivity & execute dual-branch generation
    final isOnline = await connectivityService.isOnline;
    LlmResponse llmResponse;

    if (isOnline) {
      try {
        llmResponse = await cloudLlmClient
            .generateResponse(
              prompt: prompt,
              contextChunks: retrievedChunks,
            )
            .timeout(cloudTimeout);
      } catch (e) {
        // Cloud timeout or network error -> Graceful offline fallback
        // ignore: avoid_print
        print('ChatOrchestrator: Cloud LLM error ($e), falling back to offline engine.');
        llmResponse = await offlineLlmClient.generateResponse(
          prompt: prompt,
          contextChunks: retrievedChunks,
        );
      }
    } else {
      // Direct offline routing
      llmResponse = await offlineLlmClient.generateResponse(
        prompt: prompt,
        contextChunks: retrievedChunks,
      );
    }

    // 6. Save Bot Message in local storage
    final botMessage = ChatMessage(
      conversationId: conversationId,
      role: MessageRole.bot,
      text: llmResponse.text,
      timestamp: DateTime.now(),
      isSynced: llmResponse.branch == LlmBranchType.online,
    );
    await storageRepository.saveMessage(botMessage);

    return botMessage;
  }
}
