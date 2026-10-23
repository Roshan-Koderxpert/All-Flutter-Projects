import 'package:get/get.dart';
import 'en_base_translations.dart';

/// Provides the bundled English translations to GetX at app start.
/// All other languages are loaded dynamically by [TranslationService].
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
        'en_US': EnBaseTranslations.all,
        'en': EnBaseTranslations.all,
      };
}
