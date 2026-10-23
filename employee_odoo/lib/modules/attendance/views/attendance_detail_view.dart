import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../data/models/attendance_record.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/attendance_detail_controller.dart';
import '../widgets/attendance_route_map.dart';
import '../../../core/utils/responsive.dart';

class AttendanceDetailView extends GetView<AttendanceDetailController> {
  const AttendanceDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          final r = controller.record.value;
          return Text(
            r?.detailTitle ?? 'Attendance',
            style: AppTextStyles.style(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          );
        }),
        centerTitle: false,
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ResponsiveBody(child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.style(color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: controller.loadDetail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final record = controller.record.value;
        if (record == null) return const SizedBox.shrink();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.loadDetail,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ApprovalStatusBar(status: record.displayApprovalStatus),
              const SizedBox(height: 16),
              _MainInfoCard(record: record),
              const SizedBox(height: 20),
              _EventSection(
                title: 'CHECK IN',
                meta: record.checkInMeta,
              ),
              const SizedBox(height: 20),
              if (!record.isOpen)
                _EventSection(
                  title: 'CHECK OUT',
                  meta: record.checkOutMeta,
                ),
              const SizedBox(height: 20),
              const _RouteSection(),
            ],
          ),
        );
      })),
    );
  }
}

class _ApprovalStatusBar extends StatelessWidget {
  const _ApprovalStatusBar({required this.status});

  final AttendanceApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Step(
          label: AttendanceApprovalStatus.toApprove.label,
          active: status == AttendanceApprovalStatus.toApprove,
          completed: status == AttendanceApprovalStatus.approved ||
              status == AttendanceApprovalStatus.refused,
        ),
        _Step(
          label: AttendanceApprovalStatus.approved.label,
          active: status == AttendanceApprovalStatus.approved,
          completed: status == AttendanceApprovalStatus.approved,
        ),
        _Step(
          label: AttendanceApprovalStatus.refused.label,
          active: status == AttendanceApprovalStatus.refused,
          completed: status == AttendanceApprovalStatus.refused,
          isLast: true,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.active,
    required this.completed,
    this.isLast = false,
  });

  final String label;
  final bool active;
  final bool completed;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = active || completed;
    final bg = reached ? AppColors.accent : AppColors.white;
    final textColor = reached ? Colors.white : AppColors.textSecondary;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          border: reached ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.style(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _MainInfoCard extends StatelessWidget {
  const _MainInfoCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final home = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : null;
    final avatar = home?.avatarBase64.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailField(
                  label: 'Employee',
                  value: record.employeeName.isNotEmpty
                      ? record.employeeName
                      : 'Employee',
                  leading: _EmployeeAvatar(
                    name: record.employeeName,
                    imageBase64: avatar,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailField(
                  label: 'Worked Time',
                  value: record.workedHoursLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailField(
                  label: 'Check In',
                  value: record.checkInLabel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailField(
                  label: 'Extra Hours',
                  value: record.extraHoursLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailField(
                  label: 'Check Out',
                  value: record.checkOutLabel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: record.displayApprovalStatus ==
                        AttendanceApprovalStatus.toApprove
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Get.snackbar(
                              'Refuse',
                              'Approval actions are managed in Odoo web.',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Refuse'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.title,
    required this.meta,
  });

  final String title;
  final AttendanceEventMeta meta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.style(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DetailField(
                      label: 'Mode',
                      value: meta.modeLabel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DetailField(
                      label: 'Localisation',
                      value: meta.localisationLabel,
                      trailing: meta.localisationLabel == 'Unknown'
                          ? Icon(
                              Icons.help_outline,
                              size: 14,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DetailField(
                      label: 'IP Address',
                      value: meta.ipAddress.isNotEmpty ? meta.ipAddress : '—',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DetailField(
                      label: 'GPS Coordinates',
                      value: meta.gpsCoordinates,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DetailField(
                      label: 'Browser',
                      value: meta.browser.isNotEmpty ? meta.browser : '—',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: meta.hasGps
                        ? InkWell(
                            onTap: () => _openMaps(meta.mapsUrl!),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 16,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'View on Maps',
                                  style: AppTextStyles.style(
                                    fontSize: 13,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMaps(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceDetailController>();
    return Obx(() {
      Widget body;
      if (controller.isLoadingRoute.value) {
        body = const SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      } else if (controller.routeUnavailable.value) {
        body = _note(
          'Route storage is not available. Ask your administrator to install '
          'the "Attendance GPS Route Tracking" module in Odoo.',
        );
      } else if (controller.routeErrorMessage.value.isNotEmpty) {
        body = _note(controller.routeErrorMessage.value);
      } else {
        body = AttendanceRouteMap(
          points: controller.routePoints.toList(),
          line: controller.routeLine.toList(),
          gaps: controller.routeGaps.toList(),   // add this
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROUTE',
            style: AppTextStyles.style(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ).copyWith(letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: body,
          ),
        ],
      );
    });
  }

  Widget _note(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: AppColors.textSecondary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.style(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.style(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ],
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({
    required this.name,
    required this.imageBase64,
  });

  final String name;
  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: _avatarImage(imageBase64),
      child: _avatarImage(imageBase64) == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.style(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }

  ImageProvider? _avatarImage(String? base64) {
    final sanitized = OdooImage.sanitize(base64);
    if (sanitized == null) return null;
    try {
      return MemoryImage(base64Decode(sanitized));
    } catch (_) {
      return null;
    }
  }
}
