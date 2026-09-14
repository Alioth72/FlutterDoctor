# Healthcare Chatbot — Project Context & Progress

## 1. Project Overview
A lightweight, offline-first medical Q&A chatbot built in **Flutter (Dart)** for low-connectivity environments and low-resource devices (2–3GB RAM).

### Core Features Architecture
- **Offline Storage**: Local message persistence with reactive streams (Isar).
- **Local Retrieval (RAG)**: Offline similarity search using 768-dimension PubMedBERT embeddings (MedQuAD + NHP India) via ObjectBox HNSW.
- **On-Device Embedding**: Converting queries to 768-dim embeddings via ONNX Runtime.
- **Emergency Triage**: Pre-execution keyword triage intercepting urgent symptoms (chest pain, breathing difficulty, severe bleeding) before retrieval/generation.
- **Dual-Branch Orchestrator**:
  - **Offline**: On-device quantized LLM (MediaPipe / Gemma).
  - **Online**: Cloud LLM API with optional live MedlinePlus widening.
- **Background Sync**: Queued offline telemetry/logging flushed when network returns (`workmanager`).

---

## 2. Directory Structure

```text
chatbot_healthcare/
├── assets/
│   └── data/
│       └── medical_knowledge_embeddings.json # 768-dim PubMedBERT knowledge embeddings
├── lib/
│   ├── features/
│   │   └── chatbot/
│   │       ├── chatbot_storage.dart          # Barrel export for storage layer (Step 1)
│   │       ├── chatbot_retrieval.dart        # Barrel export for vector retrieval (Step 2)
│   │       ├── chatbot_embedding.dart        # Barrel export for on-device embedding (Step 3)
│   │       ├── chatbot_orchestrator.dart     # Barrel export for orchestration layer (Step 5)
│   │       ├── chatbot_llm.dart              # Barrel export for LLM generation layer (Step 6/7)
│   │       ├── data/
│   │       │   ├── models/
│   │       │   │   ├── chat_message.dart      # Isar collection schema
│   │       │   │   ├── chat_message.g.dart    # Generated Isar adapter
│   │       │   │   └── medical_chunk.dart     # ObjectBox HNSW 768-dim entity
│   │       │   ├── repositories/
│   │       │   │   ├── isar_chat_storage_repository.dart       # Isar persistence
│   │       │   │   └── objectbox_vector_store_repository.dart  # ObjectBox HNSW retrieval
│   │       │   └── services/
│   │       │       ├── bert_tokenizer.dart                     # WordPiece pure-Dart tokenizer
│   │       │       ├── onnx_embedding_service.dart             # ONNX/Deterministic embedding runner
│   │       │       ├── default_connectivity_service.dart       # DNS & Mock connectivity evaluator
│   │       │       ├── gemini_cloud_llm_client.dart            # Google Gemini REST API client
│   │       │       └── extractive_offline_llm_client.dart      # Zero-RAM MedQuAD extractive synthesizer
│   │       └── domain/
│   │           ├── models/
│   │           │   └── search_result.dart     # Retrieved chunk model {text, source, score}
│   │           ├── repositories/
│   │           │   ├── chat_storage_repository.dart   # Abstract storage contract
│   │           │   └── vector_store_repository.dart   # Abstract vector store contract
│   │           └── services/
│   │               ├── embedding_service.dart         # Abstract embedding contract
│   │               ├── connectivity_service.dart      # Abstract connectivity contract
│   │               ├── llm_client.dart                # Abstract LLM generation contract
│   │               ├── prompt_builder.dart            # Clinical RAG context prompt assembler
│   │               └── chat_orchestrator.dart         # End-to-end pipeline coordinator
│   ├── objectbox.g.dart                       # Generated ObjectBox bindings
│   ├── objectbox-model.json                   # ObjectBox model definition
│   └── main.dart                             # App entry point
├── test/
│   ├── features/
│   │   └── chatbot/
│   │       ├── isar_chat_storage_test.dart       # Step 1 unit test suite (5 passing tests)
│   │       ├── vector_store_repository_test.dart # Step 2 unit test suite (5 passing tests)
│   │       ├── bert_tokenizer_test.dart          # Step 3 tokenizer tests (7 passing tests)
│   │       ├── embedding_service_test.dart       # Step 3 embedding service tests (7 passing tests)
│   │       ├── chat_orchestrator_test.dart            # Step 5 orchestrator tests (6 passing tests)
│   │       ├── gemini_cloud_llm_client_test.dart      # Step 7 Gemini client tests (5 passing tests)
│   │       └── extractive_offline_llm_client_test.dart# Step 6 Offline synthesizer tests (3 passing tests)
│   └── widget_test.dart
├── pubspec.yaml                              # Dependencies config
└── context.md                                # This file
```

---

## 3. What Has Been Built

### Step 1 — Local Chat Storage (Completed ✅)
- **Model**: `ChatMessage` (`id`, `conversationId` composite index with `timestamp`, `role`, `text`, `timestamp`, `isUrgent`, `isSynced`).
- **Interface**: `ChatStorageRepository` (CRUD, conversations, unsynced tracking, reactive stream).
- **Implementation**: `IsarChatStorageRepository` with atomic write transactions and query watchers.
- **Tests**: 5/5 passing unit tests.

### Step 2 — Local Vector Store (Completed ✅)
- **Vector Engine**: **ObjectBox** with native C-core HNSW vector indexing (`@HnswIndex(dimensions: 768, distanceType: VectorDistanceType.cosine)`).
- **Entity**: `MedicalChunk` (`id`, `text`, `source`, `embedding` [floatVector 768]).
- **Interface**: `VectorStoreRepository` (`init`, `ingestAssetIfEmpty`, `similaritySearch`, `count`, `clearAll`, `close`).
- **Implementation**: `ObjectBoxVectorStoreRepository`:
  - Parses `assets/data/medical_knowledge_embeddings.json` on first launch into ObjectBox (5,001 real PubMedBERT embeddings from MedQuAD + NHP India, ~88MB).
  - Idempotent: Skips parsing on subsequent launches (<5ms load time).
  - High-performance HNSW nearest neighbors search: `MedicalChunk_.embedding.nearestNeighborsF32(queryEmbedding, topK)`.
- **Domain Result Model**: `SearchResult` (`text`, `source`, `score`).
- **Tests**: 5/5 passing unit tests verifying idempotency, 768-dim validation, nearest neighbor search, and asset integrity.

### Step 3 — On-Device Embedding Service (Completed ✅)
- **Tokenizer**: `BertTokenizer` pure-Dart WordPiece tokenizer with medical vocabulary, special tokens (`[CLS]`, `[SEP]`, `[PAD]`), attention masks, subword `##` parsing, and `vocab.txt` string loading.
- **Interface**: `EmbeddingService` (`init`, `embedQuery`, `isInitialized`, `close`).
- **Implementation**: `OnnxEmbeddingService`:
  - Enforces strict 768-dimension output constraint.
  - Applies L2 unit normalization ($\|v\|_2 = 1.0$) for cosine similarity search.
  - Uses pluggable `EmbeddingRunner` delegate: `DeterministicEmbeddingRunner` (fast, deterministic local testing) + `OnnxModelRunner` (for native `.onnx` model weights).
- **Tests**: 14 passing unit tests (7 for `BertTokenizer`, 7 for `OnnxEmbeddingService` including ObjectBox similarity search chaining).

### Step 4 — Emergency Triage Check (Omitted ⏭️)
- Skipped per user design preference to eliminate false lockouts on educational queries.
- Emergency safety warnings and medical disclaimers are handled natively via `PromptBuilder` and the static Chat UI banner.

### Step 5 — Connectivity Orchestrator (Completed ✅)
- **Engine**: `ChatOrchestrator` coordinating the full end-to-end pipeline:
  1. Persists User `ChatMessage` to Isar storage.
  2. Embeds query on-device (768-dim float vector via `EmbeddingService`).
  3. Searches local ObjectBox HNSW index for top-3 MedQuAD knowledge chunks.
  4. Assembles clinical RAG prompt with citations and medical disclaimer via `PromptBuilder`.
  5. Evaluates network reachability via `ConnectivityService`:
     - **Online**: Routes to `CloudLlmClient` with a 5-second timeout.
     - **Offline / Cloud Error**: Automatically falls back to `OfflineLlmClient`.
  6. Persists Bot response `ChatMessage` in Isar (flagging `isSynced` accordingly).
- **Contracts**: `ConnectivityService`, `LlmClient`, `PromptBuilder`.
- **Implementations**: `DefaultConnectivityService`, `MockConnectivityService`.
- **Tests**: 6/6 passing unit tests covering online routing, offline execution, cloud timeout fallback, error fallback, prompt assembly, and input validation.

### Step 6 & 7 — LLM Generation: Cloud Gemini API & Offline Extractive Synthesizer (Completed ✅)
- **Online Engine (`GeminiCloudLlmClient`)**:
  - Direct REST integration with Google's Gemini API (`gemini-1.5-flash`).
  - Grounded generation citing verified MedQuAD source chunks.
  - Configurable via constructor, `--dart-define=GEMINI_API_KEY`, or runtime `setApiKey()`.
- **Offline Engine (`ExtractiveOfflineLlmClient`)**:
  - Formats retrieved local ObjectBox MedQuAD chunks into structured bulleted findings.
  - Ultra-low memory (<1 MB RAM) and zero model download overhead for 2–3 GB RAM devices.
- **Barrel Export**: `chatbot_llm.dart`.
- **Tests**: 8 passing unit tests (5 for `GeminiCloudLlmClient`, 3 for `ExtractiveOfflineLlmClient`).

---

## 4. Usage Example

```dart
import 'package:chatbot_healthcare/features/chatbot/chatbot_embedding.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_llm.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_orchestrator.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_retrieval.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_storage.dart';

void example() async {
  // 1. Initialize core layers
  final storage = IsarChatStorageRepository();
  await storage.init();

  final vectorStore = ObjectBoxVectorStoreRepository();
  await vectorStore.init();
  await vectorStore.ingestAssetIfEmpty();

  final embedding = OnnxEmbeddingService();
  await embedding.init();

  final connectivity = DefaultConnectivityService();

  // 2. Initialize generation engines
  final cloudLlm = GeminiCloudLlmClient(apiKey: "YOUR_GEMINI_API_KEY");
  const offlineLlm = ExtractiveOfflineLlmClient();

  // 3. Instantiate orchestrator
  final orchestrator = ChatOrchestrator(
    storageRepository: storage,
    vectorStoreRepository: vectorStore,
    embeddingService: embedding,
    connectivityService: connectivity,
    offlineLlmClient: offlineLlm,
    cloudLlmClient: cloudLlm,
  );

  // 4. Process query end-to-end (saves user & bot messages in Isar automatically)
  final botResponse = await orchestrator.handleUserMessage(
    text: "What are the common symptoms of anemia?",
    conversationId: "conv_main",
  );

  print("Bot answered: ${botResponse.text}");
}
```

---

## 5. Roadmap & Status (Prompt v3)

| Step | Feature | Description | Status |
| :--- | :--- | :--- | :--- |
| **1** | **Local Chat Storage** | Isar model, repository CRUD, reactive stream, tests | **Completed** ✅ |
| **2** | **Local Vector Store** | ObjectBox HNSW 768-dim vector store, idempotent ingestion | **Completed** ✅ |
| **3** | **On-Device Embedding Service** | `EmbeddingService` interface + PubMedBERT WordPiece tokenizer + ONNX runner | **Completed** ✅ |
| ~~**4**~~ | ~~**Emergency Triage Check**~~ | *Skipped (handled via UI disclaimer & prompt)* | **Omitted** ⏭️ |
| **5** | **Connectivity Orchestrator** | `ChatOrchestrator`: Full pipeline, dual-branch routing & timeout fallback | **Completed** ✅ |
| **6** | **Offline Generation Engine** | `ExtractiveOfflineLlmClient`: Zero-RAM MedQuAD synthesizer | **Completed** ✅ |
| **7** | **Cloud LLM Integration** | `GeminiCloudLlmClient`: Direct REST Google Gemini API | **Completed** ✅ |
| **8** | **Chat UI** | Complete Flutter Material 3 Chat UI, reactive stream, status badge, emergency banner, suggestion chips, runtime Gemini API key sheet | **Completed** ✅ |
| **9** | **Background Sync** | `workmanager` offline queue flushing when network restores | *Pending* |
