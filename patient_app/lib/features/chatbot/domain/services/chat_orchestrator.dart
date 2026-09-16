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

  /// Local message persistence layer.
  final ChatStorageRepository storageRepository;

  /// Knowledge chunk retrieval layer.
  final VectorStoreRepository vectorStoreRepository;

  /// Query embedding generator.
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
  /// 1. Persists user query to local storage.
  /// 2. Fetches active patient profile.
  /// 3. Generates query embedding vector.
  /// 4. Searches local index for top-K medical chunks.
  /// 5. Assembles clinical RAG prompt with citations.
  /// 6. Checks connectivity & routes to Online Cloud API or Offline On-Device engine.
  /// 7. Automatically falls back to offline engine if online times out.
  /// 8. Persists and returns the generated bot response.
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

    // 3. Generate query embedding if initialized
    List<double> queryVector = [];
    try {
      if (embeddingService.isInitialized) {
        queryVector = await embeddingService.embedQuery(query);
      }
    } catch (_) {}

    // 4. Retrieve relevant medical knowledge chunks
    List<SearchResult> retrievedChunks = [];
    try {
      if (queryVector.isNotEmpty) {
        retrievedChunks = await vectorStoreRepository.similaritySearch(
          queryVector,
          topKRetrieval,
        );
      }
    } catch (_) {}

    // 5. Build augmented medical context prompt with Patient EHR
    final prompt = promptBuilder.buildPrompt(
      query: query,
      chunks: retrievedChunks,
      patientProfile: patientProfile,
    );

    // 6. Check connectivity & execute dual-branch generation
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

    // 7. Save Bot Message in local storage
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
