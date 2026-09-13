class AppConfig {
  const AppConfig._();
  static const turnCredentialsUrl = String.fromEnvironment(
    'TURN_CREDENTIALS_URL',
    defaultValue:
        'https://sih-teleconsultation.metered.live/api/v1/turn/credentials?apiKey=b037e42a5a61defe95dc1f292598d60c79d5',
  );
  static bool get hasTurnCredentials => turnCredentialsUrl.trim().isNotEmpty;
}
