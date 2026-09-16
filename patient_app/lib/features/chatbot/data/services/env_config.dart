import 'package:flutter/services.dart' show rootBundle;

/// Runtime environment configuration service that parses `.env` files from assets
/// and provides fallback support for `--dart-define` compilation flags.
class EnvConfig {
  static final Map<String, String> _env = {};
  static bool _initialized = false;

  /// Loads and parses the `.env` asset file if available.
  /// Safe to call multiple times; if `.env` does not exist, fails silently.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final content = await rootBundle.loadString('.env');
      _parseEnv(content);
    } catch (_) {
      // Gracefully continue if .env is missing (e.g., CI/CD or fresh clone)
    } finally {
      _initialized = true;
    }
  }

  /// Parses raw dotenv string content into key-value map.
  static void _parseEnv(String content) {
    final lines = content.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final equalsIndex = line.indexOf('=');
      if (equalsIndex > 0) {
        final key = line.substring(0, equalsIndex).trim();
        var value = line.substring(equalsIndex + 1).trim();

        // Strip surrounding matching single or double quotes
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          if (value.length >= 2) {
            value = value.substring(1, value.length - 1);
          }
        }

        _env[key] = value;
      }
    }
  }

  /// Retrieves an environment variable by [key], returning [fallback] if not found.
  static String get(String key, {String fallback = ''}) {
    return _env[key] ?? fallback;
  }

  /// Allows setting or overriding an environment variable in-memory at runtime.
  static void set(String key, String value) {
    _env[key] = value.trim();
  }

  /// Groq Cloud API Key with fallback to `--dart-define=GROQ_API_KEY=...`
  static String get groqApiKey {
    final val = _env['GROQ_API_KEY'];
    if (val != null && val.trim().isNotEmpty) return val.trim();
    return const String.fromEnvironment('GROQ_API_KEY').trim();
  }

  /// Gemini Cloud API Key with fallback to `--dart-define=GEMINI_API_KEY=...`
  static String get geminiApiKey {
    final val = _env['GEMINI_API_KEY'];
    if (val != null && val.trim().isNotEmpty) return val.trim();
    return const String.fromEnvironment('GEMINI_API_KEY').trim();
  }

  /// Sarvam Cloud API Key with fallback to `--dart-define=SARVAM_API_KEY=...`
  static String get sarvamApiKey {
    final val = _env['SARVAM_API_KEY'];
    if (val != null && val.trim().isNotEmpty) return val.trim();
    return const String.fromEnvironment('SARVAM_API_KEY').trim();
  }
}
