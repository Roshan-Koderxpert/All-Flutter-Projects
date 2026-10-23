import 'package:flutter/cupertino.dart';

class SplashScreenProvider extends ChangeNotifier {
  bool _isSplashScreen = true;

  bool get isSplashScreen => _isSplashScreen;

  void setSplashScreen(bool isSplashScreen) {
    _isSplashScreen = isSplashScreen;
    notifyListeners();
  }
}
