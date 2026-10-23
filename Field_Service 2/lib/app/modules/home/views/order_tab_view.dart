import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/assets.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/kanban_column_vm.dart';
import '../../../data/models/order_model.dart';
import '../../../routes/app_routes.dart';
import 'activities_view.dart';
import '../controllers/order_controller.dart';

class OrderTabView extends GetView<OrderController> {
  const OrderTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? AppColors.darkBackground : AppColors.white,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.loadOrders,
        child: Obx(() {
          // Reading .value forces Obx to track kanbanColumns + activeFilters
          controller.kanbanColumns.value;
          controller.activeFilters.value;
          controller.activeGroupBy.value;
          controller.searchQuery.value;
          final list = controller.filteredOrders;
          final columns = controller.filteredKanbanColumns;
          final slivers = <Widget>[
            SliverToBoxAdapter(child: _buildOrderHeader(context)),
          ];

          final currentView = controller.selectedOrderView.value;

          if (controller.isLoading.value) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              );
            } else if (controller.errorMessage.value.isNotEmpty) {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.errorMessage.value,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: controller.loadOrders,
                            child: Text(AppStrings.orderTabRetry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else if (list.isEmpty) {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      AppStrings.orderEmpty,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            } else if (currentView == 'list') {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: _buildListViewTable(list),
                  ),
                ),
              );
            }  else if (currentView == 'calendar') {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: _buildCalendarViewSection(context),
                  ),
                ),
              );
            } else if (currentView != 'kanban') {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '${_viewLabel(currentView)} is selected.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            } else {
              final effectiveColumns = columns.isEmpty
                  ? <KanbanColumnVm>[
                      KanbanColumnVm(
                        title: AppStrings.orderKanbanDefaultCol,
                        orders: List<OrderModel>.from(list)
                          ..sort(OrderModel.compareKanban),
                      ),
                    ]
                  : columns;
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxHeight;
                      if (h <= 0) {
                        return const SizedBox.shrink();
                      }
                      return _KanbanBoard(
                        columns: effectiveColumns,
                        columnHeight: h,
                      );
                    },
                  ),
                ),
              );
            }
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          );
        }),
      ),
    );
  }

  String _viewLabel(String value) {
    switch (value) {
      case 'list':     return AppStrings.orderViewList;
      case 'calendar': return AppStrings.orderViewCalendar;
      default:         return AppStrings.orderViewKanban;
    }
  }

  PopupMenuItem<String> _buildMenuItem(dynamic icon, String text, String value) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    final isSelected = controller.selectedOrderView.value == value;

    // Define colors based on dark mode + selected state
    final Color iconColor = isDark
          ? (isSelected ? Colors.black: AppColors.white)
        : (isSelected ? AppColors.primary : AppColors.textPrimary);

    final Color textColor = isDark
        ? (isSelected ?  Colors.black : AppColors.white)
        : AppColors.textPrimary;

    return PopupMenuItem<String>(
      value: value,
      onTap: null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDE6E6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (icon is String)
              Image.asset(
                icon,
                height: 16,
                width: 16,
                color: iconColor,
              )
            else if (icon is IconData)
              Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            const SizedBox(width: 12),
            Text(
              text,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleViewSelection(BuildContext context, String value) {
    controller.setOrderView(value);
    if (value != 'kanban') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewLabel(value))),
      );
    }
  }

  Widget _buildListViewTable(List<OrderModel> orders) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    const colScheduled = 190.0;
    const colName = 210.0;
    const colLocation = 220.0;
    const colAssigned = 180.0;
    const colStage = 170.0;
    const colCompany = 180.0;
    const tableMinWidth =
        colScheduled + colName + colLocation + colAssigned + colStage + colCompany
            + 24;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
           borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableMinWidth,
            child: Column(
              children: [
                // Header
                Container(
                  color: isDark ? AppColors.darkCard : const Color(0xFFEDEDED),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      _listHeaderCell(AppStrings.orderListColScheduled, colScheduled),
                      _listHeaderCell(AppStrings.orderListColName,      colName),
                      _listHeaderCell(AppStrings.orderListColLocation,  colLocation),
                      _listHeaderCell(AppStrings.orderListColAssigned,  colAssigned),
                      _listHeaderCell(AppStrings.orderListColStage,     colStage),
                      _listHeaderCell(AppStrings.orderListColCompany,   colCompany, isLast: true),
                    ],
                  ),
                ),
                // Data rows
                if (orders.isNotEmpty)
                  Expanded(
                    child: ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      itemBuilder: (_, i) {
                        final order = orders[i];
                        return InkWell(
                          onTap: () => Get.toNamed(
                            AppRoutes.orderCreate,
                            arguments: {'orderId': int.tryParse(order.id)},
                          ),
                          child: Container(
                            color: isDark ? AppColors.darkCard : const Color(0xFFF8F8F8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                _listDataCell(
                                  order.scheduledStart.isEmpty
                                      ? '-'
                                      : order.scheduledStart,
                                  colScheduled,
                                ),
                                _listOrderNameCell(order, colName),
                                _listDataCell(
                                  order.subtitle.isEmpty ? '-' : order.subtitle,
                                  colLocation,
                                ),
                                _listDataCell(
                                  order.assignedTo.isEmpty ? '-' : order.assignedTo,
                                  colAssigned,
                                ),
                                _listDataCell(
                                  order.sectionLabel.isEmpty
                                      ? '-'
                                      : order.sectionLabel,
                                  colStage,
                                ),
                                _listDataCell(
                                  order.company.isEmpty ? '-' : order.company,
                                  colCompany,
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else ...[
                  const Divider(height: 1, color: Color(0xFFEDEDED)),
                  const SizedBox(height: 44),
                  const Divider(height: 1, color: Color(0xFFEDEDED)),
                  const SizedBox(height: 44),
                  const Divider(height: 1, color: Color(0xFFEDEDED)),
                  const SizedBox(height: 44),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildCalendarViewSection(BuildContext context) {
    return Obx(() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final selectedDay = controller.selectedCalendarDay.value;
      final focusedDay = controller.focusedCalendarDay.value;
      final dayOrders = controller.selectedDayOrders();

      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child:TableCalendar<OrderModel>(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: focusedDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (d) =>
                d.year == selectedDay.year &&
                    d.month == selectedDay.month &&
                    d.day == selectedDay.day,
                onDaySelected: controller.selectCalendarDay,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  headerPadding: const EdgeInsets.symmetric(vertical: 10),
                  leftChevronIcon: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: isDark ? AppColors.darkSurface2 : Colors.white,
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: isDark ? Colors.white : Colors.black,
                      size: 30,
                    ),
                  ),
                  rightChevronIcon: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: isDark ? AppColors.darkSurface2 : Colors.white,
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white : Colors.black,
                      size: 30,
                    ),
                  ),
                  leftChevronPadding: EdgeInsets.zero,
                  rightChevronPadding: EdgeInsets.zero,
                  leftChevronMargin: const EdgeInsets.only(left: 8),
                  rightChevronMargin: const EdgeInsets.only(right: 8),
                  headerMargin: const EdgeInsets.only(bottom: 8),
                  titleTextFormatter: (date, locale) =>
                  '${_monthName(date.month)}\n${date.year}',
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  weekendStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  dowTextFormatter: (date, locale) =>
                  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration:  BoxDecoration(
                    color: Color(0xffFDE6E6),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selectedTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  weekendTextStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  defaultTextStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  outsideTextStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade400,
                  ),
                ),
                calendarBuilders: CalendarBuilders<OrderModel>(
                  markerBuilder: (context, day, events) {
                    final count = controller.orderCountForDay(day);
                    if (count <= 0) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
              child: Text(
                '${AppStrings.orderCalendarOrdersOn}${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}',                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: dayOrders.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.orderCalendarNoOrders,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: dayOrders.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFEDEDED)),
                      itemBuilder: (_, i) {
                        final order = dayOrders[i];
                        return ListTile(
                          title: Text(
                            order.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            order.subtitle.isEmpty
                                ? (order.scheduledStart.isEmpty ? '-' : order.scheduledStart)
                                : '${order.subtitle} • ${order.scheduledStart.isEmpty ? '-' : order.scheduledStart}',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          onTap: () => Get.toNamed(
                            AppRoutes.orderCreate,
                            arguments: {'orderId': int.tryParse(order.id)},
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }

  Widget _listHeaderCell(String text, double width, {bool isLast = false}) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isLast)
            VerticalDivider(
              color: isDark ? AppColors.darkBorder : Colors.white,
              thickness: 1.5,
              width: 16,
            ),
        ],
      ),
    );
  }

  Widget _listDataCell(String text, double width, {bool isLast = false}) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isLast) const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _listOrderNameCell(OrderModel order, double width) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (order.isOfflineQueued) ...[
                  const SizedBox(height: 4),
                  const _OfflineQueuedLabel(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildOrderHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  AppStrings.navOrder,
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Obx(() => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // _BadgedIcon(
                      //   count: controller.messageBadgeCount.value,
                      //   child: IconButton(
                      //     padding: EdgeInsets.zero,
                      //     constraints: const BoxConstraints(
                      //       minWidth: 40,
                      //       minHeight: 40,
                      //     ),
                      //     onPressed: () {},
                      //     icon:  Image.asset(AppImage.chat,height: 24, width: 24,),
                      //   ),
                      // ),
                      const SizedBox(width: 4),
                      _BadgedIcon(
                        count: controller.historyBadgeCount.value,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: () => Get.to(() => ActivitiesView()),
                          icon:  Image.asset(AppImage.clock,height: 24, width: 24,  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              OutlinedButton(
                  onPressed: () => Get.toNamed(AppRoutes.orderCreate),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.white,                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 6),
                    minimumSize: const Size(0, 45),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(
                    AppStrings.orderFilterNew,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark ? AppColors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      inherit: false,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
                color:  isDark ? AppColors.darkSurface2 : Color(0xffF1F1F1)
              ),
              child: Theme(
              data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              ),
              child: PopupMenuButton<String>(
                color: isDark ? AppColors.darkSurface2 : AppColors.white,
                tooltip: AppStrings.orderViewKanban,
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  popUpAnimationStyle: AnimationStyle(
                    curve: Curves.easeOut,
                    duration: Duration(milliseconds: 150),
                  ),
                  icon: Obx(() {
                    final view = controller.selectedOrderView.value;
                    final iconPath = view == 'list'
                        ? AppImage.listview
                        : view == 'calendar'
                        ? AppImage.calendarview
                        : AppImage.kanban;
                    return Image.asset(iconPath, height: 22, width: 22,color:isDark ? AppColors.white :Colors.black);
                  }),
                  offset: const Offset(0, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) => _handleViewSelection(context, value),
                  itemBuilder: (context) => [
                    _buildMenuItem(AppImage.kanban,       AppStrings.orderViewKanban,   'kanban'),
                    _buildMenuItem(AppImage.listview,     AppStrings.orderViewList,     'list'),
                    _buildMenuItem(AppImage.calendarview, AppStrings.orderViewCalendar, 'calendar'),
                  ],
                ),
              ),
              ),
              const SizedBox(width: 8),
              const _AnimatedSearchBar(),
            ],
          ),
        ),
      ],
    );
  }

}



// ── Kanban Board with auto-scroll ─────────────────────────────────────────

class _KanbanBoard extends StatefulWidget {
  const _KanbanBoard({
    required this.columns,
    required this.columnHeight,
  });

  final List<KanbanColumnVm> columns;
  final double columnHeight;

  @override
  State<_KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<_KanbanBoard> {
  late List<KanbanColumnVm> _workingColumns;
  bool _savingDrop = false;
  bool _isDragging = false;

  final ScrollController _scrollCtrl = ScrollController();
  Timer? _scrollTimer;
  double _dragGlobalX = 0;

  @override
  void initState() {
    super.initState();
    _workingColumns = _cloneColumns(widget.columns);
  }

  @override
  void didUpdateWidget(covariant _KanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_savingDrop) return;
    _workingColumns = _cloneColumns(widget.columns);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<KanbanColumnVm> _cloneColumns(List<KanbanColumnVm> src) {
    return src
        .map((c) => KanbanColumnVm(
      title: c.title,
      stageId: c.stageId,
      folded: c.folded,
      orders: List<OrderModel>.from(c.orders),
    ))
        .toList();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragGlobalX = details.globalPosition.dx;
    _ensureScrollTimer();
  }

  void _ensureScrollTimer() {
    if (_scrollTimer != null && _scrollTimer!.isActive) return;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final screenWidth = MediaQuery.sizeOf(context).width;
      const triggerZone = 90.0;
      const maxSpeed = 14.0;

      if (_dragGlobalX > screenWidth - triggerZone) {
        // ── Scroll RIGHT ──
        final factor =
        ((_dragGlobalX - (screenWidth - triggerZone)) / triggerZone)
            .clamp(0.0, 1.0);
        final target = (_scrollCtrl.offset + maxSpeed * factor)
            .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
        _scrollCtrl.jumpTo(target);
      } else if (_dragGlobalX < triggerZone) {
        // ── Scroll LEFT ──
        final factor =
        ((triggerZone - _dragGlobalX) / triggerZone).clamp(0.0, 1.0);
        final target = (_scrollCtrl.offset - maxSpeed * factor)
            .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
        _scrollCtrl.jumpTo(target);
      } else {
        // Not in any trigger zone — stop timer
        _scrollTimer?.cancel();
        _scrollTimer = null;
      }
    });
  }

  void _onDragEnded() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    if (mounted) setState(() => _isDragging = false);
  }

  Future<void> _onDrop({
    required _DraggedOrder payload,
    required int targetColumnIndex,
    required int targetOrderIndex,
  }) async {
    final targetColumn = _workingColumns[targetColumnIndex];
    if (targetColumn.stageId == null) return;

    final snapshot = _cloneColumns(_workingColumns);
    var finalInsertIndex = targetOrderIndex;

    setState(() {
      _isDragging = false;
      final sourceList = _workingColumns[payload.fromColumnIndex].orders;
      final sourcePos =
      sourceList.indexWhere((o) => o.id == payload.order.id);
      if (sourcePos == -1) return;
      final moving = sourceList.removeAt(sourcePos);
      var insertIndex = targetOrderIndex;
      if (payload.fromColumnIndex == targetColumnIndex &&
          sourcePos < insertIndex) {
        insertIndex -= 1;
      }
      insertIndex = insertIndex.clamp(
          0, _workingColumns[targetColumnIndex].orders.length);
      _workingColumns[targetColumnIndex].orders.insert(insertIndex, moving);
      finalInsertIndex = insertIndex;
    });

    _savingDrop = true;
    final oc = Get.find<OrderController>();
    final ok = await oc.moveOrderToStage(
      order: payload.order,
      toStageId: targetColumn.stageId,
      toIndex: finalInsertIndex,
    );
    _savingDrop = false;

    if (!mounted) return;
    if (!ok) {
      setState(() => _workingColumns = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppStrings.orderKanbanMoveFailed)),
      );
      return;
    }
    setState(
            () => _workingColumns = _cloneColumns(oc.filteredKanbanColumns));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Single column fills ~90% of screen, capped for larger screens
    final columnWidth = (screenWidth * 0.88).clamp(300.0, 420.0);

    return ListView.separated(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: _workingColumns.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        if (index == _workingColumns.length) {
          return _AddStageCard(columnHeight: widget.columnHeight);
        }
        return _KanbanColumn(
          column: _workingColumns[index],
          columnIndex: index,
          columnHeight: widget.columnHeight,
          columnWidth: columnWidth,
          onDrop: _onDrop,
          onDragUpdate: _onDragUpdate,
          onDragStarted: () => setState(() => _isDragging = true),
          onDragEnded: _onDragEnded,
        );
      },
    );
  }
}

// ── Kanban Column with highlight + position indicator ─────────────────────

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    required this.column,
    required this.columnIndex,
    required this.columnHeight,
    required this.columnWidth,
    required this.onDrop,
    required this.onDragUpdate,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final KanbanColumnVm column;
  final int columnIndex;
  final double columnHeight;
  final double columnWidth;
  final Future<void> Function({
  required _DraggedOrder payload,
  required int targetColumnIndex,
  required int targetOrderIndex,
  }) onDrop;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  KanbanColumnVm get column => widget.column;
  double get columnHeight => widget.columnHeight;
  bool _isHighlighted = false;

  void _setHighlight(bool val) {
    if (_isHighlighted == val) return;
    if (mounted) setState(() => _isHighlighted = val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (column.folded) return _buildFoldedColumn(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: widget.columnWidth,
      height: columnHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _isHighlighted
            ? AppColors.primary.withOpacity(0.06)
            : Colors.transparent,
        border: Border.all(
          color: _isHighlighted
              ? AppColors.primary.withOpacity(0.35)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${column.title} (${column.orders.length})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: _isHighlighted
                          ? AppColors.primary
                          : (isDark ? Colors.white : AppColors.textPrimary),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showStageMenu(context),
                  child: Image.asset(
                    AppImage.setting,
                    height: 20,
                    width: 20,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Card list ─────────────────────────────────────────────────
          Expanded(
            child: column.orders.isEmpty
                ? _KanbanDropSlot(
              onHoverChanged: _setHighlight,
              onAccept: (payload) => widget.onDrop(
                payload: payload,
                targetColumnIndex: widget.columnIndex,
                targetOrderIndex: 0,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 32,
                      color: _isHighlighted
                          ? AppColors.primary
                          : AppColors.textDisabled,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isHighlighted ? AppStrings.orderKanbanDropHere : AppStrings.orderKanbanNoOrders,                      style: AppTextStyles.bodySmall.copyWith(
                        color: _isHighlighted
                            ? AppColors.primary
                            : AppColors.textDisabled,
                        fontWeight: _isHighlighted
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              // interleaved: slot(0) card(1) slot(2) card(3) ...
              itemCount: (column.orders.length * 2) + 1,
              itemBuilder: (context, index) {
                if (index.isEven) {
                  final insertAt = index ~/ 2;
                  return _KanbanDropSlot(
                    onHoverChanged: _setHighlight,
                    onAccept: (payload) => widget.onDrop(
                      payload: payload,
                      targetColumnIndex: widget.columnIndex,
                      targetOrderIndex: insertAt,
                    ),
                  );
                }
                final orderIndex = index ~/ 2;
                final order = column.orders[orderIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: LongPressDraggable<_DraggedOrder>(
                    data: _DraggedOrder(
                      order: order,
                      fromColumnIndex: widget.columnIndex,
                      fromOrderIndex: orderIndex,
                    ),
                    delay: const Duration(milliseconds: 200),
                    onDragStarted: widget.onDragStarted,
                    onDragEnd: (_) => widget.onDragEnded(),
                    onDragUpdate: widget.onDragUpdate,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Transform.rotate(
                        angle: 0.02,
                        child: SizedBox(
                          width: widget.columnWidth - 35,
                          child: Opacity(
                            opacity: 0.92,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withOpacity(0.18),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  const BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _OrderCard(order: order),
                            ),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.28,
                      child: _OrderCard(order: order),
                    ),
                    child: _OrderCard(order: order),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldedColumn(BuildContext context) {
    return DragTarget<_DraggedOrder>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => widget.onDrop(
        payload: details.data,
        targetColumnIndex: widget.columnIndex,
        targetOrderIndex: 0,
      ),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () {
            if (column.stageId != null) {
              Get.find<OrderController>()
                  .toggleFoldStage(column.stageId!, true);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56,
            height: columnHeight,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isOver
                  ? AppColors.primary.withOpacity(0.08)
                  : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOver
                    ? AppColors.primary.withOpacity(0.4)
                    : const Color(0xFFE2E8F0),
                width: isOver ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Icon(Icons.unfold_more_rounded,
                    size: 20,
                    color: isOver
                        ? AppColors.primary
                        : AppColors.textDisabled),
                const SizedBox(height: 12),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      '${column.title} (${column.orders.length})',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isOver
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Stage menu — keep all your existing methods unchanged ─────────────
  void _showStageMenu(BuildContext context) {
    final stageId = column.stageId;
    final oc = Get.find<OrderController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      column.title,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFEDEDED)),
              const SizedBox(height: 12),

              // ── Edit Stage ──
              _stageMenuTile(
                leading: Image.asset(
                  AppImage.editstage,
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                  height: 20,
                  width: 20,
                ),
                label: AppStrings.orderStageEdit,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditStageDialog(context, oc);
                },
              ),

              // ── Fold / Unfold ──
              if (stageId != null) ...[
                const SizedBox(height: 4),
                _stageMenuTile(
                  leading: Icon(
                    column.folded
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    color: isDark ? AppColors.white : AppColors.textPrimary,
                    size: 20,
                  ),
                  label: column.folded ? AppStrings.orderStageUnfold : AppStrings.orderStageFold,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    oc.toggleFoldStage(stageId, column.folded);
                  },
                ),
              ],

              // ── Delete Stage ──
              if (stageId != null) ...[ 
                const SizedBox(height: 4),
                _stageMenuTile(
                  leading: Image.asset(
                    AppImage.deletestage,
                    color: AppColors.error,
                    height: 20,
                    width: 20,
                  ),
                  label: AppStrings.orderStageDelete,
                  isDark: isDark,
                  labelColor: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteStageConfirm(context, oc);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageMenuTile({
    required Widget leading,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    Color? labelColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: leading)),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: labelColor ?? (isDark ? AppColors.white : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStageDialog(BuildContext context, OrderController oc) {
    final ctrl = TextEditingController(text: column.title);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.orderStageEdit,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Text field ──
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? AppColors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.orderStageNameHint,
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Save button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final name = ctrl.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(ctx);
                      if (column.stageId != null) oc.editStage(column.stageId!, name);
                    },
                    child:  Text(
                      AppStrings.orderStageSave,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteStageConfirm(BuildContext context, OrderController oc) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.orderStageDelete,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Message ──
                Text(
                  '${AppStrings.orderStageDeleteConfirm} "${column.title}"? ${AppStrings.orderStageDeleteCannotUndo}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Delete button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (column.stageId != null) oc.removeStage(column.stageId!);
                    },
                    child:  Text(
                        AppStrings.orderStageDeleteBtn,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
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

// ── Drop slot — shown between cards as insertion target ───────────────────

class _KanbanDropSlot extends StatefulWidget {
  const _KanbanDropSlot({
    required this.onAccept,
    required this.onHoverChanged,
    this.child,
  });

  final Future<void> Function(_DraggedOrder payload) onAccept;
  final void Function(bool hovering) onHoverChanged;
  final Widget? child;

  @override
  State<_KanbanDropSlot> createState() => _KanbanDropSlotState();
}

class _KanbanDropSlotState extends State<_KanbanDropSlot> {
  bool _hovering = false;

  void _setHover(bool val) {
    if (_hovering == val) return;
    setState(() => _hovering = val);
    widget.onHoverChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DraggedOrder>(
      onWillAcceptWithDetails: (_) {
        _setHover(true);
        return true;
      },
      onLeave: (_) => _setHover(false),
      onAcceptWithDetails: (details) async {
        _setHover(false);
        await widget.onAccept(details.data);
      },
      builder: (context, candidateData, _) {
        final active = _hovering || candidateData.isNotEmpty;

        // Full-column empty drop zone
        if (widget.child != null) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: active
                  ? AppColors.primary.withOpacity(0.06)
                  : Colors.transparent,
              border: Border.all(
                color: active
                    ? AppColors.primary.withOpacity(0.35)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: widget.child,
          );
        }

        // Between-card insertion indicator
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 28 : 8,
          margin: EdgeInsets.symmetric(vertical: active ? 2 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active
                ? AppColors.primary.withOpacity(0.10)
                : Colors.transparent,
          ),
          child: active
              ? Center(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )
              : null,
        );
      },
    );
  }
}


class _DraggedOrder {
  const _DraggedOrder({
    required this.order,
    required this.fromColumnIndex,
    required this.fromOrderIndex,
  });

  final OrderModel order;
  final int fromColumnIndex;
  final int fromOrderIndex;
}

class _OfflineQueuedLabel extends StatelessWidget {
  const _OfflineQueuedLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        AppStrings.orderOfflineLabel,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.child,
    required this.count,
  });

  final Widget child;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 2,
            top: 4,
            child: Container(
              constraints: const BoxConstraints(minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}



class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Get.toNamed(
        AppRoutes.orderCreate,
        arguments: {'orderId': int.tryParse(order.id)},
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ?  AppColors.darkCard : const Color(0xffF8F8F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xffE2E8F0),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F171717),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Color(0x1A171717),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          order.title,
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),

                    ],
                  ),
                  if (order.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      order.subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _PriorityStars(filled: order.priorityStars),
                ],
              ),
            ),
          ),
          if (order.isOfflineQueued)
            Positioned(
              top: 8,
              right: 8,
              child: _OfflineQueuedLabel(),
            ),
        ],
      ),
    );
  }
}

class _PriorityStars extends StatelessWidget {
  const _PriorityStars({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = filled.clamp(0, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final on = i < n;
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 2 : 0),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_border_rounded,
            size: 27,
            color: on
                ? const Color(0xffFFCC00)
                : (isDark ? Colors.white : const Color(0xff2B2A2A)),
          ),
        );
      }),
    );
  }
}

class _AnimatedSearchBar extends StatefulWidget {
  const _AnimatedSearchBar();

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _widthAnim;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OverlayPortalController _overlayCtrl = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  OrderController get _oc => Get.find<OrderController>();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _widthAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _textCtrl.addListener(() {
      _oc.searchQuery.value = _textCtrl.text;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_expanded) {
      _focusNode.unfocus();
      _textCtrl.clear();
      _oc.searchQuery.value = '';
      if (_overlayCtrl.isShowing) _overlayCtrl.hide();
      _ctrl.reverse().then((_) {
        if (mounted) setState(() => _expanded = false);
      });
    } else {
      setState(() => _expanded = true);
      _ctrl.forward().then((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _toggleDropdown() {
    if (_overlayCtrl.isShowing) {
      _overlayCtrl.hide();
    } else {
      _overlayCtrl.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final expandedWidth = screenWidth - 16 - 88 - 8 - 40 - 8 - 40 - 8.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayCtrl,
        overlayChildBuilder: (ctx) {
          return CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: Align(
              alignment: Alignment.topRight,
              child: _FilterDropdown(
                onClose: () => _overlayCtrl.hide(),
              ),
            ),
          );
        },
        child: AnimatedBuilder(
          animation: _widthAnim,
          builder: (context, child) {
            final w = _expanded
                ? 40 + (expandedWidth - 40) * _widthAnim.value
                : 40.0;
            return Container(
              width: w,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F1F1),
              ),
              child: Row(
                children: [
                  // Search icon
                  GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Image.asset(
                        AppImage.search,
                        height: 22,
                        width: 22,
                        color: _expanded
                            ? AppColors.primary
                            : isDark
                            ? AppColors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_expanded)
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        focusNode: _focusNode,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: AppStrings.orderSearchHint,
                          hintStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textHint),
                          border: InputBorder.none,
                          isDense: true,
                          filled: false,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: GestureDetector(
                            onTap: _toggleDropdown,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Image.asset(
                                AppImage.arrow_down,
                                width: 18,
                                height: 18,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Filter Dropdown Panel ──────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final VoidCallback onClose;
  const _FilterDropdown({required this.onClose});

  OrderController get _oc => Get.find<OrderController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.sizeOf(context).width - 32,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters column
            Expanded(
              child: _FilterSection(onClose: onClose),
            ),
            Container(width: 1, color: AppColors.divider),
            // Group By column
            Expanded(
              child: _GroupBySection(onClose: onClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final VoidCallback onClose;
  const _FilterSection({required this.onClose});

  OrderController get _oc => Get.find<OrderController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Obx(() {
        final active = _oc.activeFilters;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(AppStrings.orderFilterTitle,
                    style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.white : AppColors.textPrimary,

                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            _FilterTile(
              label: AppStrings.orderFilterMyOrders,
              value: 'my_orders',
              active: active.contains('my_orders'),
              onTap: () => _oc.toggleFilter('my_orders'),
            ),
            const Divider(height: 16, color: AppColors.divider),
            _FilterTile(
              label: AppStrings.orderFilterTodo,
              value: 'todo',
              active: active.contains('todo'),
              onTap: () => _oc.toggleFilter('todo'),
            ),
            _FilterTile(
              label: AppStrings.orderFilterUnassigned,
              value: 'unassigned',
              active: active.contains('unassigned'),
              onTap: () => _oc.toggleFilter('unassigned'),
            ),
            _FilterTile(
              label: AppStrings.orderFilterUnscheduled,
              value: 'unscheduled',
              active: active.contains('unscheduled'),
              onTap: () => _oc.toggleFilter('unscheduled'),
            ),
            _FilterTile(
              label: AppStrings.orderFilterDone,
              value: 'done',
              active: active.contains('done'),
              onTap: () => _oc.toggleFilter('done'),
            ),
            const Divider(height: 16, color: AppColors.divider),
            _FilterTile(
              label: AppStrings.orderFilterToday,
              value: 'today',
              active: active.contains('today'),
              onTap: () => _oc.toggleFilter('today'),
            ),
            _FilterTile(
              label: AppStrings.orderFilterFuture,
              value: 'future',
              active: active.contains('future'),
              onTap: () => _oc.toggleFilter('future'),
            ),
            _FilterTile(
              label: AppStrings.orderFilterDue7,
              value: 'due_7',
              active: active.contains('due_7'),
              onTap: () => _oc.toggleFilter('due_7'),
            ),
            _FilterTile(
              label: AppStrings.orderFilterDue30,
              value: 'due_30',
              active: active.contains('due_30'),
              onTap: () => _oc.toggleFilter('due_30'),
            ),
          ],
        );
      }),
    );
  }
}

class _GroupBySection extends StatelessWidget {
  final VoidCallback onClose;
  const _GroupBySection({required this.onClose});

  OrderController get _oc => Get.find<OrderController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Obx(() {
        final groupBy = _oc.activeGroupBy.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_rounded,
                    size: 16, color: Color(0xFF5B4FCF)),
                const SizedBox(width: 6),
                Text(AppStrings.orderGroupByTitle,
                    style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            _FilterTile(
              label: AppStrings.orderGroupByAssignedTo,
              value: 'assigned_to',
              active: groupBy == 'assigned_to',
              onTap: () => _oc.setGroupBy('assigned_to'),
            ),
          ],
        );
      }),
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  const _FilterTile({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: active
                      ? AppColors.primary
                      : isDark
                      ? AppColors.white
                      : AppColors.textPrimary,
                  fontWeight: active
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (active)
              const Icon(Icons.check_rounded,
                  size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _AddStageCard extends StatefulWidget {
  final double columnHeight;
  const _AddStageCard({required this.columnHeight});

  @override
  State<_AddStageCard> createState() => _AddStageCardState();
}

class _AddStageCardState extends State<_AddStageCard> {
  bool _editing = false;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await Get.find<OrderController>().addStage(name);
    if (mounted) {
      _ctrl.clear();
      setState(() { _editing = false; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 280,
      height: widget.columnHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — same position as stage title row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: _editing
                ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: true,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:AppStrings.orderStageNameHint,
                      hintStyle: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.textHint,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                // Add button
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                      : const Icon(Icons.check_rounded,
                      size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                // Cancel button
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() => _editing = false);
                  },
                  child: const Icon(Icons.close_rounded,
                      size: 22, color: AppColors.textSecondary),
                ),
              ],
            )
                : GestureDetector(
              onTap: () {
                setState(() => _editing = true);
                Future.delayed(
                  const Duration(milliseconds: 80),
                      () => _focus.requestFocus(),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkPrimary : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 22,
                      color: isDark ? AppColors.white :AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.orderStageAdd,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: isDark ? AppColors.white :AppColors.textPrimary,

                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
