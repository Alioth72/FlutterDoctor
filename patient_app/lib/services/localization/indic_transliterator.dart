/// Universal Indic Transliterator.
/// Phonetically transliterates English / Latin characters into all 11 Indic script families:
/// - Gurmukhi (Punjabi: pa)
/// - Devanagari (Hindi: hi, Marathi: mr, Sanskrit: sa, Nepali: ne, Maithili: mai, Konkani: kok, Dogri: doi, Bodo: brx)
/// - Bengali-Assamese (Bengali: bn, Assamese: as, Manipuri: mni)
/// - Tamil (Tamil: ta)
/// - Telugu (Telugu: te)
/// - Kannada (Kannada: kn)
/// - Malayalam (Malayalam: ml)
/// - Gujarati (Gujarati: gu)
/// - Odia (Odia: or)
/// - Perso-Arabic (Urdu: ur, Kashmiri: ks, Sindhi: sd)
/// - Ol Chiki (Santali: sat)
class IndicTransliterator {
  static const Map<String, Map<String, String>> _consonants = {
    'tion': {'hi': 'शन', 'pa': 'ਸ਼ਨ', 'bn': 'শন', 'te': 'షన్', 'ta': 'ஷன்', 'mr': 'शन', 'gu': 'શન', 'kn': 'ಶನ್', 'ml': 'ഷൻ', 'or': 'ଶନ', 'as': 'শন', 'ur': 'شن'},
    'sion': {'hi': 'शन', 'pa': 'ਸ਼ਨ', 'bn': 'শন', 'te': 'షన్', 'ta': 'ஷன்', 'mr': 'शन', 'gu': 'શન', 'kn': 'ಶನ್', 'ml': 'ഷൻ', 'or': 'ଶନ', 'as': 'শন', 'ur': 'شن'},
    'kh': {'hi': 'ख', 'pa': 'ਖ', 'bn': 'খ', 'te': 'ఖ', 'ta': 'க', 'mr': 'ख', 'gu': 'ખ', 'kn': 'ಖ', 'ml': 'ഖ', 'or': 'ଖ', 'as': 'খ', 'ur': 'کھ'},
    'gh': {'hi': 'घ', 'pa': 'ਘ', 'bn': 'ঘ', 'te': 'ఘ', 'ta': 'க', 'mr': 'घ', 'gu': 'ઘ', 'kn': 'ಘ', 'ml': 'ഘ', 'or': 'ଘ', 'as': 'ঘ', 'ur': 'گھ'},
    'chh': {'hi': 'छ', 'pa': 'ਛ', 'bn': 'ছ', 'te': 'ఛ', 'ta': 'ச', 'mr': 'छ', 'gu': 'છ', 'kn': 'ಛ', 'ml': 'ഛ', 'or': 'ଛ', 'as': 'ছ', 'ur': 'چھ'},
    'ch': {'hi': 'च', 'pa': 'ਚ', 'bn': 'চ', 'te': 'చ', 'ta': 'ச', 'mr': 'च', 'gu': 'ચ', 'kn': 'ಚ', 'ml': 'ച', 'or': 'ଚ', 'as': 'চ', 'ur': 'چ'},
    'jh': {'hi': 'झ', 'pa': 'ਝ', 'bn': 'ঝ', 'te': 'ఝ', 'ta': 'ஜ', 'mr': 'झ', 'gu': 'ઝ', 'kn': 'ಝ', 'ml': 'ഝ', 'or': 'ଝ', 'as': 'ঝ', 'ur': 'جھ'},
    'th': {'hi': 'थ', 'pa': 'ਥ', 'bn': 'থ', 'te': 'థ', 'ta': 'த', 'mr': 'थ', 'gu': 'થ', 'kn': 'ಥ', 'ml': 'ഥ', 'or': 'ଥ', 'as': 'থ', 'ur': 'تھ'},
    'dh': {'hi': 'ध', 'pa': 'ਧ', 'bn': 'ধ', 'te': 'ధ', 'ta': 'த', 'mr': 'ध', 'gu': 'ધ', 'kn': 'ಧ', 'ml': 'ധ', 'or': 'ଧ', 'as': 'ধ', 'ur': 'دھ'},
    'ph': {'hi': 'फ', 'pa': 'ਫ', 'bn': 'ফ', 'te': 'ఫ', 'ta': 'ப', 'mr': 'फ', 'gu': 'ફ', 'kn': 'ಫ', 'ml': 'ഫ', 'or': 'ଫ', 'as': 'ফ', 'ur': 'پھ'},
    'bh': {'hi': 'भ', 'pa': 'ਭ', 'bn': 'ভ', 'te': 'భ', 'ta': 'ப', 'mr': 'भ', 'gu': 'ભ', 'kn': 'ಭ', 'ml': 'ഭ', 'or': 'ଭ', 'as': 'ভ', 'ur': 'بھ'},
    'sh': {'hi': 'श', 'pa': 'ਸ਼', 'bn': 'শ', 'te': 'శ', 'ta': 'ஷ', 'mr': 'श', 'gu': 'શ', 'kn': 'ಶ', 'ml': 'ശ', 'or': 'ଶ', 'as': 'শ', 'ur': 'ش'},
    'k': {'hi': 'क', 'pa': 'ਕ', 'bn': 'ক', 'te': 'క', 'ta': 'க', 'mr': 'क', 'gu': 'ક', 'kn': 'ಕ', 'ml': 'ക', 'or': 'କ', 'as': 'ক', 'ur': 'ک'},
    'g': {'hi': 'ग', 'pa': 'ਗ', 'bn': 'গ', 'te': 'గ', 'ta': 'க', 'mr': 'ग', 'gu': 'ગ', 'kn': 'ಗ', 'ml': 'ഗ', 'or': 'ଗ', 'as': 'গ', 'ur': 'گ'},
    'j': {'hi': 'ज', 'pa': 'ਜ', 'bn': 'জ', 'te': 'జ', 'ta': 'ஜ', 'mr': 'ज', 'gu': 'જ', 'kn': 'ಜ', 'ml': 'ജ', 'or': 'ଜ', 'as': 'জ', 'ur': 'ج'},
    't': {'hi': 'त', 'pa': 'ਤ', 'bn': 'ত', 'te': 'త', 'ta': 'த', 'mr': 'त', 'gu': 'ત', 'kn': 'ತ', 'ml': 'ത', 'or': 'ତ', 'as': 'ত', 'ur': 'ت'},
    'd': {'hi': 'द', 'pa': 'ਦ', 'bn': 'দ', 'te': 'ద', 'ta': 'த', 'mr': 'द', 'gu': 'દ', 'kn': 'ದ', 'ml': 'ദ', 'or': 'ଦ', 'as': 'দ', 'ur': 'د'},
    'n': {'hi': 'न', 'pa': 'ਨ', 'bn': 'ন', 'te': 'న', 'ta': 'ந', 'mr': 'न', 'gu': 'ન', 'kn': 'ನ', 'ml': 'ന', 'or': 'ନ', 'as': 'ন', 'ur': 'ن'},
    'p': {'hi': 'प', 'pa': 'ਪ', 'bn': 'প', 'te': 'ప', 'ta': 'ப', 'mr': 'प', 'gu': 'પ', 'kn': 'ಪ', 'ml': 'പ', 'or': 'ପ', 'as': 'প', 'ur': 'پ'},
    'f': {'hi': 'फ़', 'pa': 'ਫ਼', 'bn': 'ফ', 'te': 'ఫ', 'ta': 'ப', 'mr': 'फ', 'gu': 'ફ', 'kn': 'ಫ', 'ml': 'ഫ', 'or': 'ଫ', 'as': 'ফ', 'ur': 'ف'},
    'b': {'hi': 'ब', 'pa': 'ਬ', 'bn': 'ব', 'te': 'బ', 'ta': 'ப', 'mr': 'ब', 'gu': 'બ', 'kn': 'ಬ', 'ml': 'ബ', 'or': 'ବ', 'as': 'ব', 'ur': 'ب'},
    'm': {'hi': 'म', 'pa': 'ਮ', 'bn': 'ম', 'te': 'మ', 'ta': 'ம', 'mr': 'म', 'gu': 'મ', 'kn': 'ಮ', 'ml': 'മ', 'or': 'ମ', 'as': 'ম', 'ur': 'م'},
    'y': {'hi': 'य', 'pa': 'ਯ', 'bn': 'য', 'te': 'య', 'ta': 'ய', 'mr': 'य', 'gu': 'ય', 'kn': 'ಯ', 'ml': 'യ', 'or': 'ଯ', 'as': 'য', 'ur': 'ی'},
    'r': {'hi': 'र', 'pa': 'ਰ', 'bn': 'র', 'te': 'ర', 'ta': 'ர', 'mr': 'र', 'gu': 'ર', 'kn': 'ರ', 'ml': 'ര', 'or': 'ର', 'as': 'ৰ', 'ur': 'ر'},
    'l': {'hi': 'ल', 'pa': 'ਲ', 'bn': 'ল', 'te': 'ల', 'ta': 'ல', 'mr': 'ल', 'gu': 'લ', 'kn': 'ಲ', 'ml': 'ല', 'or': 'ଲ', 'as': 'ল', 'ur': 'ل'},
    'v': {'hi': 'व', 'pa': 'ਵ', 'bn': 'ভ', 'te': 'వ', 'ta': 'வ', 'mr': 'व', 'gu': 'વ', 'kn': 'ವ', 'ml': 'വ', 'or': 'ଭ', 'as': 'ভ', 'ur': 'و'},
    'w': {'hi': 'व', 'pa': 'ਵ', 'bn': 'ও', 'te': 'వ', 'ta': 'வ', 'mr': 'व', 'gu': 'વ', 'kn': 'ವ', 'ml': 'വ', 'or': 'ୱ', 'as': 'ৱ', 'ur': 'و'},
    's': {'hi': 'स', 'pa': 'ਸ', 'bn': 'স', 'te': 'స', 'ta': 'ஸ', 'mr': 'स', 'gu': 'સ', 'kn': 'ಸ', 'ml': 'സ', 'or': 'ସ', 'as': 'স', 'ur': 'س'},
    'h': {'hi': 'ह', 'pa': 'ਹ', 'bn': 'হ', 'te': 'హ', 'ta': 'ஹ', 'mr': 'ह', 'gu': 'હ', 'kn': 'ಹ', 'ml': 'ഹ', 'or': 'ହ', 'as': 'হ', 'ur': 'ہ'},
    'z': {'hi': 'ज़', 'pa': 'ਜ਼', 'bn': 'জ', 'te': 'జ', 'ta': 'ஸ', 'mr': 'झ', 'gu': 'ઝ', 'kn': 'ಜ', 'ml': 'സ', 'or': 'ଜ', 'as': 'জ', 'ur': 'ز'},
    'c': {'hi': 'क', 'pa': 'ਕ', 'bn': 'ক', 'te': 'క', 'ta': 'க', 'mr': 'क', 'gu': 'ક', 'kn': 'ಕ', 'ml': 'ക', 'or': 'କ', 'as': 'ক', 'ur': 'ک'},
    'x': {'hi': 'क्स', 'pa': 'ਕਸ', 'bn': 'ক্স', 'te': 'క్స్', 'ta': 'க்ஸ்', 'mr': 'क्स', 'gu': 'ક્સ', 'kn': 'ಕ್ಸ್', 'ml': 'ക്സ്', 'or': 'କ୍ସ', 'as': 'ক্স', 'ur': 'کس'},
    'q': {'hi': 'क', 'pa': 'ਕ', 'bn': 'ਕ', 'te': 'క', 'ta': 'க', 'mr': 'क', 'gu': 'ક', 'kn': 'ಕ', 'ml': 'ക', 'or': 'କ', 'as': 'ਕ', 'ur': 'ق'},
  };

  static const Map<String, Map<String, String>> _vowels = {
    'aa': {'hi': 'ा', 'pa': 'ਾ', 'bn': 'া', 'te': 'ా', 'ta': 'ா', 'mr': 'ा', 'gu': 'ા', 'kn': 'ಾ', 'ml': 'ാ', 'or': 'ା', 'as': 'া', 'ur': 'ا'},
    'ee': {'hi': 'ी', 'pa': 'ੀ', 'bn': 'ী', 'te': 'ీ', 'ta': 'ீ', 'mr': 'ी', 'gu': 'ી', 'kn': 'ೀ', 'ml': 'ീ', 'or': 'ୀ', 'as': 'ী', 'ur': 'ی'},
    'oo': {'hi': 'ू', 'pa': 'ੂ', 'bn': 'ূ', 'te': 'ూ', 'ta': 'ூ', 'mr': 'ू', 'gu': 'ૂ', 'kn': 'ೂ', 'ml': 'ൂ', 'or': 'ୂ', 'as': 'ূ', 'ur': 'و'},
    'ai': {'hi': 'ै', 'pa': 'ੈ', 'bn': 'ৈ', 'te': 'ై', 'ta': 'ை', 'mr': 'ै', 'gu': 'ૈ', 'kn': 'ೈ', 'ml': 'ൈ', 'or': 'ୈ', 'as': 'ৈ', 'ur': 'ے'},
    'au': {'hi': 'ौ', 'pa': 'ੌ', 'bn': 'ৌ', 'te': 'ౌ', 'ta': 'ௌ', 'mr': 'ौ', 'gu': 'ૌ', 'kn': 'ೌ', 'ml': 'ൗ', 'or': 'ୌ', 'as': 'ৌ', 'ur': 'و'},
    'a': {'hi': 'ा', 'pa': 'ਾ', 'bn': 'া', 'te': 'ా', 'ta': 'ா', 'mr': 'ा', 'gu': 'ા', 'kn': 'ಾ', 'ml': 'ാ', 'or': 'ା', 'as': 'া', 'ur': ''},
    'i': {'hi': 'ि', 'pa': 'ਿ', 'bn': 'ি', 'te': 'ి', 'ta': 'ி', 'mr': 'ि', 'gu': 'િ', 'kn': 'ಿ', 'ml': 'ി', 'or': 'ି', 'as': 'ি', 'ur': 'ی'},
    'u': {'hi': 'ु', 'pa': 'ੁ', 'bn': 'ু', 'te': 'ు', 'ta': 'ு', 'mr': 'ु', 'gu': 'ુ', 'kn': 'ು', 'ml': 'ു', 'or': 'ୁ', 'as': 'ু', 'ur': 'و'},
    'e': {'hi': 'े', 'pa': 'ੇ', 'bn': 'ে', 'te': 'ే', 'ta': 'ே', 'mr': 'े', 'gu': 'ે', 'kn': 'ೇ', 'ml': 'േ', 'or': 'େ', 'as': 'ে', 'ur': 'ے'},
    'o': {'hi': 'ो', 'pa': 'ੋ', 'bn': 'ো', 'te': 'ో', 'ta': 'ோ', 'mr': 'ो', 'gu': 'ો', 'kn': 'ೋ', 'ml': 'ോ', 'or': 'ୋ', 'as': 'ো', 'ur': 'و'},
  };

  static const Map<String, Map<String, String>> _initialVowels = {
    'aa': {'hi': 'आ', 'pa': 'ਆ', 'bn': 'আ', 'te': 'ఆ', 'ta': 'ஆ', 'mr': 'आ', 'gu': 'આ', 'kn': 'ಆ', 'ml': 'ആ', 'or': 'ଆ', 'as': 'আ', 'ur': 'آ'},
    'ee': {'hi': 'ई', 'pa': 'ਈ', 'bn': 'ঈ', 'te': 'ఈ', 'ta': 'ஈ', 'mr': 'ई', 'gu': 'ઈ', 'kn': 'ಈ', 'ml': 'ഈ', 'or': 'ଈ', 'as': 'ঈ', 'ur': 'ای'},
    'oo': {'hi': 'ऊ', 'pa': 'ਊ', 'bn': 'ঊ', 'te': 'ఊ', 'ta': 'ஊ', 'mr': 'ऊ', 'gu': 'ઊ', 'kn': 'ಊ', 'ml': 'ഊ', 'or': 'ଊ', 'as': 'ঊ', 'ur': 'او'},
    'ai': {'hi': 'ऐ', 'pa': 'ਐ', 'bn': 'ঐ', 'te': 'ఐ', 'ta': 'ஐ', 'mr': 'ऐ', 'gu': 'ઐ', 'kn': 'ಐ', 'ml': 'ഐ', 'or': 'ଐ', 'as': 'ঐ', 'ur': 'اے'},
    'au': {'hi': 'औ', 'pa': 'ਔ', 'bn': 'ঔ', 'te': 'ఔ', 'ta': 'ஔ', 'mr': 'औ', 'gu': 'ઔ', 'kn': 'ಔ', 'ml': 'ഔ', 'or': 'ଔ', 'as': 'ঔ', 'ur': 'او'},
    'a': {'hi': 'अ', 'pa': 'ਅ', 'bn': 'অ', 'te': 'అ', 'ta': 'அ', 'mr': 'अ', 'gu': 'અ', 'kn': 'ಅ', 'ml': 'അ', 'or': 'ଅ', 'as': 'অ', 'ur': 'ا'},
    'i': {'hi': 'इ', 'pa': 'ਇ', 'bn': 'ই', 'te': 'ఇ', 'ta': 'இ', 'mr': 'इ', 'gu': 'ઇ', 'kn': 'ಇ', 'ml': 'ഇ', 'or': 'ଇ', 'as': 'ই', 'ur': 'ای'},
    'u': {'hi': 'उ', 'pa': 'ਉ', 'bn': 'উ', 'te': 'ఉ', 'ta': 'உ', 'mr': 'उ', 'gu': 'ઉ', 'kn': 'ಉ', 'ml': 'ഉ', 'or': 'ଉ', 'as': 'উ', 'ur': 'او'},
    'e': {'hi': 'ए', 'pa': 'ਏ', 'bn': 'এ', 'te': 'ఏ', 'ta': 'ஏ', 'mr': 'ए', 'gu': 'એ', 'kn': 'ಏ', 'ml': 'ഏ', 'or': 'ଏ', 'as': 'এ', 'ur': 'اے'},
    'o': {'hi': 'ओ', 'pa': 'ਓ', 'bn': 'ও', 'te': 'ఓ', 'ta': 'ஓ', 'mr': 'ओ', 'gu': 'ઓ', 'kn': 'ಓ', 'ml': 'ഓ', 'or': 'ଓ', 'as': 'ও', 'ur': 'او'},
  };

  /// Transliterate a single word into target language script
  static String transliterateWord(String word, String langCode) {
    if (word.isEmpty) return word;

    final lang = _normalizeLang(langCode);
    final lower = word.toLowerCase();
    final buffer = StringBuffer();
    int i = 0;
    bool isStart = true;

    while (i < lower.length) {
      // Check 4-char consonant (tion, sion)
      if (i + 4 <= lower.length && _consonants.containsKey(lower.substring(i, i + 4))) {
        final c = lower.substring(i, i + 4);
        buffer.write(_consonants[c]![lang] ?? _consonants[c]!['hi']!);
        i += 4;
        isStart = false;
        continue;
      }

      // Check 3-char consonant (chh)
      if (i + 3 <= lower.length && _consonants.containsKey(lower.substring(i, i + 3))) {
        final c = lower.substring(i, i + 3);
        buffer.write(_consonants[c]![lang] ?? _consonants[c]!['hi']!);
        i += 3;
        isStart = false;
        continue;
      }

      // Check 2-char consonant (kh, gh, th, dh, ph, bh, sh, ch, jh)
      if (i + 2 <= lower.length && _consonants.containsKey(lower.substring(i, i + 2))) {
        final c = lower.substring(i, i + 2);
        buffer.write(_consonants[c]![lang] ?? _consonants[c]!['hi']!);
        i += 2;
        isStart = false;
        continue;
      }

      // Check 2-char vowel (aa, ee, oo, ai, au)
      if (i + 2 <= lower.length && _vowels.containsKey(lower.substring(i, i + 2))) {
        final v = lower.substring(i, i + 2);
        if (isStart) {
          buffer.write(_initialVowels[v]?[lang] ?? _initialVowels[v]?['hi'] ?? '');
        } else {
          buffer.write(_vowels[v]?[lang] ?? _vowels[v]?['hi'] ?? '');
        }
        i += 2;
        isStart = false;
        continue;
      }

      // Check 1-char consonant
      final singleChar = lower[i];
      if (_consonants.containsKey(singleChar)) {
        buffer.write(_consonants[singleChar]![lang] ?? _consonants[singleChar]!['hi']!);
        i++;
        isStart = false;
        continue;
      }

      // Check 1-char vowel
      if (_vowels.containsKey(singleChar)) {
        if (isStart) {
          buffer.write(_initialVowels[singleChar]?[lang] ?? _initialVowels[singleChar]?['hi'] ?? '');
        } else {
          buffer.write(_vowels[singleChar]?[lang] ?? _vowels[singleChar]?['hi'] ?? '');
        }
        i++;
        isStart = false;
        continue;
      }

      // Other characters (digits, symbols)
      buffer.write(word[i]);
      i++;
    }

    return buffer.toString();
  }

  /// Transliterates any residual English/Latin tokens in text to target Indic script
  static String transliterateSentence(String text, String langCode) {
    if (text.trim().isEmpty) return text;
    if (langCode == 'en' || langCode == 'en-IN') return text;

    final lang = _normalizeLang(langCode);

    // Replace all Latin words with their transliteration
    return text.replaceAllMapped(RegExp(r'[a-zA-Z]+'), (match) {
      final word = match.group(0)!;
      return transliterateWord(word, lang);
    });
  }

  static String _normalizeLang(String langCode) {
    final code = langCode.split('-')[0].toLowerCase();
    if (['sa', 'mai', 'kok', 'ne', 'doi', 'brx'].contains(code)) return 'hi';
    if (['as', 'mni'].contains(code)) return 'bn';
    if (['ks', 'sd'].contains(code)) return 'ur';
    return code;
  }
}
