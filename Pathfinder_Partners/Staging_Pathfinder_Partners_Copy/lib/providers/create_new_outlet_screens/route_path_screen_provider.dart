import 'package:flutter/cupertino.dart';

class RoutePlanScreenProvider extends ChangeNotifier {
  String _selectedState = '';

  String get selectedState => _selectedState;
  String _selectedCity = '';

  String get selectedCity => _selectedCity;
  void setSelectedState(String state) {
    _selectedState = state;
    _selectedCity = '';
    notifyListeners();
  }
  void setSelectedCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }
  void removeSelectedState() {
    _selectedState = '';
    _selectedCity = '';
    notifyListeners();
  }
  void removeSelectedCity() {
    _selectedCity = '';
    notifyListeners();
  }

  void clearData() {
    _selectedState = '';
    _selectedCity = '';
    notifyListeners();
  }
}
