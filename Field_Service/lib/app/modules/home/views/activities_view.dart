import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/assets.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/chatter_repository.dart';
import '../controllers/activities_controller.dart';

class ActivitiesView extends StatefulWidget {
  ActivitiesView({super.key});

  @override
  State<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends State<ActivitiesView> {
  final ActivitiesController controller =
      Get.put(ActivitiesController(Get.find<ChatterRepository>()));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.fetchActivities();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        toolbarHeight: 20,
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child:  Image.asset(AppImage.back,
                    height: 25, width: 25,
                    color: isDark ? AppColors.white: Colors.black ,

                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Activities',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _tabs(isDark),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final list = controller.filteredActivities;
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No activities found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => _card(context, list[i], isDark),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _tabs(bool isDark) {
    Widget item(String label, String value) {
      return Expanded(
        child: Obx(() {
          final selected = controller.selectedTab.value == value;
          return GestureDetector(
            onTap: () => controller.changeTab(value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primary
                          : (isDark ? Colors.white : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.countForTab(value)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          item('All', 'all'),
          item('Overdue', 'overdue'),
          item('Today', 'today'),
          item('Upcoming', 'upcoming'),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> a, bool isDark) {
    final id = a['id'];
    final aid = id is int ? id : int.tryParse('$id');
    final title = _str(a['summary']) ?? _str(a['res_name']) ?? 'Activity';
    final type = _m2oLabel(a['activity_type_id']) ?? 'Activity';
    final user = _m2oLabel(a['user_id']) ?? 'Unassigned';
    final dateRaw = _str(a['date_deadline']);
    final date = _formatDate(dateRaw);
    final dateColor = _dateColor(dateRaw);
    return Card(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (aid != null)
                  PopupMenuButton<String>(
                    icon: Image.asset(AppImage.more,height: 18, width: 18,  color: isDark ? Colors.white : AppColors.darkBackground,),
                    onSelected: (v) async {
                      if (v == 'done') {
                        final ok = await controller.markDone(aid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Activity marked as done' : 'Failed to mark as done')),
                          );
                        }
                      } else if (v == 'cancel') {
                        final ok = await controller.cancel(aid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Activity cancelled' : 'Failed to cancel activity')),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'done', child: Text('Mark as Done')),
                      PopupMenuItem(value: 'cancel', child: Text('Cancel Activity')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              type.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Assigned: $user',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(color: dateColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String? _str(dynamic v) {
    if (v == null || v == false || v == true) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _m2oLabel(dynamic v) {
    if (v is List && v.length >= 2) return v[1]?.toString();
    return null;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'No date';
    final dt = DateTime.tryParse(raw.contains('T') ? raw : raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today, ${DateFormat('hh:mm a').format(dt)}';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow, ${DateFormat('hh:mm a').format(dt)}';
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  Color _dateColor(String? raw) {
    if (raw == null || raw.isEmpty) return Colors.grey;
    final dt = DateTime.tryParse(raw.contains('T') ? raw : raw.replaceFirst(' ', 'T'));
    if (dt == null) return Colors.grey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d.isBefore(today)) return Colors.red;
    if (d == today) return Colors.orange;
    return Colors.green;
  }
}

