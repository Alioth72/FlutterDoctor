class AppConfig {
  const AppConfig._();

  static const String turnCredentialsUrl = String.fromEnvironment(
    'TURN_CREDENTIALS_URL',
    defaultValue:
        'https://sih-teleconsultation.metered.live/api/v1/turn/credentials?apiKey=b037e42a5a61defe95dc1f292598d60c79d5',
  );

  static const String sarvamApiKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: 'sk_r8oy8ofr_iIrWH1PKWxuEZZnRkp3Eca2s',
  );

  static bool get hasTurnCredentials => turnCredentialsUrl.trim().isNotEmpty;
  static bool get hasSarvamKey => sarvamApiKey.trim().isNotEmpty;
}
