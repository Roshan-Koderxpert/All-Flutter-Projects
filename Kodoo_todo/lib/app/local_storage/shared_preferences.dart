// lib/local_storage/sharedpred.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_model.dart';


class SharedPreference {
  static const String _keyIsLoggedIn = "isLoggedIn";
  static const String _keyOdooUrl = "odooUrl";
  static const String _keyDb = "dbName";
  static const String _keyUserId = "userId";
  static const String _keySessionId = "sessionId";
  static const String _keyEmail = "email";
  static const String _keyPassword = "password"; // ⚠️ see security note below
  static const String _keyCompanyId = 'selected_company_id'; // ✨ NEW

  static const String _keyCompanyIds = 'selected_company_ids'; // ✅ NEW

  static const String _accountsKey = 'saved_accounts';
  static const String _activeAccountKey = 'active_account_id';



  /// Save login session (call this after successful authenticate)
  static Future<void> saveLogin({
    required String url,
    required String db,
    required int userId,
    required String sessionId,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyOdooUrl, url);
    await prefs.setString(_keyDb, db);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keySessionId, sessionId);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
  }

  /// Check login state
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Return session map (nulls if not present)
  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "url": prefs.getString(_keyOdooUrl),
      "db": prefs.getString(_keyDb),
      "userId": prefs.getInt(_keyUserId),
      "sessionId": prefs.getString(_keySessionId),
      "email": prefs.getString(_keyEmail),
      "password": prefs.getString(_keyPassword),
    };
  }


  /// ✨ Save selected company ID
  static Future<void> saveSelectedCompanyIds(List<int> companyIds) async {
    final prefs = await SharedPreferences.getInstance();
    final idsString = companyIds.join(',');
    await prefs.setString(_keyCompanyIds, idsString);
  }

  /// ✨ Get selected company ID
  static Future<List<int>?> getSelectedCompanyIds() async {
    final prefs = await SharedPreferences.getInstance();
    final idsString = prefs.getString(_keyCompanyIds);

    if (idsString == null || idsString.isEmpty) return null;

    return idsString.split(',').map((e) => int.parse(e)).toList();
  }

  /// Clear login (logout)
  static Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn); // ✅ ADD THIS - Important!
    await prefs.remove(_keyCompanyId);
    await prefs.remove(_keyCompanyIds);
    await prefs.remove(_keyOdooUrl);
    await prefs.remove(_keyDb);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keySessionId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
    await prefs.remove(_activeAccountKey); // ✅ ADD THIS - Important!
  }

  // =============================================
  // Account Management Methods
  // =============================================

  /// Save a new account
  static Future<void> saveAccount(AccountModel account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();

    // Check if account already exists
    final existingIndex = accounts.indexWhere(
            (a) => a.username == account.username && a.database == account.database
    );

    if (existingIndex != -1) {
      // Update existing account
      accounts[existingIndex] = account;
    } else {
      // Add new account
      accounts.add(account);
    }

    // Save all accounts
    final accountsJson = accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));

    // Set as active account
    if (account.isActive) {
      await prefs.setString(_activeAccountKey, account.id);
    }
  }

  /// Get all saved accounts
  static Future<List<AccountModel>> getAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsString = prefs.getString(_accountsKey);

    if (accountsString == null || accountsString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> accountsJson = jsonDecode(accountsString);
      return accountsJson.map((json) => AccountModel.fromJson(json)).toList();
    } catch (e) {
      print("Error loading accounts: $e");
      return [];
    }
  }

  /// Get active account
  static Future<AccountModel?> getActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeAccountKey);

    if (activeId == null) return null;

    final accounts = await getAllAccounts();
    try {
      return accounts.firstWhere((a) => a.id == activeId);
    } catch (e) {
      return null;
    }
  }

  /// Set active account
  static Future<void> setActiveAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();

    // Update all accounts - set only one as active
    final updatedAccounts = accounts.map((account) {
      return account.copyWith(isActive: account.id == accountId);
    }).toList();

    // Save updated accounts
    final accountsJson = updatedAccounts.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));
    await prefs.setString(_activeAccountKey, accountId);
  }

  /// Delete an account
  static Future<void> deleteAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();

    accounts.removeWhere((a) => a.id == accountId);

    // Save updated accounts
    final accountsJson = accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));

    // If deleted account was active, clear active account
    final activeId = prefs.getString(_activeAccountKey);
    if (activeId == accountId) {
      await prefs.remove(_activeAccountKey);
    }
  }

  /// Clear all accounts
  static Future<void> clearAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
    await prefs.remove(_activeAccountKey);
  }

  /// Get accounts for a specific database
  static Future<List<AccountModel>> getAccountsForDatabase(String database, String url) async {
    final allAccounts = await getAllAccounts();
    return allAccounts.where((a) => a.database == database && a.url == url).toList();
  }

  /// Remove current account from saved accounts list
  static Future<void> removeCurrentAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();

    // Remove the account with matching ID
    accounts.removeWhere((a) => a.id == accountId);

    // Save updated accounts list
    final accountsJson = accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(accountsJson));

    // If removed account was active, clear active account
    final activeId = prefs.getString(_activeAccountKey);
    if (activeId == accountId) {
      await prefs.remove(_activeAccountKey);
    }

    print("✅ Account $accountId removed from saved accounts");
  }

}
