// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboarding_skip => 'Skip';

  @override
  String get onboarding_next => 'Next';

  @override
  String get onboarding_start => 'Get Started';

  @override
  String get onboarding1_title => 'Vote Anonymously';

  @override
  String get onboarding1_desc =>
      'Answer fun questions about your classmates — nobody knows it\'s you. Complete anonymity guaranteed.';

  @override
  String get onboarding2_title => 'No Negativity';

  @override
  String get onboarding2_desc =>
      'Only positive questions that bring your class closer together. Safe and friendly environment for everyone.';

  @override
  String get onboarding3_title => 'Anonymous Feed';

  @override
  String get onboarding3_desc =>
      'See who got voted for in your class feed — and collect stars as you rise to the top.';

  @override
  String get onboarding4_title => 'Invite Your Friends';

  @override
  String get onboarding4_desc =>
      'More friends means more fun! Invite your classmates and unlock the full OISTER experience.';

  @override
  String get auth_phoneTitle => 'Sign in to OISTER';

  @override
  String get auth_phoneSubtitle => 'Enter your phone number';

  @override
  String get auth_phoneContinue => 'Continue';

  @override
  String get auth_otpTitle => 'Enter code';

  @override
  String get auth_otpSubtitle => 'Code sent to';

  @override
  String get auth_otpOpenTelegram => 'Open Telegram';

  @override
  String get auth_otpGetWhatsApp => 'Get code via WhatsApp';

  @override
  String get auth_otpResend => 'Send again';

  @override
  String get auth_otpTimer => 'Retry in';

  @override
  String get auth_otpWrongCode => 'Wrong code. Please try again';

  @override
  String get auth_otpExpired => 'Code expired. Request a new one';

  @override
  String get auth_otpTooMany => 'Too many attempts. Try again in 1 minute';

  @override
  String get reg_header => 'Registration';

  @override
  String get reg_firstName => 'First name';

  @override
  String get reg_lastName => 'Last name';

  @override
  String get reg_genderMale => 'Male';

  @override
  String get reg_genderFemale => 'Female';

  @override
  String get reg_ageHint => 'Please enter your real age';

  @override
  String get reg_ageModalTitle => 'Age Restriction';

  @override
  String get reg_ageModalMessage =>
      'Unfortunately, the app is only available for users aged 14 to 19.';

  @override
  String get location_header => 'Choose your city';

  @override
  String get location_subtitle => 'We\'ll show nearby schools and friends';

  @override
  String get location_search => 'Search city...';

  @override
  String get location_noCity => 'Can\'t find your location?';

  @override
  String get location_support => 'Contact support';

  @override
  String get school_header => 'Choose your school';

  @override
  String get school_search => 'Search school...';

  @override
  String get class_header => 'Choose your class';

  @override
  String get username_title => 'Create a username';

  @override
  String get username_available => 'Username available';

  @override
  String get username_taken => 'Username taken';

  @override
  String get contacts_title => 'Find friends';

  @override
  String get contacts_description =>
      'Enable contacts access to find your friends';

  @override
  String get contacts_button => 'Enable contacts';

  @override
  String get photo_title => 'Add a photo';

  @override
  String get photo_subtitle => 'Add a photo so your friends can recognize you';

  @override
  String get photo_gallery => 'Choose from gallery';

  @override
  String get photo_camera => 'Take a photo';

  @override
  String get voting_beforeVoteTitle => 'Wait for friends!';

  @override
  String get voting_beforeVoteDesc =>
      'Your school doesn\'t have many participants yet. Invite friends to start voting';

  @override
  String get voting_continueWithout => 'Continue without friends';

  @override
  String get voting_question => 'Question';

  @override
  String get voting_of => 'of';

  @override
  String get voting_shuffle => 'Shuffle';

  @override
  String get voting_timerTitle => 'Next round in...';

  @override
  String get voting_timerInvite => 'Invite a friend';

  @override
  String get voting_timerDesc => 'Invite a friend and vote right now!';

  @override
  String get voting_goHome => 'Go home';

  @override
  String voting_starsReceived(int count) {
    return 'You received $count stars!';
  }

  @override
  String get voting_myCollection => 'My collection';

  @override
  String get voting_starTakingTitle => 'Someone voted for you!';

  @override
  String get voting_viewActivity => 'View activity';

  @override
  String get invite_title => 'Invite a friend';

  @override
  String get invite_description =>
      'Friend installed the app = you can vote right now!';

  @override
  String get invite_share => 'Share';

  @override
  String get invite_copy => 'Copy link';

  @override
  String get invite_copied => 'Link copied!';

  @override
  String get profile_stars => 'Stars';

  @override
  String get profile_friends => 'Friends';

  @override
  String get profile_votes => 'Votes';

  @override
  String get profile_collection => 'My collection';

  @override
  String get profile_editProfile => 'Edit profile';

  @override
  String get profile_addFriend => 'Add friend';

  @override
  String get profile_requestSent => 'Request sent';

  @override
  String get profile_alreadyFriends => 'You are friends';

  @override
  String get editProfile_title => 'Edit profile';

  @override
  String get editProfile_changeSchool => 'Change school';

  @override
  String get editProfile_deleteAccount => 'Delete account';

  @override
  String get editProfile_deleteAccountFinal => 'Delete permanently';

  @override
  String get editProfile_deleteScheduled =>
      'Account will be deleted within 30 days';

  @override
  String get activity_title => 'Activity';

  @override
  String get activity_tabSchool => 'In school';

  @override
  String get activity_tabMyLikes => 'My likes';

  @override
  String get activity_empty => 'No activity yet';

  @override
  String get activity_revealWho => 'Find out who';

  @override
  String get activity_voted => 'voted for';

  @override
  String get friends_title => 'My friends';

  @override
  String get friends_empty => 'No friends';

  @override
  String get friends_remove => 'Remove friend';

  @override
  String get friendRequests_title => 'Friend requests';

  @override
  String get friendRequests_accept => 'Accept';

  @override
  String get friendRequests_decline => 'Decline';

  @override
  String get friendRequests_empty => 'No requests';

  @override
  String get search_placeholder => 'Search users...';

  @override
  String get search_empty => 'Nothing found';

  @override
  String get premium_title => 'Premium';

  @override
  String get premium_proTitle => 'Premium Pro';

  @override
  String get premium_proPrice => '\$7.99 / week';

  @override
  String get premium_proButton => 'Get Pro';

  @override
  String get premium_maxTitle => 'Premium Max';

  @override
  String get premium_maxPrice => '\$27.99 / month';

  @override
  String get premium_maxButton => 'Get Max';

  @override
  String get premium_restore => 'Restore purchases';

  @override
  String get premium_activated => 'Premium activated!';

  @override
  String get premium_purchaseError => 'Failed to complete purchase';

  @override
  String get premiumResult_remaining => 'You have left:';

  @override
  String get premiumResult_revealFirstLetter => 'Reveal first letter';

  @override
  String get premiumResult_revealFullName => 'Reveal full name';

  @override
  String get premiumResult_limitExhausted =>
      'Limit exhausted. Get Premium Max for unlimited';

  @override
  String get premiumResult_tapToReveal => 'Tap the card to reveal';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_notifications => 'Notifications';

  @override
  String get settings_newVotes => 'New votes';

  @override
  String get settings_timerExpired => 'Timer expired';

  @override
  String get settings_editProfile => 'Edit profile';

  @override
  String get settings_changePhone => 'Change phone number';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_deleteAccount => 'Delete account';

  @override
  String get settings_logout => 'Sign out';

  @override
  String get settings_version => 'App version';

  @override
  String get settings_terms => 'Terms of use';

  @override
  String get settings_privacy => 'Privacy policy';

  @override
  String get settings_logoutConfirm => 'Are you sure you want to sign out?';

  @override
  String get collection_title => 'Collection';

  @override
  String get collection_unlock => 'Unlock';

  @override
  String get collection_locked => 'Locked';

  @override
  String get collection_frames => 'Frames';

  @override
  String get collection_badges => 'Badges';

  @override
  String get collection_backgrounds => 'Backgrounds';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_error => 'Error';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_back => 'Back';

  @override
  String get common_next => 'Next';

  @override
  String get common_skip => 'Skip';

  @override
  String get common_done => 'Done';

  @override
  String get common_ok => 'OK';

  @override
  String get common_close => 'Close';

  @override
  String get common_unknownError => 'Something went wrong';

  @override
  String get common_later => 'Later';

  @override
  String get common_continue => 'Continue';

  @override
  String get common_invite => 'Invite';
}
