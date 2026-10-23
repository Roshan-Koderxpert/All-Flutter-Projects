import 'package:field_service/app/routes/app_pages.dart';
import 'package:field_service/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/core/localization/app_locale.dart';
import 'app/core/localization/app_translations.dart';
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

      // Initial binding — registers global services
      initialBinding: InitialBinding(),
      translations: AppTranslations(),
      locale: AppLocale.fromOdooCode(languageCode),
      fallbackLocale: AppLocale.fallback,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return OfflineBannerHost(child: child);
      },

      // Routing (splash decides login vs dashboard from GetStorage)
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,

      // Default transitions
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}