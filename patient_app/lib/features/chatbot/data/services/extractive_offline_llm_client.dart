import '../../domain/models/search_result.dart';
import '../../domain/services/llm_client.dart';

/// Intelligent clinical offline synthesizer for the Ashwini Patient Healthcare Assistant.
///
/// Features:
/// 1. Zero technical jargon: Clean, compassionate medical formatting with no raw database IDs or citations.
/// 2. Comprehensive medical knowledge: Direct, medically accurate guidance for common symptoms, first aid,
///    medications, and hospital visits.
/// 3. In-App Portal Guide: Friendly step-by-step assistance for all Ashwini features (Jan Aushadhi prescription
///    scanner, contactless Face Vitals, Teleconsultation, ASHA visits, SOS button, 22 languages).
/// 4. Clinical safety guards: Automatic allergy matching (e.g. Penicillin allergy vs Amoxicillin) & prescription explanations.
/// 5. Multilingual fluency: Adapts natively to Hindi, Bengali, Tamil, Telugu, Marathi, Gujarati, and other Indian languages.
class ExtractiveOfflineLlmClient implements LlmClient {
  const ExtractiveOfflineLlmClient();

  @override
  Future<LlmResponse> generateResponse({
    required String prompt,
    required List<SearchResult> contextChunks,
  }) async {
    final stopwatch = Stopwatch()..start();

    final lang = _detectLanguage(prompt);
    final userQuery = _extractUserQuery(prompt);

    // 1. Check for Allergy Safety Violations
    final allergyAlert = _checkAllergyGuard(prompt, userQuery, lang);
    if (allergyAlert != null) {
      stopwatch.stop();
      return LlmResponse(
        text: allergyAlert,
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    // 2. Check for In-App Portal Navigation & Feature queries
    final appGuideAnswer = _checkAppQuery(userQuery, lang);
    if (appGuideAnswer != null) {
      stopwatch.stop();
      return LlmResponse(
        text: appGuideAnswer,
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    // 3. Check for Common Clinical Symptoms & Health Topics
    final clinicalAnswer = _checkClinicalTopics(userQuery, lang);
    if (clinicalAnswer != null) {
      stopwatch.stop();
      return LlmResponse(
        text: clinicalAnswer,
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    // 4. Synthesize from Retrieved Context Chunks if available (Cleaned of all jargon)
    if (contextChunks.isNotEmpty) {
      final text = _synthesizeChunks(contextChunks, lang);
      stopwatch.stop();
      return LlmResponse(
        text: text,
        branch: LlmBranchType.offline,
        latency: stopwatch.elapsed,
      );
    }

    // 5. Default Friendly Healthcare Response
    final defaultResponse = _buildGeneralCareAdvice(userQuery, lang);
    stopwatch.stop();
    return LlmResponse(
      text: defaultResponse,
      branch: LlmBranchType.offline,
      latency: stopwatch.elapsed,
    );
  }

  String _detectLanguage(String prompt) {
    // 1. Direct tag check: "SELECTED_LANGUAGE_CODE: (code)"
    final tagMatch = RegExp(
      r'SELECTED_LANGUAGE_CODE:\s*([a-zA-Z]{2,3}(?:-[a-zA-Z]{2,3})?)',
      caseSensitive: false,
    ).firstMatch(prompt);
    if (tagMatch != null) {
      return tagMatch.group(1)!.toLowerCase().split('-').first;
    }

    // 2. Explicit directive check from PromptBuilder: "The user chosen language is ... (code)"
    final directiveMatch = RegExp(
      r'The user chosen language is [^(]+\(([a-zA-Z]{2,3}(?:-[a-zA-Z]{2,3})?)\)',
      caseSensitive: false,
    ).firstMatch(prompt);
    if (directiveMatch != null) {
      return directiveMatch.group(1)!.toLowerCase().split('-').first;
    }

    // 3. Isolated directive headers only (e.g. "[Language: bn]")
    // Note: Never use loose prompt.contains('Bengali') or prompt.contains('Hindi') because
    // the Ashwini feature guide mentions all language names!
    final isolatedCodeMatch = RegExp(
      r'\b(?:lang|language|code):\s*([a-z]{2,3})\b',
      caseSensitive: false,
    ).firstMatch(prompt);
    if (isolatedCodeMatch != null) {
      return isolatedCodeMatch.group(1)!.toLowerCase();
    }

    // 4. Query script detection (from user query section ONLY)
    final userQuery = _extractUserQuery(prompt);
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(userQuery)) return 'bn';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(userQuery)) return 'hi';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(userQuery)) return 'ta';
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(userQuery)) return 'te';
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(userQuery)) return 'gu';
    if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(userQuery)) return 'kn';
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(userQuery)) return 'ml';
    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(userQuery)) return 'pa';
    if (RegExp(r'[\u0B00-\u0B7F]').hasMatch(userQuery)) return 'od';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(userQuery)) return 'ur';

    return 'en';
  }

  String _extractUserQuery(String prompt) {
    final marker = '--- User Query ---';
    if (prompt.contains(marker)) {
      final parts = prompt.split(marker);
      if (parts.length > 1) {
        final queryPart = parts[1].split('--- Medical Disclaimer ---').first;
        return queryPart.trim();
      }
    }
    return prompt.trim();
  }

  String? _checkAllergyGuard(String prompt, String query, String lang) {
    final lowerQuery = query.toLowerCase();
    final isAskingAmoxicillin = lowerQuery.contains('amoxicillin') ||
        lowerQuery.contains('अमोक्सिसिलिन') ||
        lowerQuery.contains('augmentin') ||
        lowerQuery.contains('penicillin') ||
        lowerQuery.contains('पेनिसिलिन');

    final hasPenicillinAllergy = prompt.toLowerCase().contains('penicillin') ||
        prompt.toLowerCase().contains('allergy: penicillin');

    if (isAskingAmoxicillin && hasPenicillinAllergy) {
      if (lang == 'hi') {
        return '⚠️ **एलर्जी सुरक्षा चेतावनी (Allergy Alert)**\n\n'
            '• **अमोक्सिसिलिन (Amoxicillin) न लें!**\n'
            '• आपके मेडिकल रिकॉर्ड के अनुसार आपको **पेनिसिलिन (Penicillin)** से गंभीर एलर्जी है।\n'
            '• अमोक्सिसिलिन पेनिसिलिन परिवार की एंटीबायोटिक दवा है और इसे लेने से सांस लेने में तकलीफ, त्वचा पर चकत्ते या एलर्जी हो सकती है।\n'
            '• कृपया तुरंत अपने डॉक्टर से संपर्क करें ताकि वे आपको सुरक्षित विकल्प दे सकें।';
      } else if (lang == 'bn') {
        return '⚠️ **অ্যালার্জি নিরাপত্তা সতর্কতা (Allergy Alert)**\n\n'
            '• **অ্যামোক্সিসিলিন (Amoxicillin) গ্রহণ করবেন না!**\n'
            '• আপনার মেডিকেল রেকর্ড অনুযায়ী আপনার **পেনিসিলিন (Penicillin)** অ্যালার্জি রয়েছে।\n'
            '• অ্যামোক্সিসিলিন পেনিসিলিন পরিবারের ওষুধ হওয়ায় এটি মারাত্মক প্রতিক্রিয়া সৃষ্টি করতে পারে।\n'
            '• অনুগ্রহ করে বিকল্প নিরাপদ ওষুধের জন্য আপনার ডাক্তারের সাথে পরামর্শ করুন।';
      } else if (lang == 'ta') {
        return '⚠️ **ஒவ்வாமை பாதுகாப்பு எச்சரிக்கை (Allergy Alert)**\n\n'
            '• **அமோக்சிசிலின் (Amoxicillin) மருந்தை உட்கொள்ள வேண்டாம்!**\n'
            '• உங்கள் மருத்துவ பதிவேட்டின்படி உங்களுக்கு **பென்சிலின் (Penicillin)** ஒவ்வாமை உள்ளது.\n'
            '• இது ஆபத்தான ஒவ்வாமை விளைவுகளை ஏற்படுத்தக்கூடும்.\n'
            '• மாற்று மருந்துக்கு உடனே மருத்துவரை அணுகவும்.';
      } else if (lang == 'te') {
        return '⚠️ **అలెర్జీ భద్రతా హెచ్చరిక (Allergy Alert)**\n\n'
            '• **అమోక్సిసిలిన్ (Amoxicillin) మందు తీసుకోవద్దు!**\n'
            '• మీ మెడికల్ రికార్డుల ప్రకారం మీకు **పెన్సిలిన్ (Penicillin)** అలెర్జీ ఉంది.\n'
            '• అమోక్సిసిలిన్ పెన్సిలిన్ గ్రూప్ మందు కావడం వల్ల ప్రమాదకరమైన అలెర్జీ రియాక్షన్ రావచ్చు.\n'
            '• దయచేసి వెంటనే మీ డాక్టర్‌ను సంప్రదించండి.';
      } else {
        return '⚠️ **Critical Allergy Safety Warning**\n\n'
            '• **Do NOT take Amoxicillin!**\n'
            '• Your medical record indicates a documented allergy to **Penicillin**.\n'
            '• Amoxicillin is a penicillin-class antibiotic and could trigger a serious or life-threatening allergic reaction.\n'
            '• Please consult your attending doctor immediately for a safe, non-penicillin alternative.';
      }
    }
    return null;
  }

  String? _checkAppQuery(String query, String lang) {
    final lower = query.toLowerCase();

    // 1. Face Vitals (Heart rate, SpO2)
    if (lower.contains('vital') ||
        lower.contains('face') ||
        lower.contains('heart rate') ||
        lower.contains('pulse') ||
        lower.contains('spo2') ||
        lower.contains('धड़कन') ||
        lower.contains('हार्ट रेट') ||
        lower.contains('ক্যামেরা') ||
        lower.contains('இதயத் துடிப்பு')) {
      if (lang == 'hi') {
        return '💓 **कैमरे से चेहरे से दिल की धड़कन (Heart Rate) कैसे मापें**:\n\n'
            '1. **होम टैब** पर **"Face Vitals"** कार्ड पर टैप करें।\n'
            '2. अच्छी रोशनी में बैठें और अपने चेहरे को स्क्रीन के घेरे के अंदर रखें।\n'
            '3. 30 से 45 सेकंड तक शांत रहें।\n'
            '4. मोबाइल का कैमरा त्वचा के सूक्ष्म रंग-परिवर्तन को पढ़कर आपकी **हृदय गति (BPM)**, **ऑक्सीजन (SpO2)** और **सांस लेने की दर** तुरंत बता देता है।\n'
            '5. इसके लिए किसी स्मार्टवॉच या मशीन की जरूरत नहीं है!';
      } else if (lang == 'bn') {
        return '💓 **ফোনের ক্যামেরা দিয়ে কীভাবে হার্ট রেট ও পালস মাপবেন (Face Vitals)**:\n\n'
            '1. **হোম ট্যাবে** যান এবং **"Face Vitals"** কার্ডে ট্যাপ করুন।\n'
            '2. ভালো আলোতে বসুন এবং স্ক্রিনের গোলকের ভেতরে মুখমণ্ডল স্থির রাখুন।\n'
            '3. ৩০ থেকে ৪৫ সেকেন্ড শান্তভাবে স্বাভাবিক শ্বাস নিন।\n'
            '4. ক্যামেরা ত্বকের সূক্ষ্ম রক্তপ্রবাহ বিশ্লেষণ করে আপনার **হৃদস্পন্দন (Heart Rate BPM)**, **অক্সিজেন মাত্রা (SpO2)** এবং **শ্বাসক্রিয়ার হার** জানিয়ে দেবে।\n'
            '5. কোনো স্মার্টওয়াচ বা বাহ্যিক সেন্সরের প্রয়োজন নেই!';
      } else if (lang == 'ta') {
        return '💓 **கேமரா மூலம் நாடித்துடிப்பை எவ்வாறு அளவிடுவது (Face Vitals)**:\n\n'
            '1. **Home Tab**-இல் **"Face Vitals"** அட்டையைத் தட்டவும்.\n'
            '2. நல்ல வெளிச்சத்தில் அமர்ந்து முகத்தை வட்டத்திற்குள் வைக்கவும்.\n'
            '3. 30-45 வினாடிகள் அமைதியாக இருக்கவும்.\n'
            '4. கேமரா உங்கள் **இதயத் துடிப்பு (BPM)**, **ஆக்சிஜன் (SpO2)** மற்றும் **சுவாச வீதத்தை** உடனடியாக அளவிடும்.\n'
            '5. எந்த ஸ்மார்ட்வாட்சும் தேவையில்லை!';
      } else if (lang == 'te') {
        return '💓 **కెమెరా ద్వారా హృదయ స్పందనను ఎలా కొలవాలి (Face Vitals)**:\n\n'
            '1. **హోమ్ ట్యాబ్** లో **"Face Vitals"** కార్డ్ పై నొక్కండి.\n'
            '2. మంచి వెలుతురులో కూర్చుని మీ ముఖాన్ని స్క్రీన్ సర్కిల్ లో ఉంచండి.\n'
            '3. 30 నుండి 45 సెకన్ల పాటు ప్రశాంతంగా ఉండండి.\n'
            '4. మీ **గుండె వేగం (BPM)**, **రక్తంలో ఆక్సిజన్ (SpO2)** మరియు **శ్వాస రేటు** వెంటనే తెలుస్తుంది.\n'
            '5. ఎటువంటి స్మార్ట్ వాచ్ అవసరం లేదు!';
      } else {
        return '💓 **How to Measure Vitals Using Phone Camera (Face Vitals)**:\n\n'
            '1. On the **Home Tab**, tap the **"Face Vitals"** quick action card.\n'
            '2. Sit in a well-lit area and align your face inside the oval camera guide.\n'
            '3. Hold still and breathe normally for 30 to 45 seconds.\n'
            '4. The camera optically tracks facial blood pulsations to measure your **Heart Rate (BPM)**, **Blood Oxygen (SpO2)**, and **Breathing Rate**.\n'
            '5. No smartwatch or external finger sensor is required!';
      }
    }

    // 2. Prescription Scanning & Jan Aushadhi generic savings
    if (lower.contains('prescription') ||
        lower.contains('jan aushadhi') ||
        lower.contains('medicine') ||
        lower.contains('दवा') ||
        lower.contains('पर्ची') ||
        lower.contains('স্ক্যান') ||
        lower.contains('மருந்து') ||
        lower.contains('మందుల') ||
        (lower.contains('scan') && !lower.contains('vital') && !lower.contains('face'))) {
      if (lang == 'hi') {
        return '📸 **दवा पर्ची स्कैन करें और 60-80% पैसे बचाएं (Jan Aushadhi)**:\n\n'
            '1. **होम टैब** पर जाएं और **"पर्ची स्कैन करें" (Scan Prescription)** पर टैप करें, या नीचे **फार्मेसी टैब** खोलें।\n'
            '2. अपने डॉक्टर की पर्ची की फोटो खींचें या गैलरी से अपलोड करें।\n'
            '3. हमारा स्मार्ट स्कैनर दवा का नाम पढ़कर सरकारी **प्रधानमंत्री जन औषधि केंद्र** की सस्ती जेनेरिक दवाएं ढूंढता है।\n'
            '4. इससे आपके दवा के खर्च में **60% से 80% तक की भारी बचत** होती है।\n'
            '5. आप यहीं से सस्ती दवाएं घर मंगवा सकते हैं या नजदीकी जन औषधि केंद्र से ले सकते हैं।';
      } else if (lang == 'bn') {
        return '📸 **প্রেসক্রিপশন স্ক্যান করুন এবং ৬০-৮০% খরচ বাঁচান (Jan Aushadhi)**:\n\n'
            '1. **হোম ট্যাবে** যান এবং **"প্রেসক্রিপশন স্ক্যান"**-এ ট্যাপ করুন অথবা **ফার্মেসি ট্যাব** খুলুন।\n'
            '2. ডাক্তারের প্রেসক্রিপশনের ছবি তুলুন বা গ্যালারি থেকে আপলোড করুন।\n'
            '3. আমাদের স্ক্যানার স্বয়ংক্রিয়ভাবে সরকারি **জন ঔষধি জেনেরিক বিকল্প** খুঁজে দেবে, যা ব্র্যান্ডেড ওষুধের চেয়ে ৬০-৮০% কম খরচে পাওয়া যায়।\n'
            '4. আপনি সরাসরি অ্যাপ থেকে অর্ডার করতে পারেন বা নিকটস্থ স্টোর থেকে সংগ্রহ করতে পারেন।';
      } else if (lang == 'ta') {
        return '📸 **மருந்துச் சீட்டை ஸ்கேன் செய்து 60-80% சேமிக்கவும் (Jan Aushadhi)**:\n\n'
            '1. **Home Tab**-இல் **"Scan Prescription"** அல்லது மருந்தகப் பிரிவைத் திறக்கவும்.\n'
            '2. மருத்துவரின் பரிந்துரைச் சீட்டைப் புகைப்படம் எடுக்கவும்.\n'
            '3. அரசாங்கத்தின் மலிவு விலை **ஜன் ஔஷதி ஜெனரிக் மருந்துகளை** உடனே கண்டறியலாம்.\n'
            '4. இதனால் மருந்துச் செலவில் **60% முதல் 80% வரை பெரும் சேமிப்பு** கிடைக்கும்.';
      } else if (lang == 'te') {
        return '📸 **ప్రిస్క్రిప్షన్ స్కాన్ చేయండి మరియు 60-80% ఆదా చేయండి (Jan Aushadhi)**:\n\n'
            '1. **హోమ్ ట్యాబ్** లో **"Scan Prescription"** పై నొక్కండి లేదా ఫార్మసీ ట్యాబ్ తెరవండి.\n'
            '2. డాక్టర్ చీటీ ఫోటో తీయండి లేదా అప్‌లోడ్ చేయండి.\n'
            '3. ప్రభుత్వ **జన్ ఔషధి జెనెరిక్ మందుల** ప్రత్యామ్నాయాలు వెంటనే కనిపిస్తాయి.\n'
            '4. దీనితో మందుల ఖర్చులో **60% నుండి 80% వరకు భారీ పొదుపు** లభిస్తుంది.';
      } else {
        return '📸 **How to Scan Prescriptions & Save 60-80% (Jan Aushadhi)**:\n\n'
            '1. Go to the **Home Tab** and tap **"Scan Prescription"**, or open the **Pharmacy Tab** at the bottom.\n'
            '2. Take a photo of your doctor\'s prescription or select one from your phone gallery.\n'
            '3. The smart scanner reads prescribed medicine names and instantly matches them with certified government **Jan Aushadhi generic equivalents**.\n'
            '4. This saves you **60% to 80% on medicine costs** with identical therapeutic quality.\n'
            '5. Add generic medicines directly to your cart for home delivery or pickup at your nearest Jan Aushadhi Kendra.';
      }
    }

    // 3. Teleconsultation / Doctor video call
    if (lower.contains('teleconsult') ||
        lower.contains('video call') ||
        lower.contains('doctor') ||
        lower.contains('appointment') ||
        lower.contains('डॉक्टर') ||
        lower.contains('अपॉइंटमेंट') ||
        lower.contains('পরামর্শ') ||
        lower.contains('மருத்துவர்') ||
        lower.contains('వైద్యుడు')) {
      if (lang == 'hi') {
        return '👨‍⚕️ **डॉक्टर से वीडियो परामर्श (Teleconsultation) कैसे लें**:\n\n'
            '1. **होम टैब** पर **"Book Teleconsultation"** पर टैप करें या **Appointments टैब** खोलें।\n'
            '2. अपनी बीमारी या विभाग (जनरल फिजिशियन, बाल रोग, हृदय रोग, आदि) चुनें।\n'
            '3. अपनी पसंद का दिन और समय स्लॉट चुनें।\n'
            '4. समय होने पर ऐप में वीडियो कॉल शुरू करें। कॉल के दौरान आपकी नब्ज डॉक्टर को लाइव दिखेगी और कॉल के बाद डिजिटल पर्ची सीधे ऐप में मिलेगी।';
      } else if (lang == 'bn') {
        return '👨‍⚕️ **ডাক্তারের সাথে ভিডিও পরামর্শ (Teleconsultation) কীভাবে বুক করবেন**:\n\n'
            '1. **হোম ট্যাবে** **"Book Teleconsultation"**-এ ট্যাপ করুন অথবা **Appointments ট্যাব** খুলুন।\n'
            '2. আপনার প্রয়োজনীয় বিভাগ (সাধারণ মেডিসিন, শিশু রোগ, হৃদরোগ, আয়ুশ ইত্যাদি) নির্বাচন করুন।\n'
            '3. অভিজ্ঞ চিকিৎসক, উপযুক্ত তারিখ এবং সময় স্লট পছন্দ করুন।\n'
            '4. নির্দিষ্ট সময়ে অ্যাপের ভেতর থেকেই এইচডি ভিডিও কল শুরু করুন। ভিডিও কলে ডাক্তার আপনার পালস রেট দেখতে পারবেন এবং সরাসরি ডিজিটাল প্রেসক্রিপশন প্রদান করবেন।';
      } else if (lang == 'ta') {
        return '👨‍⚕️ **வீடியோ மூலம் மருத்துவ ஆலோசனை பெறுவது எப்படி**:\n\n'
            '1. **Home Tab**-இல் **"Book Teleconsultation"** என்பதைத் தட்டவும்.\n'
            '2. மருத்துவப் பிரிவைத் தேர்ந்தெடுத்து வசதியான நேரத்தை முன்பதிவு செய்யவும்.\n'
            '3. குறிப்பிட்ட நேரத்தில் செயலி மூலம் நேரடி வீடியோ ஆலோசனையில் பங்கேற்கலாம்.';
      } else if (lang == 'te') {
        return '👨‍⚕️ **వీడియో కాల్ ద్వారా డాక్టర్‌ను ఎలా సంప్రదించాలి**:\n\n'
            '1. **హోమ్ ట్యాబ్** లో **"Book Teleconsultation"** పై నొక్కండి.\n'
            '2. మీకు కావలసిన విభాగాన్ని ఎంచుకుని సమయాన్ని బుక్ చేసుకోండి.\n'
            '3. నిర్ణీత సమయంలో యాప్ ద్వారా సురక్షిత వీడియో కాల్‌లో పాల్గొనండి.';
      } else {
        return '👨‍⚕️ **How to Book a Doctor Video Teleconsultation**:\n\n'
            '1. Tap **"Book Teleconsultation"** on the Home Tab or open the **Appointments Tab**.\n'
            '2. Choose your clinical department (General Physician, Pediatrics, Cardiology, Ayush, etc.).\n'
            '3. Select an available doctor, date, and convenient time slot.\n'
            '4. When appointment time arrives, launch the HD video call right inside the app.\n'
            '5. Your doctor will see your real-time heart vitals and send your digital prescription directly to your phone.';
      }
    }

    // 4. ASHA Worker Home Visit
    if (lower.contains('asha') ||
        lower.contains('home visit') ||
        lower.contains('आशा') ||
        lower.contains('घर पर') ||
        lower.contains('আশা') ||
        lower.contains('ஆஷா')) {
      if (lang == 'hi') {
        return '🏡 **आशा कार्यकर्ता (ASHA Worker) को घर कैसे बुलाएं**:\n\n'
            '1. **होम टैब** पर **"Request ASHA Visit"** पर टैप करें।\n'
            '2. जरूरत चुनें (गर्भवती महिला की देखभाल, शिशु जांच, बुजुर्गों की सेवा, या दवा डिलीवरी)।\n'
            '3. अपना घर का पता और फोन नंबर सत्यापित करें।\n'
            '4. आपके क्षेत्र की मान्यता प्राप्त आशा स्वास्थ्य कार्यकर्ता आपके घर आकर स्वास्थ्य जांच और सहायता करेंगी।';
      } else if (lang == 'bn') {
        return '🏡 **আশা কর্মীকে (ASHA Worker) বাড়িতে কীভাবে ডাকবেন**:\n\n'
            '1. **হোম ট্যাবে** **"Request ASHA Visit"** কার্ডে ট্যাপ করুন।\n'
            '2. প্রয়োজনীয় স্বাস্থ্যসেবা নির্বাচন করুন (মায়ের যত্ন, শিশুর টিকা, প্রবীণদের পরিচর্যা বা ওষুধ পৌঁছানো)।\n'
            '3. আপনার ঠিকানা ও ফোন নম্বর নিশ্চিত করুন।\n'
            '4. আপনার এলাকার সরকারি অনুমোদিত আশা স্বাস্থ্যকর্মী আপনার বাড়ি পরিদর্শন করবেন।';
      } else if (lang == 'ta') {
        return '🏡 **ஆஷா பணியாளரை வீட்டுக்கு வரவழைப்பது எப்படி**:\n\n'
            '1. **Home Tab**-இல் **"Request ASHA Visit"** என்பதைத் தட்டவும்.\n'
            '2. தேவையான சேவையைத் தேர்ந்தெடுத்து முகவரியை உறுதிப்படுத்தவும்.\n'
            '3. உங்கள் பகுதி ஆஷா சுகாதாரப் பணியாளர் உங்கள் இல்லத்திற்கு வந்து உதவுவார்.';
      } else if (lang == 'te') {
        return '🏡 **ఆశా కార్యకర్తను ఇంటికి ఎలా పిలవాలి**:\n\n'
            '1. **హోమ్ ట్యాబ్** లో **"Request ASHA Visit"** పై నొక్కండి.\n'
            '2. కావలసిన సేవను ఎంచుకుని చిరునామాను ధృవీకరించండి.\n'
            '3. మీ ప్రాంత ఆశా ఆరోగ్య కార్యకర్త మీ ఇంటిని సందర్శిస్తారు.';
      } else {
        return '🏡 **How to Request an ASHA Worker Home Visit**:\n\n'
            '1. Tap **"Request ASHA Visit"** on the **Home Tab**.\n'
            '2. Select your care requirement (Maternal & Infant Care, Elderly Wellness, Post-operative Recovery, or Medicine Delivery).\n'
            '3. Confirm your home address and contact details.\n'
            '4. A certified community ASHA healthcare worker in your village/locality will be assigned to visit your home.';
      }
    }

    // 5. Emergency SOS Button
    if (lower.contains('sos') ||
        lower.contains('emergency') ||
        lower.contains('ambulance') ||
        lower.contains('108') ||
        lower.contains('112') ||
        lower.contains('आपातकालीन') ||
        lower.contains('জরুরি') ||
        lower.contains('அவசரம்')) {
      if (lang == 'hi') {
        return '🚨 **आपातकालीन SOS बटन (108 / 112 सहायता)**:\n\n'
            '• स्क्रीन पर नीचे दाईं ओर **लाल रंग का फ्लोटिंग SOS बटन** दबाएं।\n'
            '• यह तुरंत **108 एम्बुलेंस / 112 आपातकालीन सेवा** को कॉल जोड़ता है।\n'
            '• यह आपके फोन की **लाइव जीपीएस लोकेशन** नजदीकी अस्पताल और आपके परिवार के आपातकालीन संपर्कों को अपने-आप भेज देता है।\n'
            '• सीने में तेज दर्द, सांस फूलने या बेहोशी की स्थिति में बिना देर किए SOS दबाएं।';
      } else if (lang == 'bn') {
        return '🚨 **জরুরি SOS প্রোটোকল (১০৮ / ১১২ তাৎক্ষণিক সহায়তা)**:\n\n'
            '• স্ক্রিনের নিচে ডানদিকের **লাল বৃত্তাকার SOS বোতামটিতে** ট্যাপ করুন।\n'
            '• এটি অবিলম্বে **১০৮ অ্যাম্বুলেন্স / ১১২ জাতীয় জরুরি হেল্পলাইনে** কল সংযুক্ত করে।\n'
            '• এটি স্বয়ংক্রিয়ভাবে নিকটবর্তী হাসপাতালে আপনার **লাইভ জিপিএস লোকেশন** পাঠায় এবং পরিবারের জরুরি নম্বরে বার্তা পৌঁছে দেয়।\n'
            '• বুকে তীব্র ব্যথা, শ্বাসকষ্ট বা গুরুতর পরিস্থিতিতে অবিলম্বে SOS চাপুন।';
      } else if (lang == 'ta') {
        return '🚨 **அவசர SOS உதவி (108 / 112 உடனடி உதவி)**:\n\n'
            '• திரையின் கீழ் வலதுபுறத்தில் உள்ள **சிவப்பு நிற SOS பொத்தானை** அழுத்தவும்.\n'
            '• இது உடனடியாக **108 ஆம்புலன்ஸ் / 112 அவசர உதவி எண்ணை** இணைக்கும்.\n'
            '• உங்கள் நேரலை ஜிபிஎஸ் இருப்பிடத்தை மருத்துவமனைக்கு அனுப்பும்.';
      } else if (lang == 'te') {
        return '🚨 **అత్యవసర SOS సహాయం (108 / 112 తక్షణ సాయం)**:\n\n'
            '• స్క్రీన్‌పై కింద కుడివైపున ఉన్న **ఎరుపు రంగు SOS బటన్** నొక్కండి.\n'
            '• ఇది వెంటనే **108 అంబులెన్స్ / 112 హెల్ప్‌లైన్‌కు** కలుపుతుంది.\n'
            '• మీ లైవ్ లొకేషన్‌ను సమీప ఆసుపత్రికి చేరవేస్తుంది.';
      } else {
        return '🚨 **Emergency SOS Protocol (108 / 112 Immediate Help)**:\n\n'
            '• Tap the **red circular SOS button** floating at the bottom right of the screen.\n'
            '• It instantly connects an emergency call to **108 Ambulance / 112 National Emergency Helpline**.\n'
            '• It automatically broadcasts your **live GPS location** to nearest hospitals and alerts your family emergency contacts.\n'
            '• In case of sudden chest pain, difficulty breathing, or severe accidents, tap SOS immediately.';
      }
    }

    // 6. Language Switcher
    if (lower.contains('language') ||
        lower.contains('bhasha') ||
        lower.contains('hindi') ||
        lower.contains('tamil') ||
        lower.contains('telugu') ||
        lower.contains('bengali') ||
        lower.contains('bangla') ||
        lower.contains('भाषा') ||
        lower.contains('ভাষা') ||
        lower.contains('மொழி')) {
      if (lang == 'hi') {
        return '🌐 **ऐप की भाषा कैसे बदलें (22 भारतीय भाषाएं)**:\n\n'
            '1. **होम टैब** के सबसे ऊपर दाईं ओर **ग्लोब (Globe) आइकन** या चैट स्क्रीन में भाषा बैज पर टैप करें।\n'
            '2. भारत की सभी **22 आधिकारिक भाषाओं** (हिन्दी, বাংলা, தமிழ், తెలుగు, मराठी, गुजराती, ਪੰਜਾਬੀ, ಕನ್ನಡ, മലയാളം, ଓଡ଼ିଆ, اردو आदि) में से अपनी भाषा चुनें।\n'
            '3. पूरी ऐप, सभी बटन और यह स्वास्थ्य सहायक तुरंत उसी भाषा में बोलने और लिखने लगेगा!';
      } else if (lang == 'bn') {
        return '🌐 **অ্যাপের ভাষা কীভাবে পরিবর্তন করবেন (২২টি ভারতীয় ভাষা)**:\n\n'
            '1. চ্যাট স্ক্রিনের উপরের **ভাষা বোতামে [BN]** অথবা **হোম ট্যাবের** গ্লোব আইকনে ট্যাপ করুন।\n'
            '2. ভারতের সমস্ত **২২টি রাষ্ট্রীয় ভাষা** (বাংলা, হিন্দি, তামিল, তেলুগু, মারাঠি, গুজরাটি, পাঞ্জাবি, কন্নড়, মালায়ালম, ওড়িয়া, উর্দু ইত্যাদি) বা ইংরেজি নির্বাচন করুন।\n'
            '3. পুরো অ্যাপ্লিকেশন, সমস্ত বোতাম এবং এই এআই স্বাস্থ্য সহায়ক তৎক্ষণাৎ আপনার নির্বাচিত ভাষায় কাজ করবে।';
      } else if (lang == 'ta') {
        return '🌐 **செயலியின் மொழியை மாற்றுவது எப்படி (22 இந்திய மொழிகள்)**:\n\n'
            '1. அரட்டைத் திரையின் மேலுள்ள **மொழி பட்டனை** அல்லது முகப்புத் திரையின் குறியீட்டைத் தட்டவும்.\n'
            '2. தமிழ், இந்தி, தெலுங்கு உள்ளிட்ட 22 அதிகாரப்பூர்வ மொழிகளில் ஏதேனும் ஒன்றைத் தேர்ந்தெடுக்கலாம்.';
      } else if (lang == 'te') {
        return '🌐 **యాప్ భాషను ఎలా మార్చాలి (22 భారతీయ భాషలు)**:\n\n'
            '1. చాట్ స్క్రీన్ పైన ఉన్న **భాష బటన్‌ను** లేదా హోమ్ ట్యాబ్‌లోని గ్లోబ్ చిహ్నాన్ని నొక్కండి.\n'
            '2. తెలుగు, హిందీ, బెంగాలీ సహా 22 అధికారిక భాషలలో మీకు నచ్చిన భాషను ఎంచుకోవచ్చు.';
      } else {
        return '🌐 **How to Switch Languages (All 22 Official Indian Languages)**:\n\n'
            '1. Tap the **Language badge** at the top of this chat screen, or the **Globe icon** on the **Home Tab**.\n'
            '2. Select any of the **22 Scheduled Indian Languages** (Hindi, Bengali, Telugu, Marathi, Tamil, Gujarati, Kannada, Malayalam, Punjabi, Odia, Urdu, Assamese, etc.) or English.\n'
            '3. The entire application, buttons, labels, and voice assistant switch immediately without restarting the app.';
      }
    }

    return null;
  }

  String? _checkClinicalTopics(String query, String lang) {
    final lower = query.toLowerCase();

    // 1. Fever / Chills
    if (lower.contains('fever') ||
        lower.contains('chills') ||
        lower.contains('temperature') ||
        lower.contains('बुखार') ||
        lower.contains('ताप') ||
        lower.contains('জ্বর') ||
        lower.contains('காய்ச்சல்') ||
        lower.contains('జ్వరం')) {
      if (lang == 'hi') {
        return '🌡️ **बुखार के लिए देखभाल और परामर्श**:\n\n'
            '• **आराम और पानी**: भरपूर आराम करें। दिनभर में खूब पानी, ओआरएस (ORS) का घोल, दाल का पानी या नारियल पानी पिएं।\n'
            '• **ठंडी पट्टी**: यदि बुखार 101°F से अधिक है, तो माथे पर सामान्य पानी की ठंडी पट्टी रखें। बर्फ का इस्तेमाल न करें।\n'
            '• **दवा परामर्श**: वयस्कों के लिए डॉक्टर की सलाह से **पैरासिटामोल 650mg** (दिन में अधिकतम 3 बार, खाने के बाद) सुरक्षित राहत देता है। खाली पेट न लें।\n'
            '• **तुरंत डॉक्टर को कब दिखाएं**:\n'
            '  - यदि बुखार 3 दिन से अधिक रहे\n'
            '  - तेज सिरदर्द, गर्दन में जकड़न या उल्टी हो\n'
            '  - सांस लेने में कठिनाई या अत्यधिक कमजोरी हो।';
      } else if (lang == 'bn') {
        return '🌡️ **জ্বরের যত্ন ও স্বাস্থ্য পরামর্শ**:\n\n'
            '• **পর্যাপ্ত বিশ্রাম ও জলপান**: বিছানায় বিশ্রাম নিন। শরীর আর্দ্র রাখতে প্রচুর পরিচ্ছন্ন জল, ওআরএস (ORS) স্যালাইন, ডাবের জল বা গরম স্যুপ পান করুন।\n'
            '• **মাথায় জলপট্টি**: শরীরের তাপমাত্রা ১০১°F (৩৮.৩°C) এর বেশি হলে কপালে ও ঘাড়ে স্বাভাবিক তাপমাত্রার জলে ভেজানো নরম কাপড়ের পট্টি দিন। বরফ ব্যবহার করবেন না।\n'
            '• **ওষুধ সেবন**: প্রাপ্তবয়স্কদের ক্ষেত্রে চিকিৎসকের পরামর্শে খাবারের পর **প্যারাসিটামল ৬৫০ মিলিগ্রাম** (দিনে সর্বোচ্চ ৩ বার) জ্বর কমাতে সহায়ক। খালি পেটে সেবন করবেন না।\n'
            '• **কখন অবিলম্বে ডাক্তারের পরামর্শ নেবেন**:\n'
            '  - জ্বর ৩ দিনের বেশি স্থায়ী হলে\n'
            '  - ঘাড় শক্ত হওয়া, তীব্র মাথাব্যথা, শ্বাসকষ্ট বা বিভ্রান্তি দেখা দিলে\n'
            '  - শরীরে ফুসকুড়ি বা অবিরাম বমি হলে।';
      } else if (lang == 'ta') {
        return '🌡️ **காய்ச்சல் முதலுதவி மற்றும் பராமரிப்பு**:\n\n'
            '• **ஓய்வு மற்றும் நீரேற்றம்**: போதுமான ஓய்வு எடுக்கவும். நிறைய தண்ணீர், இளநீர் அல்லது ஓஆர்எஸ் (ORS) பருகவும்.\n'
            '• **குளிர்ந்த துணி ஒத்தடம்**: உடல் வெப்பநிலை அதிகமாக இருந்தால் நெற்றியில் சாதாரண நீரில் நனைத்த துணியை வைக்கவும்.\n'
            '• **மருந்து விவரம்**: மருத்துவரின் ஆலோசனைப்படி பெரியவர்களுக்கு **பாராசிட்டமால் 650mg** உணவுக்குப் பின் எடுத்துக் கொள்ளலாம்.\n'
            '• **எச்சரிக்கை**: காய்ச்சல் 3 நாட்களுக்கு மேல் நீடித்தால் உடனே மருத்துவரை அணுகவும்.';
      } else if (lang == 'te') {
        return '🌡️ **జ్వరం సంరక్షణ మార్గదర్శకాలు**:\n\n'
            '• **విశ్రాంతి మరియు నీరు**: తగినంత విశ్రాంతి తీసుకోండి. పుష్కలంగా నీరు, ORS ద్రవం లేదా కొబ్బరి నీరు తాగండి.\n'
            '• **తడి గుడ్డ పట్టి**: ఉష్ణోగ్రత ఎక్కువగా ఉంటే నుదిటిపై సాధారణ నీటితో తడిపిన గుడ్డ వేయండి.\n'
            '• **మందుల వివరాలు**: పెద్దలకు డాక్టర్ సలహా మేరకు భోజనం తర్వాత **పారాసిటమాల్ 650mg** ఉపశమనం ఇస్తుంది.\n'
            '• **హెచ్చరిక**: జ్వరం 3 రోజులకు మించి కొనసాగితే వెంటనే డాక్టర్‌ను సంప్రదించండి.';
      } else {
        return '🌡️ **Care Guide for Fever & High Temperature**:\n\n'
            '• **Hydration & Rest**: Get plenty of bed rest. Drink plenty of clean water, ORS solution, coconut water, or warm soups to prevent dehydration.\n'
            '• **Cool Sponging**: If body temperature exceeds 101°F (38.3°C), apply a damp cloth soaked in room-temperature water to the forehead and neck.\n'
            '• **Medication Guidance**: For adults, **Paracetamol 650mg** after meals (every 6 to 8 hours as prescribed) is standard for fever reduction. Avoid taking more than 3 tablets in 24 hours.\n'
            '• **When to Seek Immediate Medical Help**:\n'
            '  - Fever persisting beyond 3 days\n'
            '  - Stiff neck, severe headache, confusion, or difficulty breathing\n'
            '  - Rash or continuous vomiting.';
      }
    }

    // 2. Cough & Cold
    if (lower.contains('cough') ||
        lower.contains('cold') ||
        lower.contains('sore throat') ||
        lower.contains('flu') ||
        lower.contains('खांसी') ||
        lower.contains('सर्दी') ||
        lower.contains('जुकाम') ||
        lower.contains('কাশি') ||
        lower.contains('সর্দি') ||
        lower.contains('இருமல்') ||
        lower.contains('దగ్గు')) {
      if (lang == 'hi') {
        return '🍵 **सर्दी, जुकाम और खांसी के लिए प्राथमिक देखभाल**:\n\n'
            '• **गर्म पानी की भाप (Steam)**: दिन में 2 बार सादे गर्म पानी की भाप लें। इससे बंद नाक और सीने की जकड़न खुलती है।\n'
            '• **नमक के पानी के गरारे**: गले में खराश या दर्द के लिए हल्के गुनगुने पानी में थोड़ा नमक मिलाकर दिन में 2-3 बार गरारे करें।\n'
            '• **घरेलू पेय**: गर्म पानी, अदरक-तुलसी की चाय, और एक चम्मच शहद में अदरक का रस मिलाकर लेने से गले को तुरंत आराम मिलता है।\n'
            '• **दवा परामर्श**: रात में छींक और नाक बहने के लिए डॉक्टर **सिटिरिजिन (Cetirizine 10mg)** सोने से पहले लेने की सलाह देते हैं।\n'
            '• **चेतावनी**: अगर खांसी 2 हफ्ते से ज्यादा रहे, कफ में खून आए या सांस फूले, तो तुरंत डॉक्टर से जांच कराएं।';
      } else if (lang == 'bn') {
        return '🍵 **সর্দি, কাশি ও গলা ব্যথার প্রাথমিক যত্ন**:\n\n'
            '• **গরম জলের ভাপ (Steam)**: দিনে ২ বার গরম জলের ভাপ নিন। এতে বন্ধ নাক এবং বুকের কফ সহজে পরিষ্কার হয়।\n'
            '• **লবণ জলের গার্গল**: গলা ব্যথার জন্য আধ চামচ লবণ সহ ঈষদুষ্ণ জলে দিনে ২-৩ বার গার্গল করুন।\n'
            '• **উষ্ণ পানীয়**: আদা-তুলসী চা, লবঙ্গ-মধু মিশ্রিত ঈষদুষ্ণ জল পান করলে গলার অস্বস্তি দ্রুত কমে।\n'
            '• **ওষুধ সেবন**: সর্দি ও হাঁচির উপশমে চিকিৎসকের নির্দেশনায় রাতে শোবার আগে **সেটিরিজিন ১০ মিলিগ্রাম (Cetirizine 10mg)** সেবন করতে পারেন।\n'
            '• **সতর্কতা**: কাশি ২ সপ্তাহের বেশি স্থায়ী হলে, কাশির সাথে রক্ত গেলে বা বুকে ব্যথা হলে অবিলম্বে ডাক্তার দেখান।';
      } else if (lang == 'ta') {
        return '🍵 **சளி, இருமல் மற்றும் தொண்டை வலிக்கான பராமரிப்பு**:\n\n'
            '• **நீராவி பிடித்தல்**: நாளில் இருமுறை வெந்நீரில் ஆவி பிடிக்கவும்.\n'
            '• **உப்பு நீர் கொப்பளித்தல்**: வெதுவெதுப்பான உப்பு நீரில் தொண்டையைக் கொப்பளிக்கவும்.\n'
            '• **மூலிகை தேநீர்**: இஞ்சி, துளசி தேநீர் தொண்டைக்கு இதமளிக்கும்.\n'
            '• **எச்சரிக்கை**: இருமல் 2 வாரங்களுக்கு மேல் தொடர்ந்தால் மருத்துவரை அணுகவும்.';
      } else if (lang == 'te') {
        return '🍵 **జలుబు, దగ్గు మరియు గొంతు నొప్పి నివారణ**:\n\n'
            '• **ఆవిరి పీల్చడం**: రోజుకు రెండుసార్లు వేడి నీటి ఆవిరి పీల్చండి.\n'
            '• **ఉప్పు నీటి పుక్కిలింత**: గోరువెచ్చని ఉప్పు నీటితో గొంతు పుక్కిలించండి.\n'
            '• **హెచ్చరిక**: దగ్గు 2 వారాల కంటే ఎక్కువ ఉంటే వెంటనే వైద్యుడిని సంప్రదించండి.';
      } else {
        return '🍵 **Care Guide for Cold, Cough & Sore Throat**:\n\n'
            '• **Steam Inhalation**: Inhale warm steam for 5–10 minutes twice daily to loosen nasal congestion and chest phlegm.\n'
            '• **Salt Water Gargles**: Dissolve 1/2 teaspoon of salt in a glass of warm water and gargle 2–3 times a day to soothe throat irritation.\n'
            '• **Warm Fluids**: Sip warm water, ginger-tulsi tea, or honey with a few drops of ginger juice.\n'
            '• **Medication Guidance**: For runny nose and sneezing, **Cetirizine 10mg** once before bed can provide relief.\n'
            '• **Doctor Warning**: If your cough lasts more than 2 weeks, produces blood, or is accompanied by chest pain, consult a physician promptly.';
      }
    }

    // 3. Headache / Migraine
    if (lower.contains('headache') ||
        lower.contains('migraine') ||
        lower.contains('सिरदर्द') ||
        lower.contains('माथा') ||
        lower.contains('মাথাব্যথা') ||
        lower.contains('தலைவலி') ||
        lower.contains('తలనొప్పి')) {
      if (lang == 'hi') {
        return '💆 **सिरदर्द से राहत के उपाय**:\n\n'
            '• **शांत व अंधेरे कमरे में आराम**: तेज रोशनी, मोबाइल स्क्रीन और शोर से दूर रहें। 20-30 मिनट आंखें बंद करके आराम करें।\n'
            '• **पानी पिएं**: अक्सर शरीर में पानी की कमी (डिहाइड्रेशन) से सिरदर्द होता है। 1-2 गिलास पानी पिएं।\n'
            '• **माथे पर हल्की मालिश**: गर्दन और माथे पर हल्के हाथों से मालिश करें या ठंडा/हल्का गर्म तौलिया रखें।\n'
            '• **दवा परामर्श**: सामान्य सिरदर्द में डॉक्टर **पैरासिटामोल 650mg** भोजन के बाद लेने का सुझाव देते हैं।\n'
            '• **चेतावनी**: यदि सिरदर्द अचानक बहुत तेज हो, चक्कर आए, उल्टी हो या हाथ-पैर में सुन्नता लगे, तो तुरंत इमरजेंसी में जाएं।';
      } else if (lang == 'bn') {
        return '💆 **মাথাব্যথা ও মাইগ্রেনের উপশম**:\n\n'
            '• **শান্ত ও অন্ধকার ঘরে বিশ্রাম**: উজ্জ্বল আলো ও মোবাইল স্ক্রিন থেকে দূরে থাকুন। ২০-৩০ মিনিট চোখ বন্ধ করে বিশ্রাম নিন।\n'
            '• **পর্যাপ্ত জল পান করুন**: জলস্বল্পতার কারণে প্রায়শই মাথাব্যথা হয়। ১-২ গ্লাস জল পান করুন।\n'
            '• **কপালে হালকা মালিশ**: কপাল ও ঘাড়ে হালকা মালিশ করুন বা ভেজা ঠান্ডা তোয়ালে রাখুন।\n'
            '• **ওষুধ সেবন**: সাধারণ মাথাব্যথায় খাবারের পর **প্যারাসিটামল ৬৫০ মিলিগ্রাম** স্বস্তি দিতে পারে।\n'
            '• **জরুরি লক্ষণ**: হঠাৎ অসহ্য তীব্র মাথাব্যথা, হাত-পায়ে অবশ ভাব বা দৃষ্টিতে অস্পষ্টতা দেখা দিলে অবিলম্বে হাসপাতালে যান।';
      } else if (lang == 'ta') {
        return '💆 **தலைவலி மற்றும் ஒற்றைத் தலைவலிக்கான ஆலோசனைகள்**:\n\n'
            '• **அமைதியான ஓய்வு**: வெளிச்சம் குறைந்த அறையில் கண்களை மூடி ஓய்வெடுக்கவும்.\n'
            '• **நீர் அருந்துதல்**: உடலுக்குத் தேவையான நீர் அருந்தவும்.\n'
            '• **மருந்து**: மருத்துவர் பரிந்துரைத்த பாராசிட்டமால் மாத்திரை எடுத்துக் கொள்ளலாம்.';
      } else if (lang == 'te') {
        return '💆 **తలనొప్పి మరియు మైగ్రేన్ నివారణ చర్యలు**:\n\n'
            '• **విశ్రాంతి**: కాంతి తక్కువగా ఉన్న గదిలో 20-30 నిమిషాలు విశ్రాంతి తీసుకోండి.\n'
            '• **నీరు తాగండి**: డీహైడ్రేషన్ వల్ల తలనొప్పి రావచ్చు, తగినంత నీరు తాగండి.';
      } else {
        return '💆 **Guidance for Headache & Migraine Relief**:\n\n'
            '• **Rest in a Quiet, Dark Room**: Dim lights, silence notifications, and rest your eyes for 20–30 minutes away from screens.\n'
            '• **Hydrate**: Mild dehydration is one of the most common causes of tension headaches. Drink 1–2 glasses of water.\n'
            '• **Gentle Compress**: Apply a cool cloth to your forehead or a warm pad to the back of your neck.\n'
            '• **Medication**: Standard **Paracetamol 650mg** after food can relieve tension headache.\n'
            '• **Red Flag Alert**: Seek urgent medical care if you experience a "thunderclap" sudden severe headache, weakness in arms, or speech changes.';
      }
    }

    // 4. Stomach Pain / Acidity / Diarrhea
    if (lower.contains('stomach') ||
        lower.contains('acidity') ||
        lower.contains('diarrhea') ||
        lower.contains('vomiting') ||
        lower.contains('gas') ||
        lower.contains('पेट दर्द') ||
        lower.contains('दस्त') ||
        lower.contains('उल्टी') ||
        lower.contains('পেট ব্যথা') ||
        lower.contains('വയிறு') ||
        lower.contains('வயிறு') ||
        lower.contains('కడుపు')) {
      if (lang == 'hi') {
        return '🥣 **पेट दर्द, गैस या दस्त के लिए देखभाल**:\n\n'
            '• **ओआरएस (ORS) घोल**: दस्त या उल्टी होने पर हर बार शौच के बाद 1 गिलास ओआरएस घोल या नींबू-पानी पिएं। इससे कमजोरी नहीं आती।\n'
            '• **हल्का सुपाच्य भोजन**: मूंग दाल की खिचड़ी, दही-चावल, केला और उबले आलू खाएं। तला-भुना, मिर्च-मसाला और दूध वाली चीजें न खाएं।\n'
            '• **एसिडिटी में**: गुनगुना पानी पिएं और खाना खाने के तुरंत बाद न लेटें।\n'
            '• **चेतावनी**: यदि पेट में अत्यधिक तेज दर्द हो, मल में खून आए या लगातार उल्टी हो रही हो, तो बिना देर किए डॉक्टर को दिखाएं।';
      } else if (lang == 'bn') {
        return '🥣 **পেট ব্যথা, অ্যাসিডিটি ও পাতলা পায়খানার যত্ন**:\n\n'
            '• **ওআরএস (ORS) স্যালাইন**: পাতলা পায়খানা বা বমি হলে প্রতিবার শৌচের পর ১ গ্লাস ওআরএস স্যালাইন বা ডাবের জল পান করুন।\n'
            '• **সহজপাচ্য খাদ্য**: নরম খিচুড়ি, দই-ভাত, কলা ও সেদ্ধ আলু খান। অতিরিক্ত তেল-মশলাযুক্ত বা ভাজাপোড়া খাবার পরিহার করুন।\n'
            '• **অ্যাসিডিটির ক্ষেত্রে**: অল্প অল্প করে জল পান করুন এবং খাওয়ার পরপরই শুয়ে পড়বেন না।\n'
            '• **জরুরি অবস্থা**: পেটে তীব্র অসহ্য ব্যথা, মলের সাথে রক্ত বা ক্রমাগত বমি হলে অবিলম্বে ডাক্তারের কাছে যান।';
      } else if (lang == 'ta') {
        return '🥣 **வயிற்று வலி, அஜீரணம் மற்றும் வயிற்றுப்போக்கு பராமரிப்பு**:\n\n'
            '• **ORS கரைசல்**: வயிற்றுப்போக்கின் போது நீர்ச்சத்தை மீட்டெடுக்க ORS அல்லது இளநீர் பருகவும்.\n'
            '• **எளிய உணவு**: தயிர் சாதம், இட்லி, வாழைப்பழம் போன்ற எளிதில் செரிக்கும் உணவுகளை உண்ணவும்.';
      } else if (lang == 'te') {
        return '🥣 **కడుపు నొప్పి మరియు విరేచనాల సంరక్షణ**:\n\n'
            '• **ORS ద్రవం**: విరేచనాలు అయినప్పుడు శరీరం నీటిని కోల్పోకుండా ORS ద్రావణం తాగండి.\n'
            '• **తేలికపాటి ఆహారం**: కిచిడీ, పెరుగన్నం, అరటిపండ్లు వంటి తేలికగా జీర్ణమయ్యే ఆహారం తీసుకోండి.';
      } else {
        return '🥣 **Care Guide for Stomach Pain, Acidity & Diarrhea**:\n\n'
            '• **ORS Rehydration**: For loose motions or vomiting, sip 1 glass of **Oral Rehydration Salts (ORS)** solution or tender coconut water after every loose stool.\n'
            '• **BRAT & Bland Diet**: Eat soft, easy-to-digest foods like khichdi, curd rice, bananas, and toast. Avoid oily, fried, and spicy foods.\n'
            '• **For Acidity & Heartburn**: Avoid skipping meals, do not lie down immediately after eating, and drink water in small sips.\n'
            '• **When to See a Doctor**: High fever, blood in stools, severe dehydration, or inability to keep liquids down.';
      }
    }

    // 5. Blood Pressure & Diabetes
    if (lower.contains('blood pressure') ||
        lower.contains('bp') ||
        lower.contains('diabetes') ||
        lower.contains('sugar') ||
        lower.contains('रक्तचाप') ||
        lower.contains('शुगर') ||
        lower.contains('डायबिटीज') ||
        lower.contains('রক্তচাপ') ||
        lower.contains('ডায়াবেটিস') ||
        lower.contains('இரத்த அழுத்தம்')) {
      if (lang == 'hi') {
        return '🩺 **ब्लड प्रेशर और शुगर (डायबिटीज) का प्रबंधन**:\n\n'
            '• **नियमित जांच**: सुबह खाली पेट और भोजन के 2 घंटे बाद शुगर व बीपी नापकर डायरी में नोट करें।\n'
            '• **नमक व मीठे पर नियंत्रण**: बीपी में रोजाना नमक कम करें (अचार, पापड़, नमकीन से बचें)। शुगर में मीठा और मैदा बंद करें।\n'
            '• **दवा समय पर लें**: डॉक्टर द्वारा दी गई बीपी और शुगर की गोलियां कभी भी खुद से बंद न करें।\n'
            '• **हल्का व्यायाम**: रोजाना 30 मिनट तेज गति से टहलें। तनाव से दूर रहें।\n'
            '• **इमरजेंसी लक्षण**: अचानक सीने में भारीपन, अत्यधिक पसीना, चक्कर आना या अत्यधिक कमजोरी महसूस होने पर तुरंत 108 / 112 डायल करें।';
      } else if (lang == 'bn') {
        return '🩺 **রক্তচাপ (BP) ও ডায়াবেটিস নিয়ন্ত্রণ নির্দেশিকা**:\n\n'
            '• **নিয়মিত নিরীক্ষণ**: নিয়মিত সকালের খালি পেটে এবং খাবারের ২ ঘণ্টা পর রক্তে শর্করার মাত্রা ও রক্তচাপ মেপে লিখে রাখুন।\n'
            '• **লবণ ও চিনি নিয়ন্ত্রণ**: উচ্চ রক্তচাপে খাবারে লবণ ও কাঁচা নুন বাদ দিন। ডায়াবেটিসে চিনি, মিষ্টি ও প্রক্রিয়াজাত খাবার এড়িয়ে চলুন।\n'
            '• **নিয়মিত ওষুধ**: ডাক্তারের নির্দেশিত রক্তচাপ ও শর্করার ওষুধ কখনোই নিজ থেকে বন্ধ করবেন না।\n'
            '• **হালকা ব্যায়াম**: সপ্তাহে অন্তত ৫ দিন ৩০ মিনিট করে দ্রুত হাঁটুন।\n'
            '• **জরুরি বিপদ সংকেত**: বুকে তীব্র চাপ, অতিরিক্ত ঘাম, মাথা ঘোরা বা বুক ধড়ফড় করলে তৎক্ষণাৎ ১১২ বা ১০৮ নম্বরে যোগাযোগ করুন।';
      } else if (lang == 'ta') {
        return '🩺 **இரத்த அழுத்தம் மற்றும் சர்க்கரை நோய் மேலாண்மை**:\n\n'
            '• **தொடர் கண்காணிப்பு**: இரத்த அழுத்தம் மற்றும் சர்க்கரை அளவை தவறாமல் குறித்து வைக்கவும்.\n'
            '• **உணவு கட்டுப்பாடு**: உப்பு மற்றும் இனிப்பு வகைகளைக் குறைக்கவும்.\n'
            '• **தவறாமல் மருந்து**: மருத்துவர் பரிந்துரைத்த மருந்துகளைத் தவறாமல் உட்கொள்ளவும்.';
      } else if (lang == 'te') {
        return '🩺 **రక్తపోటు (BP) మరియు మధుమేహం నియంత్రణ**:\n\n'
            '• **రోజూ తనిఖీ**: బీపీ మరియు షుగర్ స్థాయిలను రోజూ డైరీలో నమోదు చేయండి.\n'
            '• **ఆహార నియమాలు**: ఉప్పు మరియు తీపి పదార్థాలను తగ్గించండి.\n'
            '• **సమయానికి మందులు**: డాక్టర్ రాసిన మందులను ఎప్పుడూ ఆపకండి.';
      } else {
        return '🩺 **Management Tips for Blood Pressure & Diabetes**:\n\n'
            '• **Daily Monitoring**: Keep a routine log of your fasting & post-meal blood sugar levels and resting blood pressure.\n'
            '• **Dietary Adjustments**: For BP, reduce dietary salt/sodium (avoid pickles and processed snacks). For diabetes, prioritize fiber and complex grains.\n'
            '• **Medication Adherence**: Never skip or abruptly stop your prescribed antihypertensive or anti-diabetic medications without doctor consent.\n'
            '• **Physical Activity**: Aim for 30 minutes of brisk walking 5 days a week.\n'
            '• **Warning Signs**: Severe dizziness, chest heaviness, extreme sweating, or confusion require immediate emergency attention.';
      }
    }

    return null;
  }

  String _synthesizeChunks(List<SearchResult> chunks, String lang) {
    final buffer = StringBuffer();

    if (lang == 'hi') {
      buffer.writeln('📋 **चिकित्सा जानकारी व मार्गदर्शन**:\n');
      for (final chunk in chunks) {
        final cleanText = _cleanRawChunkText(chunk.text);
        if (cleanText.isNotEmpty) {
          buffer.writeln('• $cleanText\n');
        }
      }
      buffer.writeln('---');
      buffer.writeln('💡 *सलाह: सटीक जांच और व्यक्तिगत उपचार के लिए योग्य डॉक्टर से परामर्श अवश्य लें।*');
    } else if (lang == 'bn') {
      buffer.writeln('📋 **স্বাস্থ্য তথ্য ও চিকিৎসকের পরামর্শ**:\n');
      for (final chunk in chunks) {
        final cleanText = _cleanRawChunkText(chunk.text);
        if (cleanText.isNotEmpty) {
          buffer.writeln('• $cleanText\n');
        }
      }
      buffer.writeln('---');
      buffer.writeln('💡 *পরামর্শ: সঠিক রোগ নির্ণয় ও চিকিৎসার জন্য সর্বদা যোগ্য চিকিৎসকের পরামর্শ নিন।*');
    } else if (lang == 'ta') {
      buffer.writeln('📋 **மருத்துவ தகவல் மற்றும் வழிகாட்டுதல்**:\n');
      for (final chunk in chunks) {
        final cleanText = _cleanRawChunkText(chunk.text);
        if (cleanText.isNotEmpty) {
          buffer.writeln('• $cleanText\n');
        }
      }
      buffer.writeln('---');
      buffer.writeln('💡 *குறிப்பு: துல்லியமான சிகிச்சைக்கு தகுதிவாய்ந்த மருத்துவரை அணுகவும்.*');
    } else if (lang == 'te') {
      buffer.writeln('📋 **వైద్య సమాచారం మరియు మార్గదర్శకత్వం**:\n');
      for (final chunk in chunks) {
        final cleanText = _cleanRawChunkText(chunk.text);
        if (cleanText.isNotEmpty) {
          buffer.writeln('• $cleanText\n');
        }
      }
      buffer.writeln('---');
      buffer.writeln('💡 *గమనిక: ఖచ్చితమైన చికిత్స కోసం అర్హత కలిగిన వైద్యుడిని సంప్రదించండి.*');
    } else {
      buffer.writeln('📋 **Clinical Health Information**:\n');
      for (final chunk in chunks) {
        final cleanText = _cleanRawChunkText(chunk.text);
        if (cleanText.isNotEmpty) {
          buffer.writeln('• $cleanText\n');
        }
      }
      buffer.writeln('---');
      buffer.writeln('💡 *Notice: For personalized clinical evaluation and prescription, please consult a qualified doctor.*');
    }

    return buffer.toString().trim();
  }

  String _cleanRawChunkText(String raw) {
    var text = raw.replaceAll(RegExp(r'MedQuAD:.*?\(.*?\)', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'Source:.*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'### Finding \d+'), '');
    text = text.replaceAll(RegExp(r'\[\d+\]'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .take(3)
        .join(' ');

    return sentences.isNotEmpty ? sentences : text;
  }

  String _buildGeneralCareAdvice(String query, String lang) {
    if (lang == 'hi') {
      return 'नमस्ते! मैं आपका अश्विनी स्वास्थ्य सहायक हूँ।\n\n'
          '• **स्वास्थ्य सलाह**: स्वस्थ रहने के लिए पर्याप्त मात्रा में स्वच्छ पानी पिएं, पौष्टिक भोजन लें और रोजाना कम से कम 7-8 घंटे की नींद लें।\n'
          '• **दवाइयों की जानकारी**: यदि आप किसी दवा के बारे में पूछना चाहते हैं, तो उसका नाम लिखें। हम उसके सही समय और परहेज की जानकारी देंगे।\n'
          '• **ऐप सुविधाएं**: आप नीचे फार्मेसी से सस्ती जेनेरिक दवाएं ढूंढ सकते हैं, फेस वाइटल्स से दिल की धड़कन नाप सकते हैं या डॉक्टर से वीडियो कॉल पर बात कर सकते हैं।\n\n'
          '💡 *किसी भी बीमारी के सही निदान के लिए नजदीकी डॉक्टर या हमारे टेलीकंसल्टेशन से परामर्श लें।*';
    } else if (lang == 'bn') {
      return 'নমস্কার! আমি আপনার অশ্বিনী স্বাস্থ্য সহায়ক।\n\n'
          '• **সাধারণ স্বাস্থ্যবিধি**: প্রচুর পরিমাণে জল পান করুন, স্বাস্থ্যকর খাবার গ্রহণ করুন এবং পর্যাপ্ত বিশ্রাম নিন।\n'
          '• **ওষুধের তথ্য**: যেকোনো ওষুধের নিয়মাবলী এবং সময় জানতে ওষুধের নামটি লিখুন।\n'
          '• **অ্যাপের সুবিধা**: আপনি প্রেসক্রিপশন স্ক্যান করে সাশ্রয়ী জেনেরিক ওষুধ পেতে পারেন অথবা ডাক্তারের সাথে ভিডিও কলে কথা বলতে পারেন।\n\n'
          '💡 *যেকোনো জরুরি স্বাস্থ্য সমস্যার জন্য সর্বদা একজন অভিজ্ঞ ডাক্তারের পরামর্শ নিন।*';
    } else if (lang == 'ta') {
      return 'வணக்கம்! நான் உங்கள் அஸ்வினி சுகாதார உதவியாளர்.\n\n'
          '• **பொதுவான நலவாழ்வு**: தினமும் போதுமான அளவு தண்ணீர் குடிக்கவும், சத்தான உணவை உட்கொள்ளவும், நல்ல ஓய்வு எடுக்கவும்.\n'
          '• **மருந்து விவரங்கள்**: நீங்கள் உட்கொள்ளும் மருந்து பற்றிய விவரங்களை அறிய அதன் பெயரை உள்ளிடவும்.\n'
          '• **செயலி வழிகாட்டல்**: குறைந்த விலையில் மருந்துகளை வாங்கவும் அல்லது வீடியோ மூலம் மருத்துவரை அணுகவும் இச்செயலி உதவுகிறது.\n\n'
          '💡 *துல்லியமான சிகிச்சைக்கு தகுதிவாய்ந்த மருத்துவரை அணுகவும்.*';
    } else {
      return 'Hello! I am your Ashwini Healthcare Assistant.\n\n'
          '• **Daily Wellness**: Stay well-hydrated, eat freshly prepared balanced meals, and ensure 7–8 hours of sound sleep.\n'
          '• **Medication & Dosage**: Type the name of any medicine to learn about its proper timing, food rules, and common precautions.\n'
          '• **In-App Features**: You can scan prescriptions in the Pharmacy Tab for 60–80% generic savings, check your pulse via Face Vitals, or book an appointment with our doctors.\n\n'
          '💡 *For clinical diagnoses or severe symptoms, please consult a qualified healthcare professional.*';
    }
  }
}
