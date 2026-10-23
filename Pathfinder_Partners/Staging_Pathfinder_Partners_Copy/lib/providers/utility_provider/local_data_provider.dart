import 'package:flutter/cupertino.dart';
import 'package:retail_gpt/local_storage/shared_preference.dart';

class LocalDataProvider extends ChangeNotifier {
  String _token = '';

  String get token => _token;

  int userId = -1;

  int get getUserId => userId;

  String _userName = '';

  String get userName => _userName;

  String _companyName = '';
  String get companyName  {
    if(_companyName.isEmpty) {
      // Simulate a delay to mimic fetching from a database or API
      SharedPreference.getCompanyName();
    }
    return _companyName;
  }

  void setCompanyName(String name) {
    _companyName = name;
    notifyListeners();
  }

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  void setUserId(int id) {
    userId = id;
    notifyListeners();
  }

  void clearData() {
    _token = '';
    userId = -1;
    _userName = '';
    notifyListeners();
  }
}
