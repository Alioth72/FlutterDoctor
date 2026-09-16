class AppConfig {
  const AppConfig._();

  static const String turnCredentialsUrl = String.fromEnvironment(
    'TURN_CREDENTIALS_URL',
    defaultValue:
        'https://sih-teleconsultation.metered.live/api/v1/turn/credentials?apiKey=b037e42a5a61defe95dc1f292598d60c79d5',
  );

  static const List<String> sarvamApiKeys = [
    'sk_rfg7nmlj_a5JVAc1PsHmW1l3IKtBMXioA',
    'sk_zjtuxntf_kgBFei7kGQ0AYfP3IhMaXqsu',
  ];
  static int _sarvamKeyIndex = 0;

  static String getNextSarvamKey() {
    final key = sarvamApiKeys[_sarvamKeyIndex % sarvamApiKeys.length];
    _sarvamKeyIndex++;
    return key;
  }

  static String get sarvamApiKey => getNextSarvamKey();

  static bool get hasTurnCredentials => turnCredentialsUrl.trim().isNotEmpty;
  static bool get hasSarvamKey => sarvamApiKeys.isNotEmpty;
}
