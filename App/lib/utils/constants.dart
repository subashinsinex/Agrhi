class AppConstants {
  // App Information
  static const String appName = 'AGRHI';
  static const String appFullName = 'AGRHI - Smart Farming Solutions';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Revolutionizing agriculture with smart IoT solutions';

  // API Configuration
  static const String baseUrl = 'http://10.21.79.141:5000/api';
  static const String authEndpoint = '$baseUrl/auth';
  static const String loginEndpoint = '$authEndpoint/login';
  static const String signupEndpoint = '$authEndpoint/signup';
  static const String logoutEndpoint = '$authEndpoint/logout';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String isLoggedInKey = 'is_logged_in';
  static const String userPreferencesKey = 'user_preferences';

  // Validation Constants
  static const int minPasswordLength = 4;
  static const int maxPasswordLength = 50;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;

  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultRadius = 12.0;
  static const double smallRadius = 8.0;
  static const double largeRadius = 20.0;

  // Animation Durations
  static const int shortAnimationDuration = 200;
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;

  // Network Configuration
  static const int connectionTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;

  // Farm/Agriculture Related
  static const List<String> cropTypes = [
    'Rice',
    'Wheat',
    'Corn',
    'Tomato',
    'Potato',
    'Onion',
    'Cotton',
    'Sugarcane',
    'Other',
  ];

  static const List<String> soilTypes = [
    'Loamy',
    'Sandy',
    'Clay',
    'Silty',
    'Peaty',
    'Chalky',
  ];

  // Weather Units
  static const String temperatureUnit = '°C';
  static const String humidityUnit = '%';
  static const String windSpeedUnit = 'km/h';

  // Error Messages
  static const String networkErrorMessage =
      'Network error. Please check your connection.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';
  static const String unknownErrorMessage = 'An unexpected error occurred.';
  static const String invalidCredentialsMessage =
      'Invalid phone number or password.';
  static const String sessionExpiredMessage =
      'Session expired. Please login again.';

  // Success Messages
  static const String loginSuccessMessage = 'Login successful!';
  static const String logoutSuccessMessage = 'Logged out successfully';
  static const String dataUpdatedMessage = 'Data updated successfully';

  // Feature Flags (for future features)
  static const bool enableBiometricLogin = false;
  static const bool enableDarkMode = false;
  static const bool enableNotifications = true;
  static const bool enableOfflineMode = false;

  // Grid Configuration
  static const int dashboardGridColumns = 3;
  static const double dashboardGridAspectRatio = 0.85;
  static const double dashboardGridSpacing = 12.0;

  // Image Paths (when you add assets)
  static const String logoPath = 'assets/images/logo.png';
  static const String placeholderImagePath = 'assets/images/placeholder.png';
  static const String defaultAvatarPath = 'assets/images/default_avatar.png';

  // Timeouts and Delays
  static const Duration splashScreenDuration = Duration(seconds: 3);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration loadingDelay = Duration(milliseconds: 500);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // File Upload
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocumentTypes = ['pdf', 'doc', 'docx'];

  // Location
  static const double defaultLatitude = 13.0827; // Chennai
  static const double defaultLongitude = 80.2707; // Chennai
  static const double locationAccuracyRadius = 100.0; // meters

  // Notification Categories
  static const String weatherNotification = 'weather';
  static const String cropNotification = 'crop';
  static const String marketNotification = 'market';
  static const String systemNotification = 'system';

  // Device Types
  static const String mobileDevice = 'mobile';
  static const String tabletDevice = 'tablet';
  static const String webDevice = 'web';

  // Database Tables (if using local database)
  static const String usersTable = 'users';
  static const String farmsTable = 'farms';
  static const String cropsTable = 'crops';
  static const String weatherTable = 'weather_data';
  static const String notificationsTable = 'notifications';

  // Shared Preferences Keys
  static const String themeKey = 'app_theme';
  static const String languageKey = 'app_language';
  static const String notificationKey = 'notification_enabled';
  static const String locationKey = 'location_enabled';

  // Regular Expressions
  static const String phoneRegex = r'^\d{10,15}$';
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String nameRegex = r'^[a-zA-Z\s]+$';
  static const String numericRegex = r'^\d+(\.\d+)?$';

  // Status Codes
  static const int statusSuccess = 200;
  static const int statusCreated = 201;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusServerError = 500;

  // Crop Growth Stages
  static const List<String> cropStages = [
    'Seed',
    'Germination',
    'Seedling',
    'Vegetative',
    'Flowering',
    'Fruiting',
    'Maturity',
    'Harvest',
  ];

  // Soil Moisture Levels
  static const String soilDry = 'dry';
  static const String soilMoist = 'moist';
  static const String soilWet = 'wet';
  static const String soilSaturated = 'saturated';

  // Weather Conditions
  static const List<String> weatherConditions = [
    'Sunny',
    'Partly Cloudy',
    'Cloudy',
    'Overcast',
    'Light Rain',
    'Heavy Rain',
    'Thunderstorm',
    'Fog',
    'Windy',
  ];

  // Priority Levels
  static const String priorityLow = 'low';
  static const String priorityMedium = 'medium';
  static const String priorityHigh = 'high';
  static const String priorityUrgent = 'urgent';

  // Measurement Units
  static const String acreUnit = 'acres';
  static const String hectareUnit = 'hectares';
  static const String celsiusUnit = '°C';
  static const String fahrenheitUnit = '°F';
  static const String kmhUnit = 'km/h';
  static const String mphUnit = 'mph';
  static const String mmUnit = 'mm';
  static const String inchUnit = 'inches';
}
