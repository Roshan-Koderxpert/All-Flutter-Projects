import 'package:field_service/app/routes/app_pages.dart';
import 'package:field_service/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/core/constants/app_colors.dart';
import 'app/core/localization/app_locale.dart';
import 'app/core/localization/app_translations.dart';
import 'app/core/services/translation_service.dart';
import 'app/core/theme/app_theme.dart';
import 'app/core/widgets/offline_banner.dart';

class FSMApp extends StatelessWidget {
  final String languageCode;
  final String initialThemeMode;

  const FSMApp({
    super.key,
    required this.languageCode,
    required this.initialThemeMode,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Field Service',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: initialThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,

      // Initial binding — registers all global services including TranslationService
      initialBinding: InitialBinding(),

      // Translations — English is bundled; all other languages loaded dynamically
      translations: AppTranslations(),
      locale: AppLocale.fromOdooCode(languageCode),
      fallbackLocale: AppLocale.fallback,

      // supportedLocales: we do NOT restrict this list.
      // Flutter uses it only as a hint to the OS for locale negotiation.
      // Leaving it empty means every locale is accepted — exactly what we want
      // for supporting all world languages without any hardcoding.
      supportedLocales: const [
        Locale('en', 'US'), // always present as fallback
      ],

      // Required delegates for date pickers, text direction, etc.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Resolve any locale Flutter sends us — accept everything.
      localeResolutionCallback: (locale, supported) =>
          locale ?? AppLocale.fallback,

      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return OfflineBannerHost(
          child: _TranslationDownloadOverlay(child: child),
        );
      },

      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,

      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

/// Shows a non-blocking progress bar at the bottom of the screen while
/// TranslationService is downloading a new language.
/// Disappears automatically once the download completes.
class _TranslationDownloadOverlay extends StatelessWidget {
  final Widget child;
  const _TranslationDownloadOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    // TranslationService might not be registered yet during very early build.
    if (!Get.isRegistered<TranslationService>()) return child;

    final ts = TranslationService.to;
    return Stack(
      children: [
        child,
        Obx(() {
          if (!ts.isDownloading.value) return const SizedBox.shrink();
          return Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _LanguageDownloadBanner(
              progress: ts.downloadProgress.value,
              langName: ts.currentLangName.value,
            ),
          );
        }),
      ],
    );
  }
}

class _LanguageDownloadBanner extends StatelessWidget {
  final double progress;
  final String langName;

  const _LanguageDownloadBanner({
    required this.progress,
    required this.langName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 8,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Downloading $langName translations… ${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    isDark ? Colors.white12 : const Color(0xFFE0E0E0),
                color: AppColors.primary,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
