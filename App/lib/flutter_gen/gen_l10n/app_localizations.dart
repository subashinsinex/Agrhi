import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
    Locale('te'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'AGRHI'**
  String get appTitle;

  /// The application subtitle
  ///
  /// In en, this message translates to:
  /// **'Smart Farming Solutions'**
  String get appSubtitle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Subtitle message
  ///
  /// In en, this message translates to:
  /// **'Enjoy our Services'**
  String get enjoyServices;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signIn;

  /// Sign up button text
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Don't have account text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Login success message
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccessful;

  /// Language selector title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Select language dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// My details section header
  ///
  /// In en, this message translates to:
  /// **'My Details'**
  String get myDetails;

  /// Features section header
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// Crop management feature
  ///
  /// In en, this message translates to:
  /// **'Crop Management'**
  String get cropManagement;

  /// Disease detection feature
  ///
  /// In en, this message translates to:
  /// **'Disease Detection'**
  String get diseaseDetection;

  /// Soil information feature
  ///
  /// In en, this message translates to:
  /// **'Soil Information'**
  String get soilInformation;

  /// Market prices feature
  ///
  /// In en, this message translates to:
  /// **'Market Prices'**
  String get marketPrices;

  /// Expert advice feature
  ///
  /// In en, this message translates to:
  /// **'Expert Advice'**
  String get expertAdvice;

  /// Weather forecast feature
  ///
  /// In en, this message translates to:
  /// **'Weather Forecast'**
  String get weatherForecast;

  /// Detection history feature
  ///
  /// In en, this message translates to:
  /// **'Detection History'**
  String get detectionHistory;

  /// Irrigation control feature
  ///
  /// In en, this message translates to:
  /// **'Irrigation Control'**
  String get irrigationControl;

  /// Farm analytics feature
  ///
  /// In en, this message translates to:
  /// **'Farm Analytics'**
  String get farmAnalytics;

  /// Livestock management feature
  ///
  /// In en, this message translates to:
  /// **'Livestock Management'**
  String get livestockManagement;

  /// Equipment tracking feature
  ///
  /// In en, this message translates to:
  /// **'Equipment Tracking'**
  String get equipmentTracking;

  /// Financial reports feature
  ///
  /// In en, this message translates to:
  /// **'Financial Reports'**
  String get financialReports;

  /// Dashboard menu item
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Plant doctor menu item
  ///
  /// In en, this message translates to:
  /// **'Plant Doctor'**
  String get plantDoctor;

  /// Analytics menu item
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// Soil health menu item
  ///
  /// In en, this message translates to:
  /// **'Soil Health'**
  String get soilHealth;

  /// Weather menu item
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// Settings menu item
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Help and support menu item
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// Logout menu item
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get confirmLogout;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout? You will need to login again to access your account.'**
  String get logoutMessage;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Logout success message
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get loggedOutSuccessfully;

  /// Coming soon placeholder text
  ///
  /// In en, this message translates to:
  /// **'Coming Soon!'**
  String get comingSoon;

  /// Feature under development message
  ///
  /// In en, this message translates to:
  /// **'This feature is under development and will be available soon.'**
  String get featureUnderDevelopment;

  /// Back to dashboard button text
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get backToDashboard;

  /// Label for crop selection section
  ///
  /// In en, this message translates to:
  /// **'Select Crop'**
  String get selectCrop;

  /// Hint text for crop dropdown
  ///
  /// In en, this message translates to:
  /// **'Choose a crop'**
  String get selectCropHint;

  /// Label for image capture section
  ///
  /// In en, this message translates to:
  /// **'Capture Image'**
  String get captureImage;

  /// Button text to take photo from camera
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Button text to choose image from gallery
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// Loading text while analyzing image
  ///
  /// In en, this message translates to:
  /// **'Analyzing image...'**
  String get analyzing;

  /// Header for detection results section
  ///
  /// In en, this message translates to:
  /// **'Detection Results'**
  String get detectionResults;

  /// Label for detected disease name
  ///
  /// In en, this message translates to:
  /// **'Disease:'**
  String get diseaseLabel;

  /// Label for confidence percentage
  ///
  /// In en, this message translates to:
  /// **'Confidence:'**
  String get confidenceLabel;

  /// Error message when detection fails
  ///
  /// In en, this message translates to:
  /// **'Detection failed. Please try again.'**
  String get detectionError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'ta', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
