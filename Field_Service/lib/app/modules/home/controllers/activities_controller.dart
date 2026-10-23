import 'package:get/get.dart';

import '../../../core/utils/logger.dart';
import '../../../data/repositories/chatter_repository.dart';

class ActivitiesController extends GetxController {
  ActivitiesController(this._repo);

  final ChatterRepository _repo;

  final activities = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final selectedTab = 'all'.obs; // all | overdue | today | upcoming

  Future<void> fetchActivities() async {
    isLoading.value = true;
    try {
      final rows = await _repo.fetchMyActivities();
      activities.assignAll(rows);
    } catch (e) {
      AppLogger.error('fetchActivities failed', tag: 'ACTIVITIES', error: e);
      activities.clear();
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredActivities {
    if (selectedTab.value == 'all') return activities;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return activities.where((a) {
      final deadline = _parseDate(a['date_deadline']);
      if (deadline == null) return false;
      final d = DateTime(deadline.year, deadline.month, deadline.day);
      switch (selectedTab.value) {
        case 'overdue':
          return d.isBefore(today);
        case 'today':
          return d == today;
        case 'upcoming':
          return d.isAfter(today);
        default:
          return true;
      }
    }).toList();
  }

  int countForTab(String tab) {
    if (tab == 'all') return activities.length;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return activities.where((a) {
      final deadline = _parseDate(a['date_deadline']);
      if (deadline == null) return false;
      final d = DateTime(deadline.year, deadline.month, deadline.day);
      switch (tab) {
        case 'overdue':
          return d.isBefore(today);
        case 'today':
          return d == today;
        case 'upcoming':
          return d.isAfter(today);
        default:
          return true;
      }
    }).length;
  }

  void changeTab(String tab) => selectedTab.value = tab;

  Future<bool> markDone(int id) async {
    final ok = await _repo.markActivityDone(id);
    if (ok) await fetchActivities();
    return ok;
  }

  Future<bool> cancel(int id) async {
    final ok = await _repo.cancelActivity(id);
    if (ok) await fetchActivities();
    return ok;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null || raw == false) return null;
    final s = raw.toString();
    return DateTime.tryParse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
  }
}

