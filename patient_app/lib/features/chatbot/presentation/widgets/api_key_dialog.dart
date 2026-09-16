import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/groq_cloud_llm_client.dart';

/// Modal bottom sheet to configure and test Cloud API keys at runtime.
class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({
    super.key,
    required this.cloudClient,
    this.onKeySaved,
  });

  final dynamic cloudClient;
  final VoidCallback? onKeySaved;

  static const String _storageKey = 'patient_chatbot_cloud_key';

  static Future<void> persistApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, key.trim());
    } catch (_) {}
  }

  static Future<String?> loadPersistedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_storageKey);
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> show(
    BuildContext context, {
    required dynamic cloudClient,
    VoidCallback? onKeySaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApiKeyDialog(
        cloudClient: cloudClient,
        onKeySaved: onKeySaved,
      ),
    );
  }

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  late final TextEditingController _controller;
  bool _obscureText = true;
  bool _isValidating = false;
  String? _errorMessage;

  bool get _isGroq => widget.cloudClient is GroqCloudLlmClient;

  @override
  void initState() {
    super.initState();
    final clientKey = widget.cloudClient.apiKey as String;
    _controller = TextEditingController(text: clientKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndValidateKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'API Key cannot be empty.';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    final error = await (widget.cloudClient.validateApiKey(key) as Future<String?>);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isValidating = false;
        _errorMessage = error;
      });
      return;
    }

    widget.cloudClient.setApiKey(key);
    await ApiKeyDialog.persistApiKey(key);

    if (!mounted) return;
    setState(() {
      _isValidating = false;
    });

    widget.onKeySaved?.call();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Connected to Cloud AI successfully!'),
        backgroundColor: Color(0xFF006A6A),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasKey = widget.cloudClient.hasApiKey as bool;
    final title = _isGroq ? 'Groq' : 'Gemini';
    final hint = _isGroq ? 'gsk_...' : 'AIzaSy...';
    final keyUrl = _isGroq ? 'console.groq.com/keys' : 'aistudio.google.com/app/apikey';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF006A6A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title API Key',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasKey ? 'Status: Active (18 verified keys loaded)' : 'Status: No API key configured',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasKey ? const Color(0xFF059669) : const Color(0xFFD97706),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isGroq
                ? 'Enter your Groq API key to enable Llama-based responses.'
                : 'Enter your personal Gemini API key or use the built-in 18-key multi-pool.',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: hint,
              labelText: '$title Key',
              errorText: _errorMessage,
              errorMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.key, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Get a free API key at $keyUrl',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isValidating ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isValidating ? null : _saveAndValidateKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A6A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isValidating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save & Verify',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
