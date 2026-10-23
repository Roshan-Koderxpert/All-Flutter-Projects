import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:uuid/uuid.dart';

import '../local_storage/shared_preferences.dart';
import '../utils/navigation_helper.dart';
import 'todo_home_controller.dart';
import '../models/account_model.dart';
import '../pages/account_setting/biometric_helper.dart';
import '../routes/app_routes.dart';


class AuthController extends GetxController {
  OdooClient? odooClient;

  var isLoading = false.obs;
  var isLoggedIn = false.obs;
  var userName = ''.obs;
  var odooUrl = ''.obs;

  var databases = <String>[].obs;
  var selectedDb = ''.obs;

  var companies = <Map<String, dynamic>>[].obs;
  var selectedCompanyIds = <int>[].obs;
  var selectedCompanyNames = ''.obs;
  var isMultiCompanyMode = true.obs;

  // ✅ Account Management
  var savedAccounts = <AccountModel>[].obs;
  var activeAccount = Rx<AccountModel?>(null);

  final _uuid = const Uuid();

  var selectedDatabase = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(selectedCompanyIds, (_) => _onCompanyChanged());
    loadSavedAccounts();
  }

  void _onCompanyChanged() {
    // Skip if no companies or still loading
    if (selectedCompanyIds.isEmpty || isLoading.value) {
      return;
    }

    print("🏢 Companies changed to: $selectedCompanyIds");
    _updateCompanyNamesDisplay();

    // ✅ SIMPLIFIED: Just trigger refresh if logged in
    if (isLoggedIn.value && odooClient != null) {
      // Small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 200), _refreshAllData);
    }
  }

  void _updateCompanyNamesDisplay() {
    if (selectedCompanyIds.isEmpty) {
      selectedCompanyNames.value = 'No company selected';
    } else {
      final names = companies
          .where((c) => selectedCompanyIds.contains(c['id']))
          .map((c) => c['name'] as String)
          .join(', ');
      selectedCompanyNames.value = names;
    }
  }

  void _refreshAllData() {
    if (Get.isRegistered<TodoHomeController>()) {
      Get.find<TodoHomeController>().loadStats();
    }
  }

  Future<void> loadSavedAccounts() async {
    try {
      savedAccounts.value = await SharedPreference.getAllAccounts();
      activeAccount.value = await SharedPreference.getActiveAccount();
      print("📋 Loaded ${savedAccounts.length} saved accounts");
    } catch (e) {
      print("❌ Error loading saved accounts: $e");
    }
  }

  /// ✅ Switch to a different saved account
  Future<void> switchAccount(AccountModel account) async {
    try {
      isLoading.value = true;

      print("🔄 Starting account switch to: ${account.username}");

      // ✅ Step 1: Clear current session
      await _clearCurrentSession();

      // ✅ Step 2: Initialize NEW Odoo client
      print("🔌 Initializing new Odoo client...");
      odooClient = OdooClient(account.url);
      odooUrl.value = account.url;

      // ✅ Step 3: Authenticate with saved credentials
      print("🔐 Authenticating as ${account.username}...");
      final session = await odooClient!.authenticate(
        account.database,
        account.username,
        account.password,
      );

      if (session.userId > 0) {
        print("✅ Authentication successful, UID: ${session.userId}");

        final userDetails = await fetchUserDetails(session.userId);

        final updatedAccount = account.copyWith(
          userId: session.userId,
          sessionId: session.id,
          lastLogin: DateTime.now(),
          isActive: true,
          name: userDetails?['name'] as String?,
          email: userDetails?['email'] as String?,
          image1920: userDetails?['image_1920'] as String?,
        );

        // ✅ Save this account as active
        await SharedPreference.saveAccount(updatedAccount);
        await SharedPreference.setActiveAccount(updatedAccount.id);

        // ✅ Update legacy storage for backward compatibility
        await SharedPreference.saveLogin(
          url: updatedAccount.url,
          db: updatedAccount.database,
          userId: updatedAccount.userId,
          sessionId: updatedAccount.sessionId ?? '',
          email: updatedAccount.username,
          password: updatedAccount.password,
        );

        // ✅ Step 5: Update state
        isLoggedIn.value = true;
        userName.value = account.username;
        activeAccount.value = updatedAccount;
        selectedDb.value = account.database;

        // ✅ Step 6: Fetch companies FIRST
        print("🏢 Fetching companies...");
        await fetchCompanies();

        // ✅ Step 7: Load saved accounts
        await loadSavedAccounts();

        print("✅ Account switch completed successfully");

        isLoading.value = false;

        // ✅ FIX: Close pages WITHOUT Get.back() to avoid snackbar error
        final currentRoute = Get.currentRoute;

        if (currentRoute.contains('add') || currentRoute.contains('Add')) {
          // Use Navigator directly instead of Get.back()
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Get.context != null && Navigator.canPop(Get.context!)) {
              Navigator.pop(Get.context!);
            }
          });
        }

        // ✅ Show success with ScaffoldMessenger (not Get.snackbar)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.context != null) {
            ScaffoldMessenger.of(Get.context!).showSnackBar(
              SnackBar(
                content: Text("Account switched to ${account.username}"),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });

        // ✅ Trigger refresh via reactive update
        selectedCompanyIds.refresh();

      } else {
        throw Exception('Failed to authenticate. Please check credentials.');
      }
    } catch (e) {
      print("❌ Switch account error: $e");
      isLoading.value = false;
      NavigationHelper.showSnackbar(
        title: 'Switch Failed',
        message: 'Could not switch to this account: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        textColor: Colors.red.shade900,
        duration: const Duration(seconds: 4),

      );
    }
  }

  Future<void> addNewAccount() async {
    if (activeAccount.value == null) {


      NavigationHelper.showSnackbar(
        title: 'Error',
        message: 'No active session found',
        position: SnackPosition.BOTTOM,

      );
      return;
    }

    // Navigate to account selection/add page
    Get.toNamed(AppRoutes.addAccount);
  }

  /// ✅ Remove a saved account
  Future<void> removeAccount(AccountModel account) async {
    try {
      if (account.isActive && savedAccounts.length == 1) {
        NavigationHelper.showSnackbar(
          title: 'Cannot Remove',
          message: 'Cannot remove the only active account. Please add another account first.',
          position: SnackPosition.BOTTOM,
        );
        return;
      }

      await SharedPreference.deleteAccount(account.id);
      await loadSavedAccounts();



      NavigationHelper.showSnackbar(
        title: 'Account Removed',
        message: '${account.username} has been removed',
        position: SnackPosition.BOTTOM,
      );

      // If removed account was active, switch to another account
      if (account.isActive && savedAccounts.isNotEmpty) {
        await switchAccount(savedAccounts.first);
      }
    } catch (e) {
      print("❌ Error removing account: $e");

      NavigationHelper.showSnackbar(
        title: 'Error',
        message: 'Failed to remove account',
        position: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> fetchCompanies() async {
    try {
      if (odooClient == null) throw Exception("Not logged in!");

      final result = await odooClient!.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'currency_id', 'partner_id'],
          'order': 'name asc',
        },
      });

      companies.assignAll(List<Map<String, dynamic>>.from(result));

      if (companies.isNotEmpty && selectedCompanyIds.isEmpty) {
        final savedCompanyIds = await SharedPreference.getSelectedCompanyIds();

        if (savedCompanyIds != null && savedCompanyIds.isNotEmpty) {
          selectedCompanyIds.value = savedCompanyIds
              .where((id) => companies.any((c) => c['id'] == id))
              .toList();
        } else {
          selectedCompanyIds.value = [companies.first['id']];
        }

        _updateCompanyNamesDisplay();
        await SharedPreference.saveSelectedCompanyIds(selectedCompanyIds);
      }

      print("✅ Fetched ${companies.length} companies");
    } catch (e) {
      print("❌ Error fetching companies: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchUserDetails(int userId) async {
    try {
      if (odooClient == null) throw Exception("Not logged in!");

      final result = await odooClient!.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [['id', '=', userId]],
          ['name', 'email', 'image_1920', 'image_128']
        ],
        'kwargs': {},
      });

      if (result != null && result.isNotEmpty) {
        final userData = result[0] as Map<String, dynamic>;

        // ✅ FIX: Convert `false` to null for image fields
        if (userData['image_1920'] == false) {
          userData['image_1920'] = null;
        }
        if (userData['image_128'] == false) {
          userData['image_128'] = null;
        }

        print("🔍 User data fetched: ${userData.keys}");
        print("🔍 Image_1920: ${userData['image_1920'] != null ? 'Has image' : 'No image'}");

        return userData;
      }
    } catch (e) {
      print("❌ Error fetching user details: $e");
      return null;
    }
    return null;
  }

  Future<void> toggleCompany(int companyId) async {
    if (selectedCompanyIds.contains(companyId)) {
      if (selectedCompanyIds.length > 1) {
        selectedCompanyIds.remove(companyId);
      } else {




        NavigationHelper.showSnackbar(
          title: 'Cannot Deselect',
          message: 'At least one company must be selected',
          position: SnackPosition.BOTTOM,

        );
        return;
      }
    } else {
      selectedCompanyIds.add(companyId);
    }

    await SharedPreference.saveSelectedCompanyIds(selectedCompanyIds);

    NavigationHelper.showSnackbar(
      title: 'Companies Updated',
      message: '${selectedCompanyIds.length} company(ies) selected',
      position: SnackPosition.BOTTOM,
    );
  }

  Future<void> selectSingleCompany(int companyId) async {
    selectedCompanyIds.value = [companyId];
    await SharedPreference.saveSelectedCompanyIds(selectedCompanyIds);

    final company = companies.firstWhere((c) => c['id'] == companyId);

    NavigationHelper.showSnackbar(
      title: 'Company Selected',
      message: 'Now viewing: ${company['name']}',
      position: SnackPosition.BOTTOM,

    );

  }

  Future<void> selectAllCompanies() async {
    selectedCompanyIds.value = companies.map<int>((c) => c['id'] as int).toList();
    await SharedPreference.saveSelectedCompanyIds(selectedCompanyIds);


    NavigationHelper.showSnackbar(
      title: 'All Companies Selected',
      message: '${selectedCompanyIds.length} companies selected',
      position: SnackPosition.BOTTOM,

    );
  }

  Future<void> clearCompanySelection() async {
    if (companies.isNotEmpty) {
      selectedCompanyIds.value = [companies.first['id']];
      await SharedPreference.saveSelectedCompanyIds(selectedCompanyIds);
    }
  }

  Future<void> tryAutoLogin() async {
    try {
      // ✅ Check if user is logged in
      final loggedIn = await SharedPreference.isLoggedIn();
      if (!loggedIn) {
        print("⚠️ User not logged in, skipping auto-login");
        isLoggedIn.value = false;
        return;
      }

      // Try to get active account
      final account = await SharedPreference.getActiveAccount();

      if (account != null) {
        odooClient = OdooClient(account.url);
        odooUrl.value = account.url;

        final session = await odooClient!.authenticate(
          account.database,
          account.username,
          account.password,
        );

        if (session.userId > 0) {
          final userDetails = await fetchUserDetails(session.userId);

          final updatedAccount = account.copyWith(
            name: userDetails?['name'] as String?,
            email: userDetails?['email'] as String?,
            image1920: userDetails?['image_1920'] as String?,
          );

          userName.value = account.username;
          activeAccount.value = updatedAccount;
          selectedDb.value = account.database;

          await SharedPreference.saveAccount(updatedAccount);

          // Prompt biometric before company fetch so the user isn't blocked on
          // network after auth, and we skip fetch if unlock fails.
          final bool biometricPassed = await BiometricHelper.authenticateOnAppStart();

          if (!biometricPassed) {
            print("❌ Biometric authentication failed - logging out");

            isLoggedIn.value = false;
            odooClient = null;

            Get.offAllNamed(AppRoutes.login);

            Future.delayed(const Duration(milliseconds: 500), () {
              Get.snackbar(
                "Authentication Required",
                "Biometric authentication is required to access the app",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.shade100,
                colorText: Colors.red.shade900,
                duration: const Duration(seconds: 3),
              );
            });

            return;
          }

          isLoggedIn.value = true;
          print("✅ Auto-login success UID: ${session.userId}");

          await fetchCompanies();
          await loadSavedAccounts();
        } else {
          await SharedPreference.clearLogin();
          isLoggedIn.value = false;
        }
      } else {
        print("⚠️ No active account found");
        isLoggedIn.value = false;
      }
    } catch (e) {
      print("❌ Auto-login error: $e");
      await SharedPreference.clearLogin();
      isLoggedIn.value = false;
    }
  }


  Future<void> fetchDatabases(String url) async {
    try {
      isLoading.value = true;
      databases.clear();
      selectedDb.value = '';

      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw Exception('Invalid URL format');
      }

      odooClient = OdooClient(url);
      odooUrl.value = url;

      final dbList = await odooClient!.callRPC('/web/database/list', 'call', {});

      if (dbList != null && dbList is List && dbList.isNotEmpty) {
        databases.value = dbList.map((e) => e.toString()).toList();
        selectedDb.value = databases.first;
      } else {
        throw Exception('No databases found on this server');
      }
    } catch (e) {
      print("❌ Fetch databases error: $e");
      databases.clear();
      selectedDb.value = '';
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login(String url, String username, String password) async {
    try {
      String cleanUrl = url.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      if (selectedDb.value.isEmpty) {
        throw Exception('Please select a database');
      }

      odooClient = OdooClient(cleanUrl);

      print("Using DB: ${selectedDb.value}");

      final session = await odooClient!.authenticate(
        selectedDb.value,
        username,
        password,
      );

      if (session.userId > 0) {
        print("Logged in as UID: ${session.userId}");

        // ✅ FETCH USER DETAILS
        final userDetails = await fetchUserDetails(session.userId);

        // ✅ Create new account WITH user details
        final newAccount = AccountModel(
          id: _uuid.v4(),
          url: cleanUrl,
          database: selectedDb.value,
          username: username,
          password: password,
          userId: session.userId,
          sessionId: session.id,
          isActive: true,
          name: userDetails?['name'] as String?,
          email: userDetails?['email'] as String?,
          image1920: userDetails?['image_1920'] as String?,
        );

        // Save account
        await SharedPreference.saveAccount(newAccount);
        await SharedPreference.setActiveAccount(newAccount.id);

        // Legacy save for backward compatibility
        await SharedPreference.saveLogin(
          url: cleanUrl,
          db: selectedDb.value,
          userId: session.userId,
          sessionId: session.id,
          email: username,
          password: password,
        );

        isLoggedIn.value = true;
        userName.value = username;
        activeAccount.value = newAccount;

        await fetchCompanies();
        await loadSavedAccounts();

        Get.offAllNamed(AppRoutes.home);
      } else {
        throw Exception('Invalid credentials');
      }
    } catch (e) {
      print("❌ Login error: $e");
      rethrow;
    }
  }

  Future<void> _clearCurrentSession() async {
    try {
      // ✅ Just destroy Odoo session
      if (odooClient != null) {
        try {
          await odooClient!.destroySession();
          print("✅ Odoo session destroyed");
        } catch (e) {
          print("⚠️ Session destroy warning: $e");
        }
      }

      // ✅ Clear company data
      selectedCompanyIds.clear();
      selectedCompanyNames.value = '';
      companies.clear();

      print("✅ Session cleared");

      // ✅ Controllers will auto-cleanup via GetX lifecycle
    } catch (e) {
      print("❌ Error clearing session: $e");
    }
  }

  Future<void> logout() async {
    print("🚪 Starting logout process...");

    try {
      // ✅ Step 1: Remove current account from saved accounts
      if (activeAccount.value != null) {
        print("🗑️ Removing account: ${activeAccount.value!.username}");
        await SharedPreference.removeCurrentAccount(activeAccount.value!.id);
      }

      // ✅ Step 2: Clear current session
      await _clearCurrentSession();

      // ✅ Step 3: Clear local storage
      print("🧹 Clearing local storage...");
      await SharedPreference.clearLogin();

      // ✅ Step 4: Clear all state
      isLoggedIn.value = false;
      userName.value = '';
      databases.clear();
      selectedDb.value = '';
      odooClient = null;
      activeAccount.value = null;
      savedAccounts.clear();

      print("✅ Logout completed successfully");

      // ✅ Step 5: Navigate to login
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      print("❌ Logout error: $e");
      // Still navigate to login even if there's an error
      Get.offAllNamed(AppRoutes.login);
    }
  }

  /// ✅ Logout all accounts
  Future<void> logoutAllAccounts() async {
    print("🚪 Logging out all accounts...");

    try {
      await _clearCurrentSession();
      await SharedPreference.clearAllAccounts();
      await SharedPreference.clearLogin();

      isLoggedIn.value = false;
      userName.value = '';
      databases.clear();
      selectedDb.value = '';
      odooClient = null;
      activeAccount.value = null;
      savedAccounts.clear();

      print("✅ All accounts logged out");

      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      print("❌ Logout all error: $e");
      Get.offAllNamed(AppRoutes.login);
    }
  }
}