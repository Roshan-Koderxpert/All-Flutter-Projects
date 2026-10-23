import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../data/repositories/auth_repository.dart';
import 'order_controller.dart';

class ProfileController extends GetxController {
  final AuthRepository _authRepository;
  final StorageService _storage = Get.find<StorageService>();

  ProfileController(this._authRepository);

  final profileName     = ''.obs;
  final profileImageUrl = ''.obs;
  final companies       = <Map<String, dynamic>>[].obs;
  final selectedCompanyIds = <int>[].obs;
  final draftSelectedCompanyIds = <int>[].obs;
  final isLoading       = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    await Future.wait([_loadProfile(), _loadCompanies()]);
    isLoading.value = false;
  }

  Future<void> _loadProfile() async {
    final data = await _authRepository.fetchProfile();
    if (data != null) {
      profileName.value     = data['name']?.toString() ?? '';
      profileImageUrl.value = data['image_url']?.toString() ?? '';
    }
  }

  Future<void> _loadCompanies() async {
    final list = await _authRepository.fetchCompanies();
    companies.value = list;
    final previouslySaved = _storage.selectedCompanyIds;

    // Offline / fetch failure: keep prior company scope so cached data keys
    // remain stable across app restarts without network.
    if (list.isEmpty) {
      selectedCompanyIds.value = List<int>.from(previouslySaved);
      draftSelectedCompanyIds.value = List<int>.from(previouslySaved);
      return;
    }

    final availableIds = list
        .map((c) => c['id'] as int?)
        .whereType<int>()
        .toSet();
    final saved = previouslySaved
        .where(availableIds.contains)
        .toList();
    final defaults = list
        .where((c) => c['is_current'] == true)
        .map((c) => c['id'] as int)
        .toList();
    selectedCompanyIds.value = saved.isNotEmpty
        ? saved
        : (defaults.isNotEmpty ? defaults : availableIds.toList());
    draftSelectedCompanyIds.value = List<int>.from(selectedCompanyIds);
    if (selectedCompanyIds.isNotEmpty) {
      await _storage.saveSelectedCompanyIds(selectedCompanyIds.toList());
    }
  }

  void toggleCompanySelection(int companyId, bool checked) {
    if (checked) {
      if (!draftSelectedCompanyIds.contains(companyId)) {
        draftSelectedCompanyIds.add(companyId);
      }
    } else {
      if (draftSelectedCompanyIds.length <= 1) return;
      draftSelectedCompanyIds.remove(companyId);
    }
  }

  void resetCompanySelectionDraft() {
    draftSelectedCompanyIds.value = List<int>.from(selectedCompanyIds);
  }

  Future<bool> confirmCompanySelection() async {
    final next = draftSelectedCompanyIds.toList()..sort();
    final current = selectedCompanyIds.toList()..sort();
    if (next.join(',') == current.join(',')) return false;
    selectedCompanyIds.value = List<int>.from(draftSelectedCompanyIds);
    await _storage.saveSelectedCompanyIds(selectedCompanyIds.toList());
    if (Get.isRegistered<OrderController>()) {
      await Get.find<OrderController>().loadOrders();
    }
    return true;
  }
}