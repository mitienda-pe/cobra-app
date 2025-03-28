class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'https://cobra.mitienda.host';
  
  // Authentication
  static const int otpLength = 6;
  static const int otpExpirationMinutes = 5;
  
  // Storage Keys
  static const String tokenStorageKey = 'auth_token';
  static const String userStorageKey = 'user_data';
  
  // Timeouts
  static const int connectionTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 10;
}
