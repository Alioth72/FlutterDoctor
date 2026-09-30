import 'package:flutter/material.dart';

import 'features/chatbot/chatbot_embedding.dart';
import 'features/chatbot/chatbot_llm.dart';
import 'features/chatbot/chatbot_orchestrator.dart';
import 'features/chatbot/chatbot_retrieval.dart';
import 'features/chatbot/chatbot_storage.dart';
import 'features/chatbot/chatbot_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();
  runApp(const HealthcareChatApp());
}

/// Root Application Widget for the Offline-First Healthcare Chatbot.
class HealthcareChatApp extends StatelessWidget {
  const HealthcareChatApp({
    super.key,
    this.storageRepository,
    this.vectorStoreRepository,
    this.embeddingService,
    this.connectivityService,
    this.cloudLlmClient,
    this.offlineLlmClient,
    this.patientRepository,
    this.orchestrator,
  });

  final ChatStorageRepository? storageRepository;
  final VectorStoreRepository? vectorStoreRepository;
  final EmbeddingService? embeddingService;
  final ConnectivityService? connectivityService;
  final dynamic cloudLlmClient;
  final LlmClient? offlineLlmClient;
  final PatientRepository? patientRepository;
  final ChatOrchestrator? orchestrator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediAssist AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006A6A),
          primary: const Color(0xFF006A6A),
          secondary: const Color(0xFF0E7490),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0.5,
          scrolledUnderElevation: 1,
        ),
      ),
      home: AppInitializer(
        storageRepository: storageRepository,
        vectorStoreRepository: vectorStoreRepository,
        embeddingService: embeddingService,
        connectivityService: connectivityService,
        cloudLlmClient: cloudLlmClient,
        offlineLlmClient: offlineLlmClient,
        patientRepository: patientRepository,
        orchestrator: orchestrator,
      ),
    );
  }
}

/// Asynchronously bootstraps databases, knowledge ingestion, and orchestrator services.
class AppInitializer extends StatefulWidget {
  const AppInitializer({
    super.key,
    this.storageRepository,
    this.vectorStoreRepository,
    this.embeddingService,
    this.connectivityService,
    this.cloudLlmClient,
    this.offlineLlmClient,
    this.patientRepository,
    this.orchestrator,
  });

  final ChatStorageRepository? storageRepository;
  final VectorStoreRepository? vectorStoreRepository;
  final EmbeddingService? embeddingService;
  final ConnectivityService? connectivityService;
  final dynamic cloudLlmClient;
  final LlmClient? offlineLlmClient;
  final PatientRepository? patientRepository;
  final ChatOrchestrator? orchestrator;

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
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

      // 5.5 Initialize patient repository (Mock pre-loaded with Rajesh Sharma)
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
      debugPrint('Startup error: $e\n$stack');
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
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
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
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _statusMessage = 'Retrying initialization...';
                    });
                    _bootstrapServices();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A6A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF006A6A),
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'MediAssist AI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Offline-First Healthcare Clinical Assistant',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
