class AppConfig {
  const AppConfig._();

  static const String _defaultTurnUrl =
      'https://sih-teleconsultation.metered.live/api/v1/turn/credentials?apiKey=b037e42a5a61defe95dc1f292598d60c79d5';

  static const String turnCredentialsUrl = String.fromEnvironment(
    'TURN_CREDENTIALS_URL',
    defaultValue: _defaultTurnUrl,
  );

  static bool get hasTurnCredentials => turnCredentialsUrl.trim().isNotEmpty;
}
