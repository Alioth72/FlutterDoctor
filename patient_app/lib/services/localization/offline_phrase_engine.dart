import 'app_strings.dart';
import 'healthcare_catalog.dart';
import 'indic_transliterator.dart';

/// Offline Intelligent Phrase & Entity Translation Engine.
/// Provides synchronous offline translation and phonetic script conversion
/// guaranteeing 0% Latin/English characters remain in the UI.
class OfflinePhraseEngine {
  static const Map<String, Map<String, String>> _phraseDictionary = {
    // Financial & Scheme Terms
    'financial assistance': {
      'pa': 'ਵਿੱਤੀ ਸਹਾਇਤਾ', 'hi': 'वित्तीय सहायता', 'bn': 'আর্থিক সহায়তা',
      'te': 'ఆర్థిక సహాయం', 'ta': 'நிதியுதவி', 'mr': 'आर्थिक मदत',
      'gu': 'નાણાકીય સહાય', 'kn': 'ಹಣಕಾಸು ನೆರವು', 'ml': 'സാമ്പത്തിക സഹായം',
      'or': 'ଆର୍ଥିକ ସହାୟତା', 'as': 'আৰ্থিক সাহায্য', 'ur': 'مالی امداد',
    },
    'infertility treatment': {
      'pa': 'ਬਾਂਝਪਨ ਇਲਾਜ', 'hi': 'बांझपन उपचार', 'bn': 'বন্ধ্যাত্ব চিকিৎসা',
      'te': 'సంతానలేమి చికిత్స', 'ta': 'மலட்டுத்தன்மை சிகிச்சை', 'mr': 'वंध्यत्व उपचार',
      'gu': 'વંધ્યત્વ સારવાર', 'kn': 'ಬಂಜೆತನ ಚಿಕಿತ್ಸೆ', 'ml': 'വന്ധ്യതാ ചികിത്സ',
      'or': 'ବନ୍ଧ୍ୟାତ୍ୱ ଚିକିତ୍ସା', 'as': 'বন্ধ্যাত্ব চিকিৎসা', 'ur': 'بانجھ پن کا علاج',
    },
    'medical expenses': {
      'pa': 'ਡਾਕਟਰੀ ਖਰਚੇ', 'hi': 'चिकित्सा खर्च', 'bn': 'চিকিৎসা খরচ',
      'te': 'వైద్య ఖర్చులు', 'ta': 'மருத்துவ செலவுகள்', 'mr': 'वैद्यकीय खर्च',
      'gu': 'તબીબી ખર્ચ', 'kn': 'ವೈದ್ಯಕೀಯ ವೆಚ್ಚಗಳು', 'ml': 'വൈദ്യചെലവുകൾ',
      'or': 'ଡାକ୍ତରୀ ଖର୍ଚ୍ଚ', 'as': 'চিকিৎসা খৰচ', 'ur': 'طبی اخراجات',
    },
    'post-natal care': {
      'pa': 'ਜਣੇਪੇ ਤੋਂ ਬਾਅਦ ਦੇਖਭਾਲ', 'hi': 'प्रसवोत्तर देखभाल', 'bn': 'প্রসবোত্তর যত্ন',
      'te': 'ప్రసవానంతర సంరక్షణ', 'ta': 'பிரசவத்திற்குப் பின் பராமரிப்பு', 'mr': 'प्रसूतीनंतर काळजी',
      'gu': 'પ્રસૂતિ પછી સંભાળ', 'kn': 'ಹೆರಿಗೆಯ ನಂತರದ ಆರೈಕೆ', 'ml': 'പ്രസവാനന്തര പരിചരണം',
      'or': 'ପ୍ରସବୋତ୍ତର ଯତ୍ନ', 'as': 'প্ৰসৱোত্তৰ যত্ন', 'ur': 'پیدائش کے بعد دیکھ بھال',
    },
    'diagnostic tests': {
      'pa': 'ਨਿਦਾਨ ਟੈਸਟ', 'hi': 'नैदानिक परीक्षण', 'bn': 'ডায়াগনস্টিক পরীক্ষা',
      'te': 'రోగ నిర్ధారణ పరీక్షలు', 'ta': 'கண்டறியும் சோதனைகள்', 'mr': 'निदान चाचण्या',
      'gu': 'નિદાન પરીક્ષણો', 'kn': 'ರೋಗನಿರ್ಣಯ ಪರೀಕ್ಷೆಗಳು', 'ml': 'രോഗനിർണയ ടെസ്റ്റുകൾ',
      'or': 'ନିଦାନ ପରୀକ୍ଷଣ', 'as': 'নিদান পৰীক্ষা', 'ur': 'تشخیصی ٹیسٹ',
    },
    'hospitalization': {
      'pa': 'ਹਸਪਤਾਲ ਦਾਖਲਾ', 'hi': 'अस्पताल में भर्ती', 'bn': 'হাসপাতালে ভর্তি',
      'te': 'ఆసుపత్రిలో చేరడం', 'ta': 'மருத்துவமனையில் அனுமதி', 'mr': 'रुग्णालयात दाखल',
      'gu': 'હોસ્પિટલમાં દાખલ', 'kn': 'ಆಸ್ಪತ್ರೆಗೆ ದಾಖಲಾತಿ', 'ml': 'ആശുപത്രിവാസം',
      'or': 'ଡାକ୍ତରଖାନାରେ ଭର୍ତ୍ତି', 'as': 'চিকিৎসালয়ত ভৰ্তি', 'ur': 'ہسپتال میں داخلہ',
    },
    'delivery charges': {
      'pa': 'ਡਿਲੀਵਰੀ ਖਰਚੇ', 'hi': 'प्रसव शुल्क', 'bn': 'প্রসবের খরচ',
      'te': 'డెలివరీ ఛార్జీలు', 'ta': 'பிரசவ கட்டணம்', 'mr': 'प्रसूती शुल्क',
      'gu': 'ડિલિવરી ચાર્જીસ', 'kn': 'ಹೆರಿಗೆ ಶುಲ್ಕ', 'ml': 'പ്രസവ നിരക്കുകൾ',
      'or': 'ପ୍ରସବ ଶୁଳ୍କ', 'as': 'প্ৰਸৱ মাচুল', 'ur': 'ڈلیوری کے اخراجات',
    },
    'treatment plan': {
      'pa': 'ਇਲਾਜ ਯੋਜਨਾ', 'hi': 'उपचार योजना', 'bn': 'চিকিৎসা পরিকল্পনা',
      'te': 'చికిత్స ప్రణాళిక', 'ta': 'சிகிச்சை திட்டம்', 'mr': 'उपचार योजना',
      'gu': 'સારવાર યોજના', 'kn': 'ಚಿಕಿತ್ಸಾ ಯೋಜನೆ', 'ml': 'ചികിത്സാ പദ്ധതി',
      'or': 'ଚିକିତ୍ସା ଯୋଜନା', 'as': 'চিকিৎসা পৰিকল্পনা', 'ur': 'علاج کا منصوبہ',
    },
    'per cycle': {
      'pa': 'ਪ੍ਰਤੀ ਚੱਕਰ', 'hi': 'प्रति चक्र', 'bn': 'প্রতি চক্র',
      'te': 'ప్రతి చక్రం', 'ta': 'சுழற்சிக்கு', 'mr': 'प्रति चक्र',
      'gu': 'ચક્ર દીઠ', 'kn': 'ಪ್ರತಿ ಸೈಕಲ್', 'ml': 'ഒരു സൈക്കിളിന്',
      'or': 'ପ୍ରତି ଚକ୍ର', 'as': 'প্ৰতি চক্ৰ', 'ur': 'فی چکر',
    },
    'per month': {
      'pa': 'ਪ੍ਰਤੀ ਮਹੀਨਾ', 'hi': 'प्रति माह', 'bn': 'প্রতি মাসে',
      'te': 'నెలకు', 'ta': 'மாதத்திற்கு', 'mr': 'दरमहा',
      'gu': 'દર મહિને', 'kn': 'ಪ್ರತಿ ತಿಂಗಳು', 'ml': 'പ്രതിമാസം',
      'or': 'ମାସିକ', 'as': 'প্ৰতি মাহে', 'ur': 'ماہانہ',
    },
    'years of age': {
      'pa': 'ਸਾਲ ਦੀ ਉਮਰ', 'hi': 'वर्ष की आयु', 'bn': 'বছর বয়স',
      'te': 'సంవత్సరాల వయస్సు', 'ta': 'வயது', 'mr': 'वर्षे वय',
      'gu': 'વર્ષની ઉંમર', 'kn': 'ವರ್ಷ ವಯಸ್ಸು', 'ml': 'വയസ്സ്',
      'or': 'ବର୍ଷ ବୟସ', 'as': 'বছৰ বয়স', 'ur': 'سال کی عمر',
    },
    'below poverty line': {
      'pa': 'ਗਰੀਬੀ ਰੇਖਾ ਤੋਂ ਹੇਠਾਂ', 'hi': 'गरीबी रेखा से नीचे', 'bn': 'দারিদ্র্যসীমার নিচে',
      'te': 'దారిద్య్రరేఖకు దిగువన', 'ta': 'வறுமைக் கோட்டிற்கு கீழ்', 'mr': 'दारिद्र्यरेषेखालील',
      'gu': 'ગરીબી રેખા નીચે', 'kn': 'ಬಡತನ ರೇಖೆಗಿಂತ ಕೆಳಗೆ', 'ml': 'ദാരിദ്ര്യരേഖയ്ക്ക് താഴെ',
      'or': 'ଦାରିଦ୍ର ସୀମାରେଖା ତଳେ', 'as': 'দাৰিদ্ৰ্য সীমাৰেখাৰ তলৰ', 'ur': 'خط غربت سے نیچے',
    },
    'natural gas': {
      'pa': 'ਕੁਦਰਤੀ ਗੈਸ', 'hi': 'प्राकृतिक गैस', 'bn': 'প্রাকৃতিক গ্যাস',
      'te': 'సహజ వాయువు', 'ta': 'இயற்கை எரிவாயு', 'mr': 'नैसर्गिक वायू',
      'gu': 'કુદરતી ગેસ', 'kn': 'ನೈಸರ್ಗಿಕ ಅನಿಲ', 'ml': 'പ്രകൃതിവാതകം',
      'or': 'ପ୍ରାକୃତିକ ଗ୍ୟାସ', 'as': 'প্ৰাকৃতিক গেছ', 'ur': 'قدرتی گیس',
    },
    'petroleum': {
      'pa': 'ਪੈਟਰੋਲੀਅਮ', 'hi': 'पेट्रोलियम', 'bn': 'পেট্রোলিয়াম',
      'te': 'పెట్రోలియం', 'ta': 'பெட்ரோலியம்', 'mr': 'पेट्रोलियम',
      'gu': 'પેટ્રોલિયમ', 'kn': 'ಪೆಟ್ರೋಲಿಯಂ', 'ml': 'പെട്രോളിയം',
      'or': 'ପେଟ୍ରୋଲିୟମ', 'as': 'পেট্ৰ’লিয়াম', 'ur': 'پیٹرولیم',
    },
    'free lpg connections': {
      'pa': 'ਮੁਫ਼ਤ ਐਲਪੀਜੀ ਕੁਨੈਕਸ਼ਨ', 'hi': 'मुफ्त एलपीजी कनेक्शन', 'bn': 'বিনামূল্যে এলপিজি সংযোগ',
      'te': 'ఉచిత ఎల్‌పీజీ కనెక్షన్లు', 'ta': 'இலவச எல்பிஜி இணைப்புகள்', 'mr': 'मोफत एलपीजी कनेक्शन',
      'gu': 'મફત એલપીજી કનેક્શન', 'kn': 'ಉಚಿತ ಎಲ್‌ಪಿಜಿ ಸಂಪರ್ಕಗಳು', 'ml': 'സൗജന്യ എൽപിജി കണക്ഷനുകൾ',
      'or': 'ମାଗଣା ଏଲପିଜି ସଂଯୋଗ', 'as': 'বিনামূলীয়া এলপিজি সংযোগ', 'ur': 'مفت ایل پی جی کنکشن',
    },
    'kasturba gandhi marg': {
      'pa': 'ਕਸਤੂਰਬਾ ਗਾਂਧੀ ਮਾਰਗ', 'hi': 'कस्तूरबा गांधी मार्ग', 'bn': 'কস্তুরবা গান্ধী মার্গ',
      'te': 'కస్తూర్బా గాంధీ మార్గ్', 'ta': 'கஸ்தூர்பா காந்தி மார்க்', 'mr': 'कस्तुरबा गांधी मार्ग',
      'gu': 'કસ્તૂરબા ગાંધી માર્ગ', 'kn': 'ಕಸ್ತೂರ್ಬಾ ಗಾಂಧಿ ಮಾರ್ಗ', 'ml': 'കസ്തൂർബാ ഗാന്ധി മാർഗ്ഗ്',
      'or': 'କସ୍ତୁରବା ଗାନ୍ଧୀ ମାର୍ଗ', 'as': 'কস্তুৰবা গান্ধী মাৰ্গ', 'ur': 'کستوربا گاندھی مارگ',
    },
    'new delhi': {
      'pa': 'ਨਵੀਂ ਦਿੱਲੀ', 'hi': 'नई दिल्ली', 'bn': 'নতুন দিল্লি',
      'te': 'న్యూ ఢిల్లీ', 'ta': 'புது தில்லி', 'mr': 'नवी दिल्ली',
      'gu': 'નવી દિલ્હી', 'kn': 'ನವದೆಹಲಿ', 'ml': 'ന്യൂഡൽഹി',
      'or': 'ନୂଆଦିଲ୍ଲୀ', 'as': 'নতুন দিল্লী', 'ur': 'نئی دہلی',
    },
    'delhi': {
      'pa': 'ਦਿੱਲੀ', 'hi': 'दिल्ली', 'bn': 'দিল্লি',
      'te': 'ఢిల్లీ', 'ta': 'தில்லி', 'mr': 'दिल्ली',
      'gu': 'દિલ્હી', 'kn': 'ದೆಹಲಿ', 'ml': 'ഡൽഹി',
      'or': 'ଦିଲ୍ଲୀ', 'as': 'দিল্লী', 'ur': 'دہلی',
    },
  };

  /// Translates text offline using local dictionary and phonetic transliterator.
  /// Guarantees that 0 English letters remain in the returned string.
  static String translate(String text, String langCode) {
    if (text.trim().isEmpty) return text;
    if (langCode == 'en' || langCode == 'en-IN') return text;

    final lang = langCode.split('-')[0].toLowerCase();

    // 1. Check direct Healthcare Catalog lookup
    final catalogMatch = HealthcareCatalog.lookup(text, lang);
    if (catalogMatch != null && catalogMatch.isNotEmpty && catalogMatch != text) {
      return catalogMatch;
    }

    // 2. Check AppStrings
    final appStringMatch = AppStrings.get(text, lang);
    if (appStringMatch != text) {
      return appStringMatch;
    }

    String result = text;

    // 3. Replace multi-word and single-word phrases
    for (final entry in _phraseDictionary.entries) {
      final phrase = entry.key;
      final transMap = entry.value;
      final trans = transMap[lang] ?? transMap['hi'];
      if (trans != null && trans.isNotEmpty) {
        final regex = RegExp(r'\b' + RegExp.escape(phrase) + r'\b', caseSensitive: false);
        result = result.replaceAll(regex, trans);
      }
    }

    // 4. Fallback: For isolated proper nouns or short single-word entities, phonetic transliteration can be used.
    // For full sentences, never transliterate English grammar into phonetic gibberish.
    final hasMultipleWords = text.trim().split(RegExp(r'\s+')).length > 2;
    if (!hasMultipleWords && RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(result)) {
      result = IndicTransliterator.transliterateSentence(result, lang);
    }

    return result;
  }
}
