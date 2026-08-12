import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('ru')
  ];

  /// Skip button on onboarding
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboarding_skip;

  /// Next button on onboarding
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboarding_next;

  /// Start button on last onboarding slide
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboarding_start;

  /// Onboarding slide 1 title
  ///
  /// In en, this message translates to:
  /// **'Vote Anonymously'**
  String get onboarding1_title;

  /// Onboarding slide 1 description
  ///
  /// In en, this message translates to:
  /// **'Answer fun questions about your classmates — nobody knows it\'s you. Complete anonymity guaranteed.'**
  String get onboarding1_desc;

  /// Onboarding slide 2 title
  ///
  /// In en, this message translates to:
  /// **'No Negativity'**
  String get onboarding2_title;

  /// Onboarding slide 2 description
  ///
  /// In en, this message translates to:
  /// **'Only positive questions that bring your class closer together. Safe and friendly environment for everyone.'**
  String get onboarding2_desc;

  /// Onboarding slide 3 title
  ///
  /// In en, this message translates to:
  /// **'Anonymous Feed'**
  String get onboarding3_title;

  /// Onboarding slide 3 description
  ///
  /// In en, this message translates to:
  /// **'See who got voted for in your class feed — and collect stars as you rise to the top.'**
  String get onboarding3_desc;

  /// Onboarding slide 4 title
  ///
  /// In en, this message translates to:
  /// **'Invite Your Friends'**
  String get onboarding4_title;

  /// Onboarding slide 4 description
  ///
  /// In en, this message translates to:
  /// **'More friends means more fun! Invite your classmates and unlock the full Hidavo experience.'**
  String get onboarding4_desc;

  /// Phone registration screen title
  ///
  /// In en, this message translates to:
  /// **'Sign in to Hidavo'**
  String get auth_phoneTitle;

  /// No description provided for @auth_phoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get auth_phoneSubtitle;

  /// No description provided for @auth_phoneContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get auth_phoneContinue;

  /// No description provided for @auth_otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get auth_otpTitle;

  /// No description provided for @auth_otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Code sent to'**
  String get auth_otpSubtitle;

  /// No description provided for @auth_otpOpenTelegram.
  ///
  /// In en, this message translates to:
  /// **'Open Telegram'**
  String get auth_otpOpenTelegram;

  /// No description provided for @auth_otpGetWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Get code via WhatsApp'**
  String get auth_otpGetWhatsApp;

  /// No description provided for @auth_otpResend.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get auth_otpResend;

  /// No description provided for @auth_otpTimer.
  ///
  /// In en, this message translates to:
  /// **'Retry in'**
  String get auth_otpTimer;

  /// No description provided for @auth_otpWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Please try again'**
  String get auth_otpWrongCode;

  /// No description provided for @auth_otpExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Request a new one'**
  String get auth_otpExpired;

  /// No description provided for @auth_otpTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in 1 minute'**
  String get auth_otpTooMany;

  /// No description provided for @reg_header.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get reg_header;

  /// No description provided for @reg_firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get reg_firstName;

  /// No description provided for @reg_lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get reg_lastName;

  /// No description provided for @reg_genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get reg_genderMale;

  /// No description provided for @reg_genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get reg_genderFemale;

  /// No description provided for @reg_ageHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter your real age'**
  String get reg_ageHint;

  /// No description provided for @reg_ageModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Age Restriction'**
  String get reg_ageModalTitle;

  /// No description provided for @reg_ageModalMessage.
  ///
  /// In en, this message translates to:
  /// **'Unfortunately, the app is only available for users aged 14 to 19.'**
  String get reg_ageModalMessage;

  /// No description provided for @location_header.
  ///
  /// In en, this message translates to:
  /// **'Choose your city'**
  String get location_header;

  /// No description provided for @location_subtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll show nearby schools and friends'**
  String get location_subtitle;

  /// No description provided for @location_search.
  ///
  /// In en, this message translates to:
  /// **'Search city...'**
  String get location_search;

  /// No description provided for @location_noCity.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find your location?'**
  String get location_noCity;

  /// No description provided for @location_support.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get location_support;

  /// No description provided for @school_header.
  ///
  /// In en, this message translates to:
  /// **'Choose your school'**
  String get school_header;

  /// No description provided for @school_search.
  ///
  /// In en, this message translates to:
  /// **'Search school...'**
  String get school_search;

  /// No description provided for @class_header.
  ///
  /// In en, this message translates to:
  /// **'Choose your class'**
  String get class_header;

  /// No description provided for @username_title.
  ///
  /// In en, this message translates to:
  /// **'Create a username'**
  String get username_title;

  /// No description provided for @username_available.
  ///
  /// In en, this message translates to:
  /// **'Username available'**
  String get username_available;

  /// No description provided for @username_taken.
  ///
  /// In en, this message translates to:
  /// **'Username taken'**
  String get username_taken;

  /// No description provided for @contacts_title.
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get contacts_title;

  /// No description provided for @contacts_description.
  ///
  /// In en, this message translates to:
  /// **'Enable contacts access to find your friends'**
  String get contacts_description;

  /// No description provided for @contacts_button.
  ///
  /// In en, this message translates to:
  /// **'Enable contacts'**
  String get contacts_button;

  /// No description provided for @photo_title.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get photo_title;

  /// No description provided for @photo_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a photo so your friends can recognize you'**
  String get photo_subtitle;

  /// No description provided for @photo_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get photo_gallery;

  /// No description provided for @photo_camera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get photo_camera;

  /// No description provided for @voting_beforeVoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Wait for friends!'**
  String get voting_beforeVoteTitle;

  /// No description provided for @voting_beforeVoteDesc.
  ///
  /// In en, this message translates to:
  /// **'You need to add at least 3 friends to start voting.'**
  String get voting_beforeVoteDesc;

  /// No description provided for @voting_continueWithout.
  ///
  /// In en, this message translates to:
  /// **'Continue without friends'**
  String get voting_continueWithout;

  /// No description provided for @voting_question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get voting_question;

  /// No description provided for @voting_of.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get voting_of;

  /// No description provided for @voting_shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get voting_shuffle;

  /// No description provided for @voting_timerTitle.
  ///
  /// In en, this message translates to:
  /// **'Next round in...'**
  String get voting_timerTitle;

  /// No description provided for @voting_timerInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get voting_timerInvite;

  /// No description provided for @voting_timerDesc.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend and vote right now!'**
  String get voting_timerDesc;

  /// No description provided for @voting_goHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get voting_goHome;

  /// No description provided for @voting_starsReceived.
  ///
  /// In en, this message translates to:
  /// **'You received {count} stars!'**
  String voting_starsReceived(int count);

  /// No description provided for @voting_myCollection.
  ///
  /// In en, this message translates to:
  /// **'My collection'**
  String get voting_myCollection;

  /// No description provided for @voting_starTakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone voted for you!'**
  String get voting_starTakingTitle;

  /// No description provided for @voting_viewActivity.
  ///
  /// In en, this message translates to:
  /// **'View activity'**
  String get voting_viewActivity;

  /// No description provided for @invite_title.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get invite_title;

  /// No description provided for @invite_description.
  ///
  /// In en, this message translates to:
  /// **'Friend installed the app = you can vote right now!'**
  String get invite_description;

  /// No description provided for @invite_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get invite_share;

  /// No description provided for @invite_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get invite_copy;

  /// No description provided for @invite_copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get invite_copied;

  /// No description provided for @profile_stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get profile_stars;

  /// No description provided for @profile_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profile_friends;

  /// No description provided for @profile_votes.
  ///
  /// In en, this message translates to:
  /// **'Votes'**
  String get profile_votes;

  /// No description provided for @profile_collection.
  ///
  /// In en, this message translates to:
  /// **'My collection'**
  String get profile_collection;

  /// No description provided for @profile_editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profile_editProfile;

  /// No description provided for @profile_addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get profile_addFriend;

  /// No description provided for @profile_requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get profile_requestSent;

  /// No description provided for @profile_alreadyFriends.
  ///
  /// In en, this message translates to:
  /// **'You are friends'**
  String get profile_alreadyFriends;

  /// No description provided for @editProfile_title.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile_title;

  /// No description provided for @editProfile_changeSchool.
  ///
  /// In en, this message translates to:
  /// **'Change school'**
  String get editProfile_changeSchool;

  /// No description provided for @editProfile_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get editProfile_deleteAccount;

  /// No description provided for @editProfile_deleteAccountFinal.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get editProfile_deleteAccountFinal;

  /// No description provided for @editProfile_deleteScheduled.
  ///
  /// In en, this message translates to:
  /// **'Account will be deleted within 30 days'**
  String get editProfile_deleteScheduled;

  /// No description provided for @activity_title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity_title;

  /// No description provided for @activity_tabSchool.
  ///
  /// In en, this message translates to:
  /// **'In school'**
  String get activity_tabSchool;

  /// No description provided for @activity_tabMyLikes.
  ///
  /// In en, this message translates to:
  /// **'My likes'**
  String get activity_tabMyLikes;

  /// No description provided for @activity_empty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get activity_empty;

  /// No description provided for @activity_revealWho.
  ///
  /// In en, this message translates to:
  /// **'Find out who'**
  String get activity_revealWho;

  /// No description provided for @activity_voted.
  ///
  /// In en, this message translates to:
  /// **'voted for'**
  String get activity_voted;

  /// No description provided for @friends_title.
  ///
  /// In en, this message translates to:
  /// **'My friends'**
  String get friends_title;

  /// No description provided for @friends_empty.
  ///
  /// In en, this message translates to:
  /// **'No friends'**
  String get friends_empty;

  /// No description provided for @friends_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get friends_remove;

  /// No description provided for @friendRequests_title.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendRequests_title;

  /// No description provided for @friendRequests_accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendRequests_accept;

  /// No description provided for @friendRequests_decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendRequests_decline;

  /// No description provided for @friendRequests_empty.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get friendRequests_empty;

  /// No description provided for @search_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get search_placeholder;

  /// No description provided for @search_empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get search_empty;

  /// No description provided for @premium_title.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium_title;

  /// No description provided for @premium_proTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Pro'**
  String get premium_proTitle;

  /// No description provided for @premium_proPrice.
  ///
  /// In en, this message translates to:
  /// **'\$7.99 / week'**
  String get premium_proPrice;

  /// No description provided for @premium_proButton.
  ///
  /// In en, this message translates to:
  /// **'Get Pro'**
  String get premium_proButton;

  /// No description provided for @premium_maxTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Max'**
  String get premium_maxTitle;

  /// No description provided for @premium_maxPrice.
  ///
  /// In en, this message translates to:
  /// **'\$27.99 / month'**
  String get premium_maxPrice;

  /// No description provided for @premium_maxButton.
  ///
  /// In en, this message translates to:
  /// **'Get Max'**
  String get premium_maxButton;

  /// No description provided for @premium_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premium_restore;

  /// No description provided for @premium_activated.
  ///
  /// In en, this message translates to:
  /// **'Premium activated!'**
  String get premium_activated;

  /// No description provided for @premium_purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete purchase'**
  String get premium_purchaseError;

  /// No description provided for @premiumResult_remaining.
  ///
  /// In en, this message translates to:
  /// **'You have left:'**
  String get premiumResult_remaining;

  /// No description provided for @premiumResult_revealFirstLetter.
  ///
  /// In en, this message translates to:
  /// **'Reveal first letter'**
  String get premiumResult_revealFirstLetter;

  /// No description provided for @premiumResult_revealFullName.
  ///
  /// In en, this message translates to:
  /// **'Reveal full name'**
  String get premiumResult_revealFullName;

  /// No description provided for @premiumResult_limitExhausted.
  ///
  /// In en, this message translates to:
  /// **'Limit exhausted. Get Premium Max for unlimited'**
  String get premiumResult_limitExhausted;

  /// No description provided for @premiumResult_tapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap the card to reveal'**
  String get premiumResult_tapToReveal;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @settings_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settings_notifications;

  /// No description provided for @settings_newVotes.
  ///
  /// In en, this message translates to:
  /// **'New votes'**
  String get settings_newVotes;

  /// No description provided for @settings_timerExpired.
  ///
  /// In en, this message translates to:
  /// **'Timer expired'**
  String get settings_timerExpired;

  /// No description provided for @settings_editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settings_editProfile;

  /// No description provided for @settings_changePhone.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get settings_changePhone;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settings_deleteAccount;

  /// No description provided for @settings_logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settings_logout;

  /// No description provided for @settings_version.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settings_version;

  /// No description provided for @settings_terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get settings_terms;

  /// No description provided for @settings_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settings_privacy;

  /// No description provided for @settings_logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settings_logoutConfirm;

  /// No description provided for @collection_title.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection_title;

  /// No description provided for @collection_unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get collection_unlock;

  /// No description provided for @collection_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get collection_locked;

  /// No description provided for @collection_frames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get collection_frames;

  /// No description provided for @collection_badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get collection_badges;

  /// No description provided for @collection_backgrounds.
  ///
  /// In en, this message translates to:
  /// **'Backgrounds'**
  String get collection_backgrounds;

  /// No description provided for @common_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get common_loading;

  /// No description provided for @common_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_error;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_back;

  /// No description provided for @common_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get common_next;

  /// No description provided for @common_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get common_skip;

  /// No description provided for @common_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_done;

  /// No description provided for @common_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// No description provided for @common_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// No description provided for @common_unknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get common_unknownError;

  /// No description provided for @common_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get common_later;

  /// No description provided for @common_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continue;

  /// No description provided for @common_invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get common_invite;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
