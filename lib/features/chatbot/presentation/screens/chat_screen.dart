import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/services/gemini_cloud_llm_client.dart';
import '../../domain/models/patient_profile.dart';
import '../../domain/repositories/chat_storage_repository.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/services/chat_orchestrator.dart';
import '../../domain/services/connectivity_service.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/formatted_message_view.dart';

/// Primary conversational screen for the Healthcare Chatbot.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.orchestrator,
    required this.storageRepository,
    required this.connectivityService,
    required this.cloudLlmClient,
    this.patientRepository,
    this.conversationId = 'default_conversation',
  });

  final ChatOrchestrator orchestrator;
  final ChatStorageRepository storageRepository;
  final ConnectivityService connectivityService;
  final dynamic cloudLlmClient;
  final PatientRepository? patientRepository;
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isGenerating = false;
  bool _isOnline = false;
  bool _showEmergencyBanner = true;
  bool _showPatientDetails = false;
  PatientProfile? _patientProfile;
  StreamSubscription<bool>? _connectivitySub;

  static const List<String> _suggestions = [
    'Can I take Amoxicillin for my cold?',
    'When should I take Cetirizine?',
    'Where is my room or appointment?',
    'What are the symptoms of dengue?',
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _loadPatientProfile();
    _connectivitySub = widget.connectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    });
  }

  Future<void> _loadPatientProfile() async {
    final repo = widget.patientRepository ?? widget.orchestrator.patientRepository;
    final profile = await repo?.getActivePatientProfile();
    if (mounted && profile != null) {
      setState(() {
        _patientProfile = profile;
      });
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final online = await widget.connectivityService.isOnline;
    if (mounted) {
      setState(() {
        _isOnline = online;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    _textController.clear();
    setState(() {
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final responseMsg = await widget.orchestrator.handleUserMessage(
        text: text,
        conversationId: widget.conversationId,
        patientId: _patientProfile?.patientId,
      );
      if (!responseMsg.isSynced && mounted) {
        if (!widget.cloudLlmClient.hasApiKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ Using offline database. Tap 🔑 at the top to connect Groq AI!'),
              backgroundColor: const Color(0xFFD97706),
              action: SnackBarAction(
                label: 'Add Key',
                textColor: Colors.white,
                onPressed: () => ApiKeyDialog.show(
                  context,
                  cloudClient: widget.cloudLlmClient,
                  onKeySaved: () => setState(() {}),
                ),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ Cloud call failed. Tap 🔑 to verify your Groq API key or network.'),
              backgroundColor: const Color(0xFFD97706),
              action: SnackBarAction(
                label: 'Check Key',
                textColor: Colors.white,
                onPressed: () => ApiKeyDialog.show(
                  context,
                  cloudClient: widget.cloudLlmClient,
                  onKeySaved: () => setState(() {}),
                ),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating response: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will delete all messages in this conversation from your offline storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageRepository.deleteConversation(widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation cleared.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF006A6A),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MediAssist AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                _buildConnectivityBadge(),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF475569)),
            tooltip: 'Groq API Settings',
            onPressed: () => ApiKeyDialog.show(
              context,
              cloudClient: widget.cloudLlmClient,
              onKeySaved: () => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF475569)),
            tooltip: 'Clear Chat',
            onPressed: _confirmClearChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!widget.cloudLlmClient.hasApiKey) _buildMissingApiKeyBanner(),
          if (_showEmergencyBanner) _buildEmergencyBanner(),
          _buildPatientContextBanner(),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.storageRepository.watchMessagesForConversation(
                widget.conversationId,
              ),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty && !_isGenerating) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + (_isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return _buildGeneratingIndicator();
                    }
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildConnectivityBadge() {
    final isOnline = _isOnline;
    final color = isOnline ? const Color(0xFF059669) : const Color(0xFFD97706);
    final engineName = widget.cloudLlmClient is GeminiCloudLlmClient
        ? 'Gemini Flash'
        : 'Groq Llama 3.3';
    final text = isOnline ? 'Online ($engineName)' : 'Offline (MedQuAD Knowledge)';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMissingApiKeyBanner() {
    return Container(
      color: const Color(0xFFFFFBEB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.vpn_key_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Groq API key missing: Running in raw offline mode. Add your free key for ultra-fast, conversational answers.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => ApiKeyDialog.show(
              context,
              cloudClient: widget.cloudLlmClient,
              onKeySaved: () => setState(() {}),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Add Key', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return Container(
      color: const Color(0xFFFEF2F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Emergency Advisory: For informational reference only. If experiencing severe chest pain, shortness of breath, or trauma, call emergency services (112/911) immediately.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _showEmergencyBanner = false),
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF991B1B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientContextBanner() {
    if (_patientProfile == null) return const SizedBox.shrink();

    final p = _patientProfile!;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF006A6A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${p.name} (${p.bloodGroup})',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.allergies.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                '⚠️ Allergy: ${p.allergies.first}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.room ?? "IPD Ward 304"} • ${p.doctorName ?? "Dr. Rajesh V. Sharma"}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showPatientDetails = !_showPatientDetails;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _showPatientDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showPatientDetails) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              color: const Color(0xFFF8FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.diagnosis != null) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Diagnosis: ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextSpan(
                            text: p.diagnosis!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (p.vitals != null) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Baseline Vitals: ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextSpan(
                            text: p.vitals!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (p.prescriptions.isNotEmpty) ...[
                    const Text(
                      'Active Prescriptions:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ...p.prescriptions.map(
                      (rx) => Padding(
                        padding: const EdgeInsets.only(left: 6, top: 1),
                        child: Text(
                          '• ${rx.medicine} (${rx.frequency}, ${rx.duration})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF006A6A), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_information_outlined,
              size: 48,
              color: Color(0xFF006A6A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask any healthcare question grounded in 5,000+ verified MedQuAD & NHP India clinical records.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SUGGESTED QUESTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._suggestions.map((suggestion) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _sendMessage(suggestion),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: Color(0xFF006A6A),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, right: 10),
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ashwini_logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.health_and_safety_rounded,
                    color: Color(0xFF006A6A),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF006A6A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormattedMessageView(
                    text: msg.text,
                    isUser: isUser,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: msg.isSynced
                                ? const Color(0xFFE0F2F1)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            msg.isSynced
                                ? (widget.cloudLlmClient is GeminiCloudLlmClient ? 'Gemini AI' : 'Groq AI')
                                : 'Offline Knowledge',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: msg.isSynced
                                  ? const Color(0xFF006A6A)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, left: 10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF006A6A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF006A6A),
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ashwini_logo.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF006A6A),
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF006A6A)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Consulting medical knowledge...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Ask a medical question...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isGenerating ? null : () => _sendMessage(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isGenerating
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF006A6A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
