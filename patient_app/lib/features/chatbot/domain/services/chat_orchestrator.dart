import 'package:flutter/foundation.dart';
import '../../../../services/localization/sarvam_translation_service.dart';
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
    String? languageCode,
    String? languageName,
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
      languageCode: languageCode,
      languageName: languageName,
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

    // 7. Guarantee response matches the patient's chosen language
    var finalResponseText = llmResponse.text;
    if (languageCode != null && _needsTranslation(finalResponseText, languageCode)) {
      try {
        final translated = await SarvamTranslationService.translate(
          finalResponseText,
          targetLanguageCode: languageCode,
        );
        if (translated.trim().isNotEmpty && translated != finalResponseText) {
          finalResponseText = translated;
        }
      } catch (e) {
        debugPrint('[ChatOrchestrator] Post-translation note: $e');
      }
    }

    // 8. Save Bot Message in local storage
    final botMessage = ChatMessage(
      conversationId: conversationId,
      role: MessageRole.bot,
      text: finalResponseText,
      timestamp: DateTime.now(),
      isSynced: llmResponse.branch == LlmBranchType.online,
    );
    await storageRepository.saveMessage(botMessage);

    return botMessage;
  }

  bool _needsTranslation(String text, String targetLang) {
    if (targetLang == 'en' || targetLang == 'en-IN') return false;
    final primary = targetLang.split('-').first.toLowerCase();
    switch (primary) {
      case 'hi':
      case 'mr':
      case 'ne':
      case 'sa':
      case 'mai':
      case 'kok':
      case 'doi':
        return !RegExp(r'[\u0900-\u097F]').hasMatch(text);
      case 'bn':
      case 'as':
        return !RegExp(r'[\u0980-\u09FF]').hasMatch(text);
      case 'pa':
        return !RegExp(r'[\u0A00-\u0A7F]').hasMatch(text);
      case 'gu':
        return !RegExp(r'[\u0A80-\u0AFF]').hasMatch(text);
      case 'or':
      case 'od':
        return !RegExp(r'[\u0B00-\u0B7F]').hasMatch(text);
      case 'ta':
        return !RegExp(r'[\u0B80-\u0BFF]').hasMatch(text);
      case 'te':
        return !RegExp(r'[\u0C00-\u0C7F]').hasMatch(text);
      case 'kn':
        return !RegExp(r'[\u0C80-\u0CFF]').hasMatch(text);
      case 'ml':
        return !RegExp(r'[\u0D00-\u0D7F]').hasMatch(text);
      case 'ur':
      case 'ks':
      case 'sd':
        return !RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      case 'mni':
        return !RegExp(r'[\uABC0-\uABFF\u0980-\u09FF]').hasMatch(text);
      case 'sat':
        return !RegExp(r'[\u1C50-\u1C7F\u0900-\u097F]').hasMatch(text);
      default:
        return !RegExp(r'[؀-ۿऀ-෿ꯀ-꯿᱐-᱿]').hasMatch(text);
    }
  }
}
