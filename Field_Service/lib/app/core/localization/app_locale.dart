import 'package:flutter/material.dart';

class AppLocale {
  AppLocale._();

  static const Locale fallback = Locale('en', 'US');
  static const List<Locale> supported = <Locale>[
    Locale('en', 'US'),
    Locale('de', 'DE'),
  ];

  static Locale fromOdooCode(String? code)  {
    final c = (code ?? '').trim();
    if (c.isEmpty) return fallback;
    final normalized = c.replaceAll('-', '_');
    final parts = normalized.split('_');
    if (parts.isEmpty) return fallback;
    final lang = parts.first.toLowerCase();
    for (final locale in supported) {
      if (locale.languageCode == lang) return locale;
    }
    return fallback;
  }
}
