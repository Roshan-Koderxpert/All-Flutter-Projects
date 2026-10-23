import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/odoo_image.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import '../../../data/models/employee_directory_record.dart';
import '../controllers/employee_directory_controller.dart';
import '../../../core/utils/responsive.dart';

class EmployeeDirectoryListView extends GetView<EmployeeDirectoryController> {
  const EmployeeDirectoryListView({super.key});

  static const _alphabet = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppMainAppBar(title: 'Employee Directory'),
      body: ResponsiveBody(child: Column(
        children: [
          _SearchBar(controller: controller),
          Expanded(
            child: _DirectoryBody(controller: controller, alphabet: _alphabet),
          ),
        ],
      )),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final EmployeeDirectoryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 22, color: AppColors.brandBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: controller.onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: AppTextStyles.style(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search by name, title, or department',
                      hintStyle: AppTextStyles.style(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Obx(() {
              if (controller.isLoading.value) return const SizedBox(height: 14);
              final count = controller.totalCount;
              return Text(
                count == 0 ? '' : '$count ${count == 1 ? 'employee' : 'employees'}',
                style: AppTextStyles.style(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DirectoryBody extends StatefulWidget {
  const _DirectoryBody({required this.controller, required this.alphabet});

  final EmployeeDirectoryController controller;
  final List<String> alphabet;

  @override
  State<_DirectoryBody> createState() => _DirectoryBodyState();
}

class _DirectoryBodyState extends State<_DirectoryBody> {
  String? _activeLetter;

  void _setActive(String? letter) {
    if (_activeLetter == letter) return;
    setState(() => _activeLetter = letter);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
      }
      final grouped = controller.groupedEmployees;
      if (grouped.isEmpty) return const _EmptyState();

      return Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 34, 20),
            children: [
              for (final letter in grouped.keys) ...[
                _SectionHeader(key: controller.sectionKey(letter), letter: letter),
                const SizedBox(height: 8),
                for (final e in grouped[letter]!) ...[
                  _EmployeeCard(employee: e),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
              ],
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _AlphabetIndexBar(
              letters: widget.alphabet,
              availableLetters: controller.availableLetters.toSet(),
              onLetterSelected: controller.scrollToLetter,
              onDragStateChanged: _setActive,
            ),
          ),
          if (_activeLetter != null) _LetterBubble(letter: _activeLetter!),
        ],
      );
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No employees found',
              style: AppTextStyles.style(fontSize: 15, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different name, title, or department.',
              style: AppTextStyles.style(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            letter,
            style: AppTextStyles.style(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.brandBlue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final EmployeeDirectoryRecord employee;

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final phone = employee.mobilePhone ?? employee.workPhone;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(AppRoutes.directoryDetail, arguments: employee.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandBlue.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _Avatar(employee: employee, radius: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: AppTextStyles.style(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (employee.jobTitle != null) ...[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                employee.jobTitle!,
                                style: AppTextStyles.style(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandOrange,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    if (employee.departmentName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.business_outlined, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              employee.departmentName!,
                              style: AppTextStyles.style(fontSize: 11.5, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (phone != null) ...[
                const SizedBox(width: 6),
                Material(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _call(phone),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.call_rounded, size: 17, color: AppColors.brandBlue),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee, required this.radius});

  final EmployeeDirectoryRecord employee;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final safe = OdooImage.sanitize(employee.avatarBase64);
    final avatar = safe != null
        ? CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(safe)))
        : CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brandBlue.withValues(alpha: 0.1),
      child: Text(
        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
        style: AppTextStyles.style(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.w700,
          color: AppColors.brandBlue,
        ),
      ),
    );

    if (employee.presence == EmployeePresence.unknown) return avatar;

    final dotColor = employee.presence == EmployeePresence.checkedIn
        ? const Color(0xFF22C55E)
        : AppColors.textSecondary.withValues(alpha: 0.6);
    final dotSize = radius * 0.5;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlphabetIndexBar extends StatefulWidget {
  const _AlphabetIndexBar({
    required this.letters,
    required this.availableLetters,
    required this.onLetterSelected,
    required this.onDragStateChanged,
  });

  final List<String> letters;
  final Set<String> availableLetters;
  final ValueChanged<String> onLetterSelected;
  final ValueChanged<String?> onDragStateChanged;

  @override
  State<_AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<_AlphabetIndexBar> {
  String? _pressed;

  void _handle(Offset localPosition, double height) {
    final itemHeight = height / widget.letters.length;
    final index = (localPosition.dy / itemHeight).floor().clamp(0, widget.letters.length - 1);
    final letter = widget.letters[index];
    if (letter != _pressed) {
      setState(() => _pressed = letter);
      widget.onDragStateChanged(letter);
      widget.onLetterSelected(letter);
    }
  }

  void _end() {
    setState(() => _pressed = null);
    widget.onDragStateChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (d) => _handle(d.localPosition, constraints.maxHeight),
          onVerticalDragEnd: (_) => _end(),
          onTapDown: (d) => _handle(d.localPosition, constraints.maxHeight),
          onTapUp: (_) => _end(),
          child: Container(
            width: 22,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: _pressed != null ? AppColors.inputFill : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final letter in widget.letters)
                  Text(
                    letter,
                    style: AppTextStyles.style(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: _pressed == letter
                          ? AppColors.brandOrange
                          : widget.availableLetters.contains(letter)
                          ? AppColors.brandBlue
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LetterBubble extends StatelessWidget {
  const _LetterBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.1, 0),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.blueGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            letter,
            style: AppTextStyles.style(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}