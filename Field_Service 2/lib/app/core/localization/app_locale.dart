import 'package:flutter/material.dart';

class AppLocale {
  AppLocale._();

  static const Locale fallback = Locale('en', 'US');

  /// Converts an Odoo language code to a Flutter [Locale].
  /// Supports any language code Odoo uses, e.g.:
  ///   'en_US' → Locale('en','US')
  ///   'ar_001' → Locale('ar')
  ///   'zh_CN'  → Locale('zh','CN')
  ///   'fr_FR'  → Locale('fr','FR')
  ///   'hi_IN'  → Locale('hi','IN')
  static Locale fromOdooCode(String? code) {
    final c = (code ?? '').trim();
    if (c.isEmpty) return fallback;

    final normalized = c.replaceAll('-', '_');
    final parts = normalized.split('_');
    final lang = parts.first.toLowerCase();
    if (lang.isEmpty) return fallback;

    // Use country code only when it's a real ISO 3166-1 code (2 letters).
    if (parts.length > 1 && parts.last.length == 2) {
      return Locale(lang, parts.last.toUpperCase());
    }
    return Locale(lang);
  }
}
