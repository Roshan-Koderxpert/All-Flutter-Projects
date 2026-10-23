import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/employee_directory_record.dart';
import '../../../data/repositories/employee_directory_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class EmployeeDirectoryController extends GetxController {
  late final EmployeeDirectoryRepository _repo;

  final _allEmployees = <EmployeeDirectoryRecord>[].obs;
  final isLoading = false.obs;
  final query = ''.obs;

  Timer? _debounce;

  /// GlobalKeys for each letter section header — used by the alphabet
  /// index bar to scroll the list into view without offset math.
  final Map<String, GlobalKey> sectionKeys = {};

  @override
  void onInit() {
    super.onInit();
    final client = Get.find<AuthController>().odooClient;
    _repo = EmployeeDirectoryRepository(client!);
    loadAll();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    final results = await _repo.search(query.value);
    _allEmployees.value = results;
    isLoading.value = false;
  }

  void onSearchChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), loadAll);
  }

  /// Employees grouped by first letter of name, sorted A→Z. Names not
  /// starting with a letter are bucketed under '#'.
  Map<String, List<EmployeeDirectoryRecord>> get groupedEmployees {
    final map = <String, List<EmployeeDirectoryRecord>>{};
    for (final e in _allEmployees) {
      final first = e.name.isNotEmpty ? e.name[0].toUpperCase() : '#';
      final key = RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
      map.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final k in sortedKeys) k: map[k]!};
  }

  // replace with
  List<String> get availableLetters => groupedEmployees.keys.toList();

  int get totalCount => _allEmployees.length;

  GlobalKey sectionKey(String letter) =>
      sectionKeys.putIfAbsent(letter, () => GlobalKey());

  /// Scrolls to the given letter, or the nearest available letter after it
  /// if that exact letter has no employees (matches iOS Contacts behavior).
  void scrollToLetter(String letter) {
    final letters = availableLetters;
    if (letters.isEmpty) return;
    final target = letters.firstWhereOrNull((l) => l.compareTo(letter) >= 0) ?? letters.last;
    final ctx = sectionKeys[target]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200));
    }
  }
}