import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/language_provider.dart';
import '../../../../widgets/patient_action_sheets.dart';
import '../../../../services/permissions/app_permission_service.dart';
import '../../../../services/stt/sarvam_stt_service.dart';
import '../../../../services/tts/sarvam_tts_service.dart';
import '../../domain/models/patient_profile.dart';
import '../../domain/repositories/chat_storage_repository.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/services/chat_orchestrator.dart';
import '../../domain/services/connectivity_service.dart';
import '../widgets/formatted_message_view.dart';

/// Primary conversational screen for the Healthcare Chatbot with 22-language Sarvam TTS.
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
  ChatMessage? _lastAssistantMessage;

  void _handleTopSpeakerPressed() {
    final tts = SarvamTtsService.instance;
    final ttsStatus = tts.statusNotifier.value;

    if (ttsStatus.isPlaying || ttsStatus.isLoading) {
      tts.stop();
      return;
    }

    final latestMsg = _lastAssistantMessage;
    if (latestMsg != null && latestMsg.text.trim().isNotEmpty) {
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      tts.speak(
        text: latestMsg.text,
        messageId: latestMsg.id.toString(),
        languageCode: langProvider.currentLanguageCode,
      );
    } else {
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      final msg = langProvider.currentLanguageCode == 'hi'
          ? 'बोलने के लिए अभी कोई उत्तर नहीं है।'
          : langProvider.currentLanguageCode == 'pa'
              ? 'ਸੁਣਨ ਲਈ ਅਜੇ ਕੋਈ ਜਵਾਬ ਨਹੀਂ ਹੈ।'
              : 'No response to read aloud yet. Ask a question first!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: const Color(0xFF006A6A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static const List<String> _suggestions = [
    'Can I take Amoxicillin for my cold?',
    'How do I scan prescriptions for Jan Aushadhi savings?',
    'How to measure my Heart Rate using Face Vitals?',
    'How to request an ASHA worker home visit?',
    'What happens when I press the red Emergency SOS button?',
    'How do I switch the app to Hindi or other languages?',
  ];

  List<String> _getLocalizedSuggestions(String languageCode) {
    final code = languageCode.toLowerCase().split('-').first.split('_').first;
    switch (code) {
      case 'hi':
        return [
          'क्या मैं सर्दी-जुकाम में Amoxicillin ले सकता हूँ?',
          'सस्ती दवाइयों (Jan Aushadhi) के लिए पर्चा कैसे स्कैन करें?',
          'Face Vitals से दिल की धड़कन (Heart Rate) कैसे नापें?',
          'आशा कार्यकर्ता (ASHA Worker) से घर पर जांच के लिए कैसे कहें?',
          'आपातकालीन लाल SOS बटन दबाने पर क्या होता है?',
          'ऐप की भाषा कैसे बदलें?',
        ];
      case 'bn':
        return [
          'আমার সর্দির জন্য কি Amoxicillin খেতে পারি?',
          'জন ঔষধি থেকে কম খরচে ওষুধ পেতে প্রেসক্রিপশন কীভাবে স্ক্যান করব?',
          'Face Vitals দিয়ে হার্ট রেট কীভাবে মাপব?',
          'আশা দিদিকে বাড়ি পরিদর্শনের জন্য কীভাবে অনুরোধ করব?',
          'জরুরি লাল SOS বোতাম টিপলে কী হবে?',
          'অ্যাপের ভাষা কীভাবে পরিবর্তন করব?',
        ];
      case 'ta':
        return [
          'சளிக்கு Amoxicillin மாத்திரை சாப்பிடலாமா?',
          'மலிவு விலை மக்கள் மருந்தக மருந்துகளுக்கு மருந்து சீட்டை ஸ்கேன் செய்வது எப்படி?',
          'Face Vitals மூலம் இதய துடிப்பை அளவிடுவது எப்படி?',
          'ஆஷா பணியாளர் வீட்டிற்கு வர எப்படி கோரிக்கை விடுப்பது?',
          'அவசர சிவப்பு SOS பட்டனை அழுத்தினால் என்ன நடக்கும்?',
          'பயன்பாட்டின் மொழியை மாற்றுவது எப்படி?',
        ];
      case 'te':
        return [
          'జలుబుకు Amoxicillin వేసుకోవచ్చా?',
          'జన్ ఔషధి తక్కువ ధర మందుల కోసం ప్రిస్క్రిప్షన్ ఎలా స్కాన్ చేయాలి?',
          'Face Vitals తో గుండె కొట్టుకునే వేగం ఎలా కొలవాలి?',
          'ఆశా కార్యకర్త ఇంటి సందర్శన కోసం ఎలా అడగాలి?',
          'ఎరుపు రంగు SOS బటన్ నొక్కితే ఏం జరుగుతుంది?',
          'యాప్ భాషను ఎలా మార్చాలి?',
        ];
      case 'mr':
        return [
          'मला सर्दीसाठी Amoxicillin घेता येईल का?',
          'जन औषधी स्वस्त औषधांसाठी प्रिस्क्रिप्शन कसे स्कॅन करावे?',
          'Face Vitals द्वारे हृदयाचे ठोके कसे मोजावे?',
          'आशा सेविकेला घरी तपासणीसाठी कशी विनंती करावी?',
          'लाल आपत्कालीन SOS बटण दाबल्यावर काय होते?',
          'अ‍ॅपची भाषा कशी बदलावी?',
        ];
      case 'gu':
        return [
          'શું શરદી માટે Amoxicillin લઈ શકાય?',
          'જન ઔષધિ સસ્તી દવાઓ માટે પ્રિસ્ક્રિપ્શન કેવી રીતે સ્કેન કરવું?',
          'Face Vitals થી હૃદયના ધબકારા કેવી રીતે માપવા?',
          'આશા કાર્યકરને ઘરે તપાસ માટે કેવી રીતે બોલાવવા?',
          'લાલ ઈમરજન્સી SOS બટન દબાવવાથી શું થાય?',
          'એપ્લિકેશનની ભાષા કેવી રીતે બદલવી?',
        ];
      case 'kn':
        return [
          'ಶೀತಕ್ಕೆ Amoxicillin ತೆಗೆದುಕೊಳ್ಳಬಹುದೇ?',
          'ಜನ ಔಷಧಿ ಕಡಿಮೆ ದರದ ಔಷಧಿಗಳಿಗಾಗಿ ಚೀಟಿ ಸ್ಕ್ಯಾನ್ ಮಾಡುವುದು ಹೇಗೆ?',
          'Face Vitals ಮೂಲಕ ಹೃದಯ ಬಡಿತ ಅಳೆಯುವುದು ಹೇಗೆ?',
          'ಆಶಾ ಕಾರ್ಯಕರ್ತೆಯರ ಮನೆ ಭೇಟಿಗೆ ಹೇಗೆ ವಿನಂತಿಸುವುದು?',
          'ಕೆಂಪು SOS ಬಟನ್ ಒತ್ತಿದರೆ ಏನಾಗುತ್ತದೆ?',
          'ಅಪ್ಲಿಕೇಶನ್ ಭಾಷೆಯನ್ನು ಹೇಗೆ ಬದಲಾಯಿಸುವುದು?',
        ];
      case 'ml':
        return [
          'ജലദോഷത്തിന് Amoxicillin കഴിക്കാമോ?',
          'ജൻ ഔഷധി കുറഞ്ഞ നിരക്കിലുള്ള മരുന്നുകൾക്ക് കുറിപ്പടി എങ്ങനെ സ്കാൻ ചെയ്യാം?',
          'Face Vitals ഉപയോഗിച്ച് ഹൃദയമിടിപ്പ് എങ്ങനെ അളക്കാം?',
          'ആശ വർക്കറുടെ ഭവന സന്ദർശനത്തിന് എങ്ങനെ അപേക്ഷിക്കാം?',
          'ചുവന്ന SOS ബട്ടൺ അമർത്തിയാൽ എന്ത് സംഭവിക്കും?',
          'ആപ്പിന്റെ ഭാഷ എങ്ങനെ മാറ്റാം?',
        ];
      case 'pa':
        return [
          'ਕੀ ਮੈਂ ਜ਼ੁਕਾਮ ਲਈ Amoxicillin ਲੈ ਸਕਦਾ ਹਾਂ?',
          'ਜਨ ਔਸ਼ਧੀ ਸਸਤੀਆਂ ਦਵਾਈਆਂ ਲਈ ਪਰਚੀ ਕਿਵੇਂ ਸਕੈਨ ਕਰੀਏ?',
          'Face Vitals ਨਾਲ ਦਿਲ ਦੀ ਧੜਕਣ ਕਿਵੇਂ ਮਾਪੀਏ?',
          'ਆਸ਼ਾ ਵਰਕਰ ਨੂੰ ਘਰ ਦੇ ਦੌਰੇ ਲਈ ਕਿਵੇਂ ਕਹੀਏ?',
          'ਐਮਰਜੈਂਸੀ ਲਾਲ SOS ਬਟਨ ਦਬਾਉਣ \'ਤੇ ਕੀ ਹੁੰਦਾ ਹੈ?',
          'ਐਪ ਦੀ ਭਾਸ਼ਾ ਕਿਵੇਂ ਬਦਲੀਏ?',
        ];
      case 'ur':
        return [
          'کیا میں زکام کے لیے Amoxicillin لے سکتا ہوں؟',
          'جن اوشدھی سستی ادویات کے لیے نسخہ کیسے اسکین کریں؟',
          'Face Vitals سے نبض کی رفتار کیسے چیک کریں؟',
          'آشا ورکر کو گھر کے معائنے کے لیے کیسے بلائیں؟',
          'ایمرجنسی لال SOS بٹن دبانے سے کیا ہوتا ہے؟',
          'ایپ کی زبان کیسے تبدیل کریں؟',
        ];
      case 'or':
      case 'od':
        return [
          'ଥଣ୍ଡା ପାଇଁ Amoxicillin ଔଷଧ ନେଇପାରିବି କି?',
          'ଜନ ଔଷଧି କମ ମୂଲ୍ୟର ଔଷଧ ପାଇଁ ପ୍ରେସକ୍ରିପସନ କିପରି ସ୍କାନ କରିବେ?',
          'Face Vitals ସାହାଯ୍ୟରେ ହୃଦସ୍ପନ୍ଦନ କିପରି ମାପିବେ?',
          'ଆଶା କର୍ମୀଙ୍କୁ ଘର ପରିଦର୍ଶନ ପାଇଁ କିପରି କହିବେ?',
          'ଲାଲ ଜରୁରୀକାଳୀନ SOS ବଟନ ଦବାଇଲେ କ\'ଣ ହୁଏ?',
          'ଆପର ଭାଷା କିପରି ବଦଳାଇବେ?',
        ];
      default:
        return _suggestions;
    }
  }

  String _getLocalizedGreeting(String langCode) {
    final code = langCode.toLowerCase().split('-').first.split('_').first;
    switch (code) {
      case 'hi':
        return 'मैं आज आपकी क्या मदद कर सकता हूँ?';
      case 'bn':
        return 'আজ আপনাকে কীভাবে সাহায্য করতে পারি?';
      case 'ta':
        return 'இன்று உங்களுக்கு நான் எவ்வாறு உதவ முடியும்?';
      case 'te':
        return 'నేను మీకు ఎలా సహాయపడగలను?';
      case 'mr':
        return 'मी आज तुम्हाला कशी मदत करू शकतो?';
      case 'gu':
        return 'હું આજે તમને કેવી રીતે મદદ કરી શકું?';
      case 'kn':
        return 'ಇಂದು ನಾನು ನಿಮಗೆ ಹೇಗೆ ಸಹಾಯ ಮಾಡಲಿ?';
      case 'ml':
        return 'ഇന്ന് ഞാൻ നിങ്ങളെ എങ്ങനെ സഹായിക്കണം?';
      case 'pa':
        return 'ਮੈਂ ਅੱਜ ਤੁਹਾਡੀ ਕੀ ਮਦਦ ਕਰ ਸਕਦਾ ਹਾਂ?';
      case 'ur':
        return 'آج میں آپ کی کیا مدد کر سکتا ہوں؟';
      case 'or':
      case 'od':
        return 'ମୁଁ ଆଜି ଆପଣଙ୍କୁ କିପରି ସାହାଯ୍ୟ କରିପାରିବି?';
      default:
        return 'How can I help you today?';
    }
  }

  String _getLocalizedSubtitle(String langCode) {
    final code = langCode.toLowerCase().split('-').first.split('_').first;
    switch (code) {
      case 'hi':
        return 'अपनी सेहत, दवाइयों या लक्षणों के बारे में पूछें। किसी भी जवाब को सुनने के लिए स्पीकर बटन दबाएं।';
      case 'bn':
        return 'আপনার স্বাস্থ্য, ওষুধ বা লক্ষণ সম্পর্কে প্রশ্ন জিজ্ঞাসা করুন। উত্তর শোনার জন্য স্পিকার বোতাম টিপুন।';
      case 'ta':
        return 'உங்கள் உடல்நலம், மருந்துகள் அல்லது அறிகுறிகள் பற்றி கேளுங்கள். பதிலைக் கேட்க ஸ்பீக்கர் பட்டனை அழுத்தவும்.';
      case 'te':
        return 'మీ ఆరోగ్యం, మందులు లేదా లక్షణాల గురించి అడగండి. సమాధానం వినడానికి స్పీకర్ బటన్‌ను నొక్కండి.';
      case 'mr':
        return 'आपल्या आरोग्याविषयी, औषधांविषयी किंवा लक्षणांविषयी विचारा. उत्तर ऐकण्यासाठी स्पीकर बटण दाबा.';
      case 'gu':
        return 'તમારા સ્વાસ્થ્ય, દવાઓ અથવા લક્ષણો વિશે પૂછો. જવાબ સાંભળવા માટે સ્પીકર બટન દબાવો.';
      case 'kn':
        return 'ನಿಮ್ಮ ಆರೋಗ್ಯ, ಔಷಧಿಗಳು ಅಥವಾ ರೋಗಲಕ್ಷಣಗಳ ಬಗ್ಗೆ ಕೇಳಿ. ಉತ್ತರವನ್ನು ಕೇಳಲು ಸ್ಪೀಕರ್ ಬಟನ್ ಒತ್ತಿರಿ.';
      case 'ml':
        return 'നിങ്ങളുടെ ആരോഗ്യം, മരുന്നുകൾ, ലക്ഷണങ്ങൾ എന്നിവയെക്കുറിച്ച് ചോദിക്കുക. ഉത്തരം കേൾക്കാൻ സ്പീക്കർ ബട്ടൺ അമർത്തുക.';
      case 'pa':
        return 'ਆਪਣੀ ਸਿਹਤ, ਦਵਾਈਆਂ ਜਾਂ ਲੱਛਣਾਂ ਬਾਰੇ ਪੁੱਛੋ। ਜਵਾਬ ਸੁਣਨ ਲਈ ਸਪੀਕਰ ਬਟਨ ਦਬਾਓ।';
      case 'ur':
        return 'अपनी सेहत، ادویات یا علامات کے بارے میں پوچھیں۔ جواب سننے کے لیے اسپیکر کا بٹن دبائیں۔';
      case 'or':
      case 'od':
        return 'ଆପଣଙ୍କ ସ୍ୱାସ୍ଥ୍ୟ, ଔଷଧ କିମ୍ବା ଲକ୍ଷଣ ବିଷୟରେ ପଚାରନ୍ତୁ। ଉତ୍ତର ଶୁଣିବା ପାଇଁ ସ୍ପିକର ବଟନ ଦବାନ୍ତୁ।';
      default:
        return 'Ask questions about your health, medicines, symptoms, or hospital visits. Tap the speaker button on any answer to listen to it.';
    }
  }

  String _getLocalizedSuggestedQuestionsHeader(String langCode) {
    final code = langCode.toLowerCase().split('-').first.split('_').first;
    switch (code) {
      case 'hi':
        return 'सुझाए गए प्रश्न';
      case 'bn':
        return 'প্রস্তাবিত প্রশ্নাবলী';
      case 'ta':
        return 'பரிந்துரைக்கப்பட்ட கேள்விகள்';
      case 'te':
        return 'సూచించిన ప్రశ్నలు';
      case 'mr':
        return 'सुचवलेले प्रश्न';
      case 'gu':
        return 'સૂચવેલા પ્રશ્નો';
      case 'kn':
        return 'ಶಿಫಾರಸು ಮಾಡಿದ ಪ್ರಶ್ನೆಗಳು';
      case 'ml':
        return 'നിർദ്ദേശിച്ച ചോദ്യങ്ങൾ';
      case 'pa':
        return 'ਸੁਝਾਏ ਗਏ ਸਵਾਲ';
      case 'ur':
        return 'تجویز کردہ سوالات';
      case 'or':
      case 'od':
        return 'ପ୍ରସ୍ତାବିତ ପ୍ରଶ୍ନଗୁଡ଼ିକ';
      default:
        return 'SUGGESTED QUESTIONS';
    }
  }

  String _getLocalizedGeneratingText(String langCode) {
    final code = langCode.toLowerCase().split('-').first.split('_').first;
    switch (code) {
      case 'hi':
        return 'चिकित्सा जानकारी तैयार की जा रही है...';
      case 'bn':
        return 'চিকিৎসা নির্দেশিকা প্রস্তুত করা হচ্ছে...';
      case 'ta':
        return 'மருத்துவ வழிகாட்டுதல் தயாரிக்கப்படுகிறது...';
      case 'te':
        return 'వైద్య సమాచారం సిద్ధం చేయబడుతోంది...';
      case 'mr':
        return 'वैद्यकीय माहिती तयार केली जात आहे...';
      case 'gu':
        return 'તબીબી માહિતી તૈયાર થઈ રહી છે...';
      case 'kn':
        return 'ವೈದ್ಯಕೀಯ ಮಾರ್ಗದರ್ಶನ ಸಿದ್ಧಪಡಿಸಲಾಗುತ್ತಿದೆ...';
      case 'ml':
        return 'വൈദ്യോപദേശം തയ്യാറാക്കുന്നു...';
      case 'pa':
        return 'ਡਾਕਟਰੀ ਸਲਾਹ ਤਿਆਰ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ...';
      case 'ur':
        return 'طبی معلومات تیار کی جا رہی ہیں...';
      case 'or':
      case 'od':
        return 'ଡାକ୍ତରୀ ମାର୍ଗଦର୍ଶନ ପ୍ରସ୍ତୁତ କରାଯାଉଛି...';
      default:
        return 'Preparing medical guidance...';
    }
  }

  String _getLocalizedInputHint(String langCode, bool isListening, String languageName) {
    if (isListening) {
      return 'Speak now in $languageName...';
    }
    final code = langCode.toLowerCase().split('-').first.split('_').first;
    switch (code) {
      case 'hi':
        return 'स्वास्थ्य संबंधी सवाल पूछें...';
      case 'bn':
        return 'স্বাস্থ্য সংক্রান্ত প্রশ্ন জিজ্ঞাসা করুন...';
      case 'ta':
        return 'உடல்நலக் கேள்விகளைக் கேளுங்கள்...';
      case 'te':
        return 'ఆరోగ్య ప్రశ్న అడగండి...';
      case 'mr':
        return 'आरोग्याविषयी प्रश्न विचारा...';
      case 'gu':
        return 'સ્વાસ્થ્ય સંબંધિત પ્રશ્ન પૂછો...';
      case 'kn':
        return 'ಆರೋಗ್ಯ ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ...';
      case 'ml':
        return 'ആരോഗ്യപരമായ ചോദ്യങ്ങൾ ചോദിക്കുക...';
      case 'pa':
        return 'ਸਿਹਤ ਸੰਬੰਧੀ ਸਵਾਲ ਪੁੱਛੋ...';
      case 'ur':
        return 'صحت کا کوئی سوال پوچھیں...';
      case 'or':
      case 'od':
        return 'ସ୍ୱାସ୍ଥ୍ୟ ବିଷୟରେ ପ୍ରଶ୍ନ ପଚାରନ୍ତୁ...';
      default:
        return 'Ask a health question or doubt...';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _loadPatientProfile();
    _connectivitySub =
        widget.connectivityService.onConnectivityChanged.listen((online) {
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
    SarvamSttService.instance.cancel();
    SarvamTtsService.instance.stop();
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

  Future<void> _handleMicPressed() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final stt = SarvamSttService.instance;
    final currentStatus = stt.statusNotifier.value;

    if (currentStatus.isListening) {
      final transcribedText = await stt.stopAndTranscribe(
        languageCode: langProvider.currentLanguageCode,
      );
      final candidateText = (transcribedText != null && transcribedText.trim().isNotEmpty)
          ? transcribedText.trim()
          : _textController.text.trim();

      if (mounted) {
        if (candidateText.isNotEmpty) {
          _textController.clear();
          _sendMessage(candidateText);
        } else {
          final err = stt.statusNotifier.value.errorMessage ??
              (langProvider.currentLanguageCode == 'hi'
                  ? 'आवाज़ पहचान नहीं सकी। कृपया दोबारा स्पष्ट बोलें।'
                  : langProvider.currentLanguageCode == 'pa'
                      ? 'ਆਵਾਜ਼ ਪਛਾਣੀ ਨਹੀਂ ਜਾ ਸਕੀ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰਾ ਬੋਲੋ।'
                      : langProvider.currentLanguageCode == 'bn'
                          ? 'ভয়েস সনাক্ত করা যায়নি। অনুগ্রহ করে আবার স্পষ্ট করে বলুন।'
                          : 'Could not detect speech. Please speak clearly into the mic and try again.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.mic_off_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(err)),
                ],
              ),
              backgroundColor: const Color(0xFFC2410C),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else if (currentStatus.isTranscribing) {
      return;
    } else {
      // Stop any audio readout before listening to the patient
      SarvamTtsService.instance.stop();

      // Explicitly request OS microphone permission if not already granted.
      // Once granted, Android OS retains this permission until app data is cleared.
      final hasPermission = await AppPermissionService.requestMicrophonePermission(
        context: context,
      );
      if (!hasPermission) {
        return;
      }

      final started = await stt.startListening(
        languageCode: langProvider.currentLanguageCode,
        onPartialResult: (partialText) {
          if (mounted && partialText.trim().isNotEmpty) {
            setState(() {
              _textController.text = partialText.trim();
            });
          }
        },
        onAutoStop: () {
          if (mounted && stt.statusNotifier.value.isListening) {
            _handleMicPressed();
          }
        },
      );

      if (!started && mounted) {
        final err = stt.statusNotifier.value.errorMessage ?? 'Microphone permission denied';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty) return;

    // Always clear the text bar immediately upon sending
    _textController.clear();
    _focusNode.unfocus();

    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      await widget.orchestrator.handleUserMessage(
        text: text,
        conversationId: widget.conversationId,
        patientId: _patientProfile?.patientId,
        languageCode: langProvider.currentLanguageCode,
        languageName: langProvider.currentLanguage.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text(
          'Are you sure you want to clear your conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SarvamTtsService.instance.stop();
      await widget.storageRepository.deleteConversation(widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => PatientActionSheets.showLanguageSelector(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ashwini_logo.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006A6A).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: Color(0xFF006A6A),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langProvider.tr('ai_assistant'),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _isOnline
                                  ? 'Ashwini AI • ${langProvider.currentLanguage.name}'
                                  : 'Ashwini AI (Offline) • ${langProvider.currentLanguage.name}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // Quick Language Switcher Button (e.g. [BN] বাংলা ▾)
          GestureDetector(
            onTap: () => PatientActionSheets.showLanguageSelector(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 4),
                  Text(
                    langProvider.currentLanguage.badge.isNotEmpty
                        ? langProvider.currentLanguage.badge
                        : langProvider.currentLanguageCode.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF7C3AED)),
                ],
              ),
            ),
          ),
          // Top-right Speaker Button (Tts Readout of Latest AI Response)
          ValueListenableBuilder<TtsPlaybackStatus>(
            valueListenable: SarvamTtsService.instance.statusNotifier,
            builder: (context, ttsStatus, _) {
              final isPlaying = ttsStatus.isPlaying;
              final isLoading = ttsStatus.isLoading;

              return IconButton(
                tooltip: isPlaying ? 'Stop Audio' : 'Read Aloud Response',
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                        color: isPlaying ? const Color(0xFF006A6A) : const Color(0xFF475569),
                        size: 22,
                      ),
                onPressed: _handleTopSpeakerPressed,
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF475569)),
            onSelected: (val) {
              if (val == 'language') {
                PatientActionSheets.showLanguageSelector(context);
              } else if (val == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text(langProvider.tr('choose_language')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showEmergencyBanner) _buildEmergencyBanner(langProvider.currentLanguageCode),
          if (_patientProfile != null) _buildPatientHeaderCard(_patientProfile!),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.storageRepository.watchMessagesForConversation(widget.conversationId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                final assistantMsgs = messages.where((m) => m.role != MessageRole.user).toList();
                if (assistantMsgs.isNotEmpty) {
                  _lastAssistantMessage = assistantMsgs.last;
                }

                if (messages.isEmpty && !_isGenerating) {
                  return _buildEmptyState(langProvider);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + (_isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return _buildMessageBubble(messages[index]);
                    } else {
                      return _buildGeneratingIndicator(langProvider.currentLanguageCode);
                    }
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

  Widget _buildEmergencyBanner(String langCode) {
    final code = langCode.toLowerCase().split('-').first.split('_').first;
    String bannerText = 'For severe chest pain or breathing issues, call 112 / 108 immediately.';
    if (code == 'hi') {
      bannerText = 'गंभीर सीने में दर्द या सांस लेने में तकलीफ के लिए तुरंत 112 / 108 पर कॉल करें।';
    } else if (code == 'bn') {
      bannerText = 'বুকে প্রচণ্ড ব্যথা বা শ্বাসকষ্টের জন্য অবিলম্বে ১১২ / ১০৮ নম্বরে কল করুন।';
    } else if (code == 'ta') {
      bannerText = 'கடுமையான மார்பு வலி அல்லது மூச்சுத் திணறலுக்கு உடனடியாக 112 / 108 ஐ அழைக்கவும்.';
    } else if (code == 'te') {
      bannerText = 'తీవ్రమైన ఛాతీ నొప్పి లేదా శ్వాస తీసుకోవడంలో ఇబ్బంది ఉంటే వెంటనే 112 / 108 కి కాల్ చేయండి.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showEmergencyBanner = false;
              });
            },
            child: const Icon(Icons.close, size: 16, color: Color(0xFF991B1B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeaderCard(PatientProfile p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFE0F2F1),
                  child: Text(
                    p.name.isNotEmpty ? p.name[0] : 'P',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A6A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.bloodGroup,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          if (p.allergies.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                '⚠️ Allergy: ${p.allergies.first}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${p.room ?? "General Ward"} • ${p.doctorName ?? "Dr. Rajesh V. Sharma"}',
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

  Widget _buildEmptyState(LanguageProvider langProvider) {
    final localizedSuggestions = _getLocalizedSuggestions(langProvider.currentLanguageCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_information_outlined,
              size: 44,
              color: Color(0xFF006A6A),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _getLocalizedGreeting(langProvider.currentLanguageCode),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getLocalizedSubtitle(langProvider.currentLanguageCode),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _getLocalizedSuggestedQuestionsHeader(langProvider.currentLanguageCode),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...localizedSuggestions.map((suggestion) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _sendMessage(suggestion),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: Color(0xFF006A6A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ashwini_logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF006A6A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF006A6A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
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
                          fontSize: 10,
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
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ashwini AI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF006A6A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sarvam TTS Speaker Button
                        ValueListenableBuilder<TtsPlaybackStatus>(
                          valueListenable: SarvamTtsService.instance.statusNotifier,
                          builder: (context, ttsStatus, _) {
                            final isThisPlaying = ttsStatus.activeMessageId == msg.id.toString() && ttsStatus.isPlaying;
                            final isThisLoading = ttsStatus.activeMessageId == msg.id.toString() && ttsStatus.isLoading;

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                if (isThisPlaying || isThisLoading) {
                                  SarvamTtsService.instance.stop();
                                } else {
                                  final langProvider = Provider.of<LanguageProvider>(context, listen: false);
                                  SarvamTtsService.instance.speak(
                                    text: msg.text,
                                    messageId: msg.id.toString(),
                                    languageCode: langProvider.currentLanguageCode,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isThisPlaying
                                      ? const Color(0xFFE0F2F1)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isThisPlaying ? const Color(0xFF006A6A) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isThisLoading) ...[
                                      const SizedBox(
                                        width: 11,
                                        height: 11,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('Loading audio...', style: TextStyle(fontSize: 9, color: Color(0xFF006A6A))),
                                    ] else if (isThisPlaying) ...[
                                      const Icon(Icons.stop_circle_rounded, size: 13, color: Color(0xFF006A6A)),
                                      const SizedBox(width: 3),
                                      const Text('Stop', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF006A6A))),
                                    ] else ...[
                                      const Icon(Icons.volume_up_rounded, size: 13, color: Color(0xFF475569)),
                                      const SizedBox(width: 3),
                                      const Text('Listen', style: TextStyle(fontSize: 9, color: Color(0xFF475569))),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
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
              margin: const EdgeInsets.only(top: 4, left: 8),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF006A6A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF006A6A),
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator(String langCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ashwini_logo.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF006A6A),
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _getLocalizedGeneratingText(langCode),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ValueListenableBuilder<SttStatus>(
          valueListenable: SarvamSttService.instance.statusNotifier,
          builder: (context, sttStatus, _) {
            final isListening = sttStatus.isListening;
            final isTranscribing = sttStatus.isTranscribing;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isListening)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Listening in ${langProvider.currentLanguage.name}... Tap mic when done',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isTranscribing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF006A6A).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Processing your voice...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF006A6A),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isListening ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isListening ? Colors.red.shade300 : Colors.transparent,
                          ),
                        ),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: _getLocalizedInputHint(
                              langProvider.currentLanguageCode,
                              isListening,
                              langProvider.currentLanguage.name,
                            ),
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isListening ? Colors.red.shade400 : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sarvam STT Microphone Button
                    Container(
                      decoration: BoxDecoration(
                        color: isListening
                            ? Colors.red
                            : const Color(0xFF006A6A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: isTranscribing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                                ),
                              )
                            : Icon(
                                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                color: isListening ? Colors.white : const Color(0xFF006A6A),
                                size: 20,
                              ),
                        tooltip: isListening ? 'Finish speaking' : 'Speak your question',
                        onPressed: _isGenerating || isTranscribing ? null : _handleMicPressed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Send Button
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF006A6A),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: _isGenerating
                            ? null
                            : () {
                                if (isListening) {
                                  _handleMicPressed();
                                } else {
                                  _sendMessage();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
