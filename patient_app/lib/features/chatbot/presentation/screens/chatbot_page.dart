import 'package:flutter/material.dart';

import '../../../../services/tts/sarvam_tts_service.dart';
import '../../data/repositories/local_vector_store_repository.dart';
import '../../data/repositories/mock_patient_repository.dart';
import '../../data/repositories/preferences_chat_storage_repository.dart';
import '../../data/services/default_connectivity_service.dart';
import '../../data/services/env_config.dart';
import '../../data/services/extractive_offline_llm_client.dart';
import '../../data/services/gemini_cloud_llm_client.dart';
import '../../data/services/onnx_embedding_service.dart';
import '../../domain/repositories/chat_storage_repository.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/repositories/vector_store_repository.dart';
import '../../domain/services/chat_orchestrator.dart';
import '../../domain/services/connectivity_service.dart';
import '../../domain/services/embedding_service.dart';
import '../../domain/services/llm_client.dart';
import '../widgets/api_key_dialog.dart';
import 'chat_screen.dart';

/// Single-line plug-and-play entry point for the Healthcare Chatbot in Patient App.
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({
    super.key,
    this.patientRepository,
    this.patientId,
    this.conversationId = 'default_conversation',
    this.storageRepository,
    this.vectorStoreRepository,
    this.embeddingService,
    this.connectivityService,
    this.cloudLlmClient,
    this.offlineLlmClient,
    this.orchestrator,
  });

  final PatientRepository? patientRepository;
  final String? patientId;
  final String conversationId;
  final ChatStorageRepository? storageRepository;
  final VectorStoreRepository? vectorStoreRepository;
  final EmbeddingService? embeddingService;
  final ConnectivityService? connectivityService;
  final dynamic cloudLlmClient;
  final LlmClient? offlineLlmClient;
  final ChatOrchestrator? orchestrator;

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  bool _isReady = false;
  String? _errorMessage;
  String _statusMessage = 'Connecting to Medical Knowledge & AI Services...';

  late ChatStorageRepository _storage;
  late ConnectivityService _connectivity;
  late dynamic _cloudLlm;
  late ChatOrchestrator _orchestrator;
  late PatientRepository _patientRepo;

  @override
  void initState() {
    super.initState();
    _bootstrapServices();
  }

  Future<void> _bootstrapServices() async {
    try {
      if (widget.orchestrator != null &&
          widget.storageRepository != null &&
          widget.connectivityService != null &&
          widget.cloudLlmClient != null) {
        _storage = widget.storageRepository!;
        _connectivity = widget.connectivityService!;
        _cloudLlm = widget.cloudLlmClient!;
        _orchestrator = widget.orchestrator!;
        _patientRepo = widget.patientRepository ?? MockPatientRepository();
        setState(() {
          _isReady = true;
        });
        return;
      }

      // 1. Initialize persistent storage
      final storage = widget.storageRepository ?? PreferencesChatStorageRepository();
      await storage.init();

      // 2. Initialize knowledge vector store
      setState(() {
        _statusMessage = 'Loading clinical knowledge base...';
      });
      final vectorStore =
          widget.vectorStoreRepository ?? LocalVectorStoreRepository();
      await vectorStore.init();
      await vectorStore.ingestAssetIfEmpty();

      // 3. Initialize embedding engine
      setState(() {
        _statusMessage = 'Initializing medical language models...';
      });
      final embedding = widget.embeddingService ?? OnnxEmbeddingService();
      await embedding.init();

      // 4. Initialize connectivity observer
      final connectivity =
          widget.connectivityService ?? DefaultConnectivityService();

      // 5. Initialize generation engines with multi-key Gemini cloud client
      await EnvConfig.init();
      final savedApiKey = await ApiKeyDialog.loadPersistedApiKey();
      final cloudLlm = widget.cloudLlmClient ??
          GeminiCloudLlmClient(
            apiKey: savedApiKey,
            model: 'gemini-2.5-flash',
          );
      final offlineLlm =
          widget.offlineLlmClient ?? const ExtractiveOfflineLlmClient();

      // 6. Initialize patient profile repository
      final patientRepo = widget.patientRepository ?? MockPatientRepository();

      // 7. Initialize Sarvam Text-to-Speech service
      await SarvamTtsService.instance.init();

      // 8. Assemble orchestrator
      final orchestrator = widget.orchestrator ??
          ChatOrchestrator(
            storageRepository: storage,
            vectorStoreRepository: vectorStore,
            embeddingService: embedding,
            connectivityService: connectivity,
            offlineLlmClient: offlineLlm,
            cloudLlmClient: cloudLlm,
            patientRepository: patientRepo,
          );

      if (mounted) {
        setState(() {
          _storage = storage;
          _connectivity = connectivity;
          _cloudLlm = cloudLlm;
          _patientRepo = patientRepo;
          _orchestrator = orchestrator;
          _isReady = true;
        });
      }
    } catch (e, stack) {
      debugPrint('Chatbot startup error: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return ChatScreen(
        orchestrator: _orchestrator,
        storageRepository: _storage,
        connectivityService: _connectivity,
        cloudLlmClient: _cloudLlm,
        patientRepository: _patientRepo,
        conversationId: widget.conversationId,
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MediAssist AI')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _statusMessage = 'Retrying initialization...';
                    });
                    _bootstrapServices();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('MediAssist AI'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  size: 48,
                  color: Color(0xFF006A6A),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Connecting to Medical Assistant...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
