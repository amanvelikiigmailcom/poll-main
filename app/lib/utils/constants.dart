class AppConstants {
  static const String apiBaseUrl = 'https://api.hidavo.app';
  static const String appName = 'Hidavo';

  // Timer
  static const int timerDurationSeconds = 40 * 60; // 40 minutes
  static const int dailyPollsCount = 50;
  static const int questionsPerRound = 12;
  static const int optionsPerQuestion = 4;

  // Premium IAP product IDs
  static const String premiumProProductId = 'premium_pro_weekly';
  static const String premiumMaxProductId = 'premium_max_monthly';

  // Premium limits (Pro)
  static const int proWeeklyFullNameReveals = 2;
  static const int proWeeklyFirstLetterReveals = 2;

  // Registration
  static const int minAge = 14;
  static const int maxAge = 19;
  static const int minGrade = 8;
  static const int maxGrade = 12;

  // Search
  static const int searchDebounceMs = 300;
  static const int minSearchCharsUser = 2;
  static const int minSearchCharsSchool = 3;

  // Validation
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;

  // Storage keys
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyCurrentUser = 'current_user';

  // Deep links
  static const String telegramBotDeepLink = 'tg://resolve?domain=HidavoBot&start=auth_';

  // URLs
  static const String termsUrl = 'https://hidavo.app/terms';
  static const String privacyUrl = 'https://hidavo.app/privacy';
  static const String supportEmail = 'support@hidavo.app';
}
