class AppConstants {
  static const String apiBaseUrl = 'https://api.hidavo.app';
  static const String appName = 'Flyprox';

  // Timer
  static const int timerDurationSeconds = 60 * 60; // 60 minutes
  static const int dailyQuizzesCount = 50;
  static const int questionsPerRound = 12;
  static const int optionsPerQuestion = 4;

  // Premium IAP product IDs
  static const String premiumProProductId = 'premium_pro_weekly';
  static const String premiumMaxProductId = 'premium_max_monthly';

  // Premium limits (Pro)
  static const int proWeeklyFullNameReveals = 2;
  static const int proWeeklyFirstLetterReveals = 2;

  // Registration — 18+ only
  static const int minAge = 18;
  static const int maxAge = 99;
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
  static const String telegramBotDeepLink =
      'tg://resolve?domain=HidavoBot&start=auth_';

  // URLs
  static const String marketingUrl =
      'https://distinct-lunaria-d0a.notion.site/41ae779d274281a095c3dd25afefafe2';
  static const String supportUrl =
      'https://distinct-lunaria-d0a.notion.site/41ae779d2742815494ebfa72e5db4620';
  static const String termsUrl =
      'https://distinct-lunaria-d0a.notion.site/41ae779d27428104bac7d2e41d83015a';
  static const String privacyUrl =
      'https://distinct-lunaria-d0a.notion.site/41ae779d27428120b9bbfb769e7063f6';
  static const String supportEmail = 'support@flyprox.com';
}
