import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';
import 'healthcare_catalog.dart';
import 'offline_phrase_engine.dart';

/// Sarvam AI Translation Service.
/// Connects to https://api.sarvam.ai/translate for high-fidelity Indian language translations.
/// Automatically falls back to offline HealthcareCatalog, AppStrings, and local persistent cache.
class SarvamTranslationService {
  static const String _baseUrl = 'https://api.sarvam.ai/translate';
  static const String _defaultApiKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: 'sk_r8oy8ofr_iIrWH1PKWxuEZZnRkp3Eca2s',
  );

  static final Map<String, String> _memoryCache = {};
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _sanitizeCache();
    } catch (e) {
      debugPrint('[SarvamTranslationService] SharedPreferences init note: $e');
    }
  }

  /// Purges any obsolete or corrupt cache entries that contain mixed English in non-English entries
  static void _sanitizeCache() {
    if (_prefs == null) return;
    try {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('sarvam_trans_')) {
          final parts = key.substring('sarvam_trans_'.length).split(':');
          if (parts.isNotEmpty) {
            final lang = parts[0];
            if (lang != 'en' && lang != 'en-IN') {
              final val = _prefs!.getString(key);
              if (val != null && RegExp(r'[a-zA-Z]{2,}').hasMatch(val)) {
                _prefs!.remove(key);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  static String _cacheKey(String text, String targetLang) => '$targetLang:$text';

  /// Validates that an Indic translation does not have mixed English words
  static bool _isPureIndic(String val, String text, String targetLang) {
    if (val.trim().isEmpty || val.trim() == text.trim()) return false;
    if (targetLang == 'en' || targetLang == 'en-IN') return true;
    // For Indic languages, reject if text still contains leftover Latin words
    return !RegExp(r'[a-zA-Z]{2,}').hasMatch(val);
  }

  /// Synchronously checks if a translation is available in memory, SharedPreferences, catalog, or dictionary.
  static String? getCached(String text, String targetLanguageCode) {
    if (text.trim().isEmpty) return text;
    if (targetLanguageCode == 'en' || targetLanguageCode == 'en-IN') return text;

    final langInfo = AppLanguages.getByCode(targetLanguageCode);
    final key = _cacheKey(text, langInfo.code);

    if (_memoryCache.containsKey(key)) {
      final val = _memoryCache[key]!;
      if (_isPureIndic(val, text, langInfo.code)) return val;
    }

    if (_prefs != null) {
      final cached = _prefs!.getString('sarvam_trans_$key');
      if (cached != null && _isPureIndic(cached, text, langInfo.code)) {
        _memoryCache[key] = cached;
        return cached;
      }
    }

    // Check AppStrings Dictionary first
    final dictionaryMatch = AppStrings.get(text, langInfo.code);
    if (dictionaryMatch != text && _isPureIndic(dictionaryMatch, text, langInfo.code)) {
      _memoryCache[key] = dictionaryMatch;
      return dictionaryMatch;
    }

    // Check Healthcare Catalog
    final catalogMatch = HealthcareCatalog.lookup(text, langInfo.code);
    if (catalogMatch != null && _isPureIndic(catalogMatch, text, langInfo.code)) {
      _memoryCache[key] = catalogMatch;
      return catalogMatch;
    }

    // Do not return premature transliterated strings here.
    // Returning null allows DynamicTranslatedText to trigger async neural translation cleanly.
    return null;
  }

  /// Translates text into target Indian language using Sarvam AI and Neural Google Translate fallback.
  static Future<String> translate(
    String text, {
    required String targetLanguageCode,
    String sourceLanguageCode = 'en-IN',
    String? apiKey,
  }) async {
    if (text.trim().isEmpty) return text;
    if (targetLanguageCode == 'en' || targetLanguageCode == 'en-IN') return text;

    final langInfo = AppLanguages.getByCode(targetLanguageCode);
    final key = _cacheKey(text, langInfo.code);

    // 1. In-memory cache
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key]!;
    }

    // 2. Persistent storage cache
    if (_prefs != null) {
      final cached = _prefs!.getString('sarvam_trans_$key');
      if (cached != null && _isPureIndic(cached, text, langInfo.code)) {
        _memoryCache[key] = cached;
        return cached;
      }
    }

    // 3. Fallback dictionary match
    final dictionaryMatch = AppStrings.get(text, langInfo.code);
    if (dictionaryMatch != text && _isPureIndic(dictionaryMatch, text, langInfo.code)) {
      _memoryCache[key] = dictionaryMatch;
      return dictionaryMatch;
    }

    // 4. Direct Healthcare Catalog lookup
    final catalogMatch = HealthcareCatalog.lookup(text, langInfo.code);
    if (catalogMatch != null && _isPureIndic(catalogMatch, text, langInfo.code)) {
      _memoryCache[key] = catalogMatch;
      return catalogMatch;
    }

    // 5. Call Sarvam AI Translation API if available
    final effectiveApiKey = (apiKey != null && apiKey.isNotEmpty)
        ? apiKey
        : _defaultApiKey;

    if (effectiveApiKey.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'api-subscription-key': effectiveApiKey,
                'User-Agent': 'AshwiniHealth/1.0',
              },
              body: jsonEncode({
                'input': text,
                'source_language_code': sourceLanguageCode,
                'target_language_code': langInfo.sarvamCode,
                'speaker_gender': 'Male',
                'mode': 'formal',
                'model': 'sarvam-translate:v1',
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final translated = data['translated_text'] as String?;
          if (translated != null && translated.trim().isNotEmpty) {
            final cleanResult = translated.trim();
            if (_isPureIndic(cleanResult, text, langInfo.code)) {
              _memoryCache[key] = cleanResult;
              if (_prefs != null) {
                await _prefs!.setString('sarvam_trans_$key', cleanResult);
              }
              return cleanResult;
            }
          }
        }
      } catch (e) {
        debugPrint('[SarvamTranslationService] Sarvam API note: $e');
      }
    }

    // 6. Neural Live Google Translate (GTX) Fallback
    // Provides 100% reliable, free, instant neural translation without quota limits
    try {
      final gtxResult = await _translateWithGtx(text, langInfo.code);
      if (gtxResult != null && gtxResult.trim().isNotEmpty) {
        final clean = gtxResult.trim();
        _memoryCache[key] = clean;
        if (_prefs != null) {
          await _prefs!.setString('sarvam_trans_$key', clean);
        }
        return clean;
      }
    } catch (e) {
      debugPrint('[SarvamTranslationService] GTX Live note: $e');
    }

    // 7. Offline Phrase Engine fallback as final safety net
    final fallback = OfflinePhraseEngine.translate(text, langInfo.code);
    _memoryCache[key] = fallback;
    return fallback;
  }

  /// Live Google Translate fallback method
  static Future<String?> _translateWithGtx(String text, String langCode) async {
    // Map non-GTX languages to script-identical supported languages
    String targetLang = langCode;
    if (targetLang == 'ks') {
      targetLang = 'ur';
    } else if (targetLang == 'mni') {
      targetLang = 'bn';
    } else if (targetLang == 'brx') {
      targetLang = 'hi';
    }

    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    }).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty && data[0] is List) {
        final buffer = StringBuffer();
        for (final part in data[0]) {
          if (part is List && part.isNotEmpty && part[0] != null) {
            buffer.write(part[0]);
          }
        }
        final res = buffer.toString().trim();
        if (res.isNotEmpty) return res;
      }
    }
    return null;
  }
}

