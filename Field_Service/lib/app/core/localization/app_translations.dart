import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
        'en_US': <String, String>{
          'app_full_name': 'Field Service Management',
          'sign_in': 'Sign In',
          'sign_out': 'Sign Out',
          'login': 'Log In',
          'next': 'Next',
          'login_credential_subtitle': 'Enter Your Credential to access the app',
          'login_server_subtitle': 'Configure Your Server Connection',
          'offline_banner_message':
              'Offline — you can keep using saved data on this device. Connect to sync with the server.',
          'field_required': 'This field is required',
          'username_required': 'Username is required',
          'password_required': 'Password is required',
          'password_min_length': 'Password must be at least 6 characters',
          'nav_order': 'Order',
          'nav_map': 'Map',
          'nav_my_profile': 'My Profile',
          'order_filter_new': 'New',
          'order_empty': 'No orders yet.',
        },
        'de_DE': <String, String>{
          'app_full_name': 'Field-Service-Management',
          'sign_in': 'Anmelden',
          'sign_out': 'Abmelden',
          'login': 'Einloggen',
          'next': 'Weiter',
          'login_credential_subtitle':
              'Geben Sie Ihre Zugangsdaten ein, um auf die App zuzugreifen',
          'login_server_subtitle': 'Konfigurieren Sie Ihre Serververbindung',
          'offline_banner_message':
              'Offline — Sie können weiterhin gespeicherte Daten auf diesem Gerät verwenden. Stellen Sie eine Verbindung her, um mit dem Server zu synchronisieren.',
          'field_required': 'Dieses Feld ist erforderlich',
          'username_required': 'Benutzername ist erforderlich',
          'password_required': 'Passwort ist erforderlich',
          'password_min_length':
              'Das Passwort muss mindestens 6 Zeichen lang sein',
          'nav_order': 'Auftrag',
          'nav_map': 'Karte',
          'nav_my_profile': 'Mein Profil',
          'order_filter_new': 'Neu',
          'order_empty': 'Noch keine Aufträge vorhanden.',
        },
      };
}
