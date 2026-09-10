class AppConfig {
  const AppConfig._();

  static const String turnCredentialsUrl = String.fromEnvironment(
    'TURN_CREDENTIALS_URL',
  );

  static bool get hasTurnCredentials => turnCredentialsUrl.trim().isNotEmpty;
}
