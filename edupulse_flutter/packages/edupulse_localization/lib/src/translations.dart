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
    },
    'te': {
      'app_title': 'ఎడ్యుపల్స్ AI',
      'splash_tagline': 'విద్యా స్పందన',
      'dashboard': 'డ్యాష్‌బోర్డ్',
      'dashboard_placeholder': 'ఎడ్యుపల్స్ పేరెంట్ యాప్‌నకు స్వాగతం',
      'retry': 'మళ్ళీ ప్రయత్నించండి',
      'error_loading': 'కాన్ఫిగరేషన్ లోడింగ్ లోపం',
      'version': 'వెర్షన్',
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
