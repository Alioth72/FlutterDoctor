import 'package:flutter/material.dart';

import '../../../chatbot_embedding.dart';
import '../../../chatbot_llm.dart';
import '../../../chatbot_orchestrator.dart';
import '../../../chatbot_retrieval.dart';
import '../../../chatbot_storage.dart';
import '../../../data/repositories/mock_patient_repository.dart';
import '../../../domain/repositories/patient_repository.dart';
import '../../widgets/api_key_dialog.dart';
import 'chat_screen.dart';

/// Single-line plug-and-play entry point for the Healthcare Chatbot.
///
/// Use this directly in your Patient App on your "AI Assistance" button:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => const ChatbotPage()),
/// );
/// ```
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

  /// Optional patient repository. Defaults to [MockPatientRepository] if not supplied.
  final PatientRepository? patientRepository;

  /// Optional active patient ID.
  final String? patientId;

  /// Unique conversation identifier.
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
  String _statusMessage = 'Initializing local storage & databases...';

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

      // 1. Initialize local message persistence (Isar)
      final storage = widget.storageRepository ?? IsarChatStorageRepository();
      await storage.init();

      // 2. Initialize local vector database (ObjectBox HNSW)
      setState(() {
        _statusMessage = 'Loading offline medical knowledge base (MedQuAD)...';
      });
      final vectorStore =
          widget.vectorStoreRepository ?? ObjectBoxVectorStoreRepository();
      await vectorStore.init();
      await vectorStore.ingestAssetIfEmpty();

      // 3. Initialize query embedding service
      setState(() {
        _statusMessage = 'Starting medical tokenizer & embedding engine...';
      });
      final embedding = widget.embeddingService ?? OnnxEmbeddingService();
      await embedding.init();

      // 4. Initialize connectivity observer
      final connectivity =
          widget.connectivityService ?? DefaultConnectivityService();

      // 5. Initialize generation engines (load saved key if present)
      await EnvConfig.init();
      final savedApiKey = await ApiKeyDialog.loadPersistedApiKey();
      final cloudLlm = widget.cloudLlmClient ??
          GroqCloudLlmClient(
            apiKey: savedApiKey,
            model: 'openai/gpt-oss-20b',
          );
      final offlineLlm =
          widget.offlineLlmClient ?? const ExtractiveOfflineLlmClient();

      // 5.5 Initialize patient repository (Mock pre-loaded with Rajesh Sharma if not supplied)
      final patientRepo = widget.patientRepository ?? MockPatientRepository();

      // 6. Assemble orchestrator coordinator
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
