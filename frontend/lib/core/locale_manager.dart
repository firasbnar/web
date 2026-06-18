import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'storage.dart';

class LocaleManager {
  LocaleManager._();

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
  ];

  static const fallbackLocale = Locale('fr');

  static Future<Locale> resolveStartupLocale() async {
    final storedLocaleCode = await AppStorage().getLocaleCode();
    final normalized = normalizeLocaleCode(storedLocaleCode);
    return Locale(normalized);
  }

  static String normalizeLocaleCode(String? code) {
    switch ((code ?? '').toLowerCase()) {
      case 'en':
        return 'en';
      case 'ar':
        return 'ar';
      case 'fr':
      default:
        return fallbackLocale.languageCode;
    }
  }

  static Future<void> applyLocale(BuildContext context, String code) async {
    final normalized = normalizeLocaleCode(code);
    await AppStorage().saveLocaleCode(normalized);
    if (!context.mounted) return;
    await context.setLocale(Locale(normalized));
  }

  static bool isRtl(BuildContext context) =>
      context.locale.languageCode == 'ar';
}
