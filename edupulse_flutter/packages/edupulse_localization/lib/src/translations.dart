import 'package:flutter/material.dart';

class EduLocalization {
  final Locale locale;

  const EduLocalization(this.locale);

  static EduLocalization? of(BuildContext context) {
    return Localizations.of<EduLocalization>(context, EduLocalization);
  }

  static const LocalizationsDelegate<EduLocalization> delegate =
      _EduLocalizationDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'EduPulse AI',
      'splash_tagline': 'Pulse of Education',
      'dashboard': 'Dashboard',
      'dashboard_placeholder': 'Welcome to EduPulse Parent App',
      'retry': 'Retry',
      'error_loading': 'Error Loading Config',
      'version': 'Version',
      'email': 'Email',
      'password': 'Password',
      'login': 'Login',
      'forgot_password': 'Forgot Password?',
      'email_required': 'Email is required',
      'password_required': 'Password is required',
      'remember_me': 'Remember Me',
      'login_failed': 'Login failed',
      'reset_link_sent': 'Password reset link sent to your email.',
      'back_to_login': 'Back to Login',
      'submit': 'Submit',
      'forgot_password_desc':
          'Enter your registered email to receive a password reset link.',
      'invalid_email_format': 'Please enter a valid email address',
      'today_collection': "Today's Collection",
      'month_collection': "Month's Collection",
      'pending_dues': 'Pending Dues',
      'defaulters': 'Defaulters',
      'outstanding_classes': 'Outstanding Classes',
      'quick_actions': 'Quick Actions',
      'pay_fees': 'Pay Fees',
      'attendance': 'Attendance',
      'homework': 'Homework',
      'report_cards': 'Report Cards',
      'no_data': 'No data found',
      'dashboard_error': 'Failed to fetch dashboard metrics',
      'logout': 'Logout',
      'attendance_percentage': 'Attendance Percentage',
      'present': 'Present',
      'absent': 'Absent',
      'leave': 'Leave',
      'late': 'Late',
      'holiday': 'Holiday',
      'offline_cache_warning': 'Offline: Showing cached data',
      'calendar': 'Calendar',
      'summary': 'Summary',
      'no_attendance': 'No attendance records found',
      'attendance_error': 'Failed to load attendance',
      'due_date': 'Due Date',
      'priority': 'Priority',
      'status': 'Status',
      'attachments': 'Attachments',
      'download': 'Download',
      'downloading': 'Downloading...',
      'download_success': 'Attachment downloaded successfully.',
      'no_homework': 'No homework assigned',
      'homework_error': 'Failed to load homework',
    },
    'te': {
      'app_title': 'ఎడ్యుపల్స్ AI',
      'splash_tagline': 'విద్యా స్పందన',
      'dashboard': 'డ్యాష్‌బోర్డ్',
      'dashboard_placeholder': 'ఎడ్యుపల్స్ పేరెంట్ యాప్‌నకు స్వాగతం',
      'retry': 'మళ్ళీ ప్రయత్నించండి',
      'error_loading': 'కాన్ఫిగరేషన్ లోడింగ్ లోపం',
      'version': 'వెర్షన్',
      'email': 'ఈమెయిల్',
      'password': 'పాస్‌వర్డ్',
      'login': 'లాగిన్',
      'forgot_password': 'పాస్‌వర్డ్ మర్చిపోయారా?',
      'email_required': 'ఈమెయిల్ అవసరం',
      'password_required': 'పాస్‌వర్డ్ అవసరం',
      'remember_me': 'నన్ను గుర్తుంచుకో',
      'login_failed': 'లాగిన్ విఫలమైంది',
      'reset_link_sent': 'పాస్‌వర్డ్ రీసెట్ లింక్ ఈమెయిల్‌కు పంపబడింది.',
      'back_to_login': 'లాగిన్ కి తిరిగి వెళ్ళండి',
      'submit': 'సమర్పించండి',
      'forgot_password_desc':
          'పాస్‌వర్డ్ రీసెట్ లింక్ పొందడానికి మీ ఈమెయిల్ నమోదు చేయండి.',
      'invalid_email_format': 'దయచేసి సరైన ఈమెయిల్ చిరునామాను నమోదు చేయండి',
      'today_collection': 'నేటి సేకరణ',
      'month_collection': 'ఈ నెల సేకరణ',
      'pending_dues': 'బాకీ ఉన్న బకాయిలు',
      'defaulters': 'బకాయిదారులు',
      'outstanding_classes': 'బాకీ ఉన్న క్లాసులు',
      'quick_actions': 'త్వరిత చర్యలు',
      'pay_fees': 'ఫీజు చెల్లింపు',
      'attendance': 'హాజరు',
      'homework': 'హోంవర్క్',
      'report_cards': 'రిపోర్ట్ కార్డులు',
      'no_data': 'డేటా కనుగొనబడలేదు',
      'dashboard_error': 'డ్యాష్‌బోర్డ్ గణాంకాలను పొందడం విఫలమైంది',
      'logout': 'లాగ్ అవుట్',
      'attendance_percentage': 'హాజరు శాతం',
      'present': 'హాజరు',
      'absent': 'గైర్హాజరు',
      'leave': 'సెలవు',
      'late': 'ఆలస్యం',
      'holiday': 'సెలవు దినం',
      'offline_cache_warning': 'ఆఫ్‌లైన్: కాష్ డేటా చూపబడుతోంది',
      'calendar': 'క్యాలెండర్',
      'summary': 'సారాంశం',
      'no_attendance': 'హాజరు రికార్డులు ఏవీ కనుగొనబడలేదు',
      'attendance_error': 'హాజరు లోడింగ్ విఫలమైంది',
      'due_date': 'గడువు తేదీ',
      'priority': 'ప్రాముఖ్యత',
      'status': 'స్థితి',
      'attachments': 'జోడింపులు',
      'download': 'డౌన్‌లోడ్',
      'downloading': 'డౌన్‌లోడ్ అవుతోంది...',
      'download_success': 'జోడింపు విజయవంతంగా డౌన్‌లోడ్ చేయబడింది.',
      'no_homework': 'హోంవర్క్ ఏదీ కేటాయించబడలేదు',
      'homework_error': 'హోంవర్క్ లోడింగ్ విఫలమైంది',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _EduLocalizationDelegate extends LocalizationsDelegate<EduLocalization> {
  const _EduLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'te'].contains(locale.languageCode);

  @override
  Future<EduLocalization> load(Locale locale) async {
    return EduLocalization(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<EduLocalization> old) => false;
}
