import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/todo_home_controller.dart';
import '../../controllers/todo_tasks_controller.dart';
import '../../controllers/todo_activity_controller.dart';
import '../../core/assets.dart';
import '../account_setting/account_setting_page.dart';
import '../../controllers/login_controller.dart';
import '../tasks/create_task_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _gradientStart = Color(0xFF1E4A6B);
  static const _accent = Color(0xFFFF6B35);

  int _index = 0;

  late final TodoHomeController _todoHome;
  late final TodoTasksController _todoTasks;
  late final TodoActivityController _todoActivity;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<TodoHomeController>()) {
      _todoHome = Get.find<TodoHomeController>();
    } else {
      _todoHome = Get.put(TodoHomeController());
    }

    _todoTasks = Get.isRegistered<TodoTasksController>()
        ? Get.find<TodoTasksController>()
        : Get.put(TodoTasksController());

    _todoActivity = Get.isRegistered<TodoActivityController>()
        ? Get.find<TodoActivityController>()
        : Get.put(TodoActivityController());
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _profileAvatar(AuthController auth) {
    final img = auth.activeAccount.value?.image1920;
    if (img != null && img.isNotEmpty) {
      try {
        final bytes = base64Decode(img);
        return CircleAvatar(
          radius: 32,
          backgroundColor: Colors.white24,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        /* fall through */
      }
    }
    return CircleAvatar(
      radius: 32,
      backgroundColor: Colors.white24,
      child: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.9), size: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Colors.white,
      body: IndexedStack(
  
        index: _index,
        children: [
          _DashboardTab(
            todoHome: _todoHome,
            greeting: _greeting,
            buildGreetingCard: _buildGreetingCard,
            buildStatsRow: _buildStatsRow,
            buildOverviewSection: _buildOverviewSection,
          ),
          _AllTasksTab(controller: _todoTasks),
          _ActivityTab(controller: _todoActivity),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E4A6B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New task'),
        onPressed: () async {
          final created = await Get.to<bool>(() => const CreateTaskPage());
          if (created == true) {
            await Get.dialog<void>(
              AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Success'),
                content: const Text('Task added successfully.'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back<void>(),
                    child: const Text('OK'),
                  ),
                ],
              ),
              barrierDismissible: true,
            );

            // Refresh in background, no waiting on UI thread.
            _todoTasks.loadTasks();
            _todoHome.loadStats();
            _todoActivity.loadActivities();
          }
        },
      ),
      bottomNavigationBar: _ModernBottomBar(
        currentIndex: _index,
        onChanged: (i) {
          if (i == _index) return;
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        accent: _gradientStart,
      ),
    );
  }

  Widget _buildGreetingCard(AuthController auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
       gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F5786),
              Color(0xFFF06022),
            ],
          ),
        borderRadius: BorderRadius.circular(20),
       
      ),
      
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()},',
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.activeAccount.value?.name ??
                      auth.userName.value,
                  style: const TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  'Manage your tasks and stay on top of what matters — efficiently.',
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Obx(() => _profileAvatar(auth)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(TodoHomeController c) {
    if (c.isLoading.value && c.countAll.value == 0 && c.countPending.value == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = [
      _StatItem('All', c.countAll.value, Icons.task_alt_outlined, _gradientStart),
      _StatItem('Pending', c.countPending.value, Icons.pending_actions_outlined, _accent),
      _StatItem('Done', c.countCompleted.value, Icons.check_circle_outline, const Color(0xFF2E7D32)),
    ];
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, index) => const SizedBox(width: 12),
      itemBuilder: (_, i) => _statCard(items[i]),
    );
  }

  Widget _statCard(_StatItem item) {
    
    return Container(
      width: 124,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(item.icon, color: item.tint, size: 26),
          Text(
            '${item.count}',
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
          ),
          Text(
            item.label,
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(TodoHomeController c) { 
    if (c.isLoading.value &&
        c.countDueToday.value == 0 &&
        c.countDueThisWeek.value == 0 &&
        c.countDueThisMonth.value == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        _overviewTile(
          icon: Icons.today_outlined,
          title: 'Today',
          subtitle: 'Due today',
          count: c.countDueToday.value,
        ),
        const SizedBox(height: 10),
        _overviewTile(
          icon: Icons.date_range_outlined,
          title: 'This week',
          subtitle: 'Due this calendar week',
          count: c.countDueThisWeek.value,
        ),
        const SizedBox(height: 10),
        _overviewTile(
          icon: Icons.calendar_month_outlined,
          title: 'This month',
          subtitle: 'Due this month',
          count: c.countDueThisMonth.value,
        ),
      ],
    );
  }

  Widget _overviewTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gradientStart.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _gradientStart, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _gradientStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final int count;
  final IconData icon;
  final Color tint;

  _StatItem(this.label, this.count, this.icon, this.tint);
}

class _DashboardTab extends StatelessWidget {
  final TodoHomeController todoHome;
  final String Function() greeting;
  final Widget Function(AuthController auth) buildGreetingCard;
  final Widget Function(TodoHomeController c) buildStatsRow;
  final Widget Function(TodoHomeController c) buildOverviewSection;

  const _DashboardTab({
    required this.todoHome,
    required this.greeting,
    required this.buildGreetingCard,
    required this.buildStatsRow,
    required this.buildOverviewSection,
  });

  static const _gradientStart = Color(0xFF1E4A6B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'My tasks',
          style: TextStyle(
            fontFamily: AppFonts.nunitoSans,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        actions: [
          IconButton(
            iconSize: 28,
            icon: Icon(Icons.account_circle_outlined, color: Colors.grey.shade800),
            onPressed: () => Get.to(() => AccountSettingsPage()),
          ),
        ],
      ),
      body: Obx(() {
        if (todoHome.loadError.value != null && !todoHome.isLoading.value) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade500),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load task stats.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.nunitoSans,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        todoHome.loadError.value!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.nunitoSans,
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: todoHome.loadStats,
                        style: FilledButton.styleFrom(backgroundColor: _gradientStart),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return RefreshIndicator(
          backgroundColor: Colors.white,
          color: const Color(0xFF1E4A6B),
          onRefresh: todoHome.loadStats,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Obx(() {
                Get.find<AuthController>().activeAccount.value;
                return buildGreetingCard(Get.find<AuthController>());
              }),
              const SizedBox(height: 20),
              Text(
                'Your workload',
                style: TextStyle(
                  fontFamily: AppFonts.nunitoSans,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Personal to-dos only — same as Odoo To-Do (no project, not sub-tasks)',
                style: TextStyle(
                  fontFamily: AppFonts.nunitoSans,
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 118,
                child: Obx(() => buildStatsRow(todoHome)),
              ),
              const SizedBox(height: 24),
              Text(
                'Task overview',
                style: TextStyle(
                  fontFamily: AppFonts.nunitoSans,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Same Kanban columns as Odoo (Today / This week / This month)',
                style: TextStyle(
                  fontFamily: AppFonts.nunitoSans,
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() => buildOverviewSection(todoHome)),
            ],
          ),
        );
      }),
    );
  }
}

class _AllTasksTab extends StatefulWidget {
  final TodoTasksController controller;
  const _AllTasksTab({required this.controller});

  @override
  State<_AllTasksTab> createState() => _AllTasksTabState();
}

class _AllTasksTabState extends State<_AllTasksTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final controller = widget.controller;
    final initial = controller.filter.value;
    var temp = initial;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FilterChoice(
                    title: 'All items',
                    selected: temp == TodoTaskFilter.all,
                    onTap: () => setModalState(() => temp = TodoTaskFilter.all),
                  ),
                  _FilterChoice(
                    title: 'Pending',
                    selected: temp == TodoTaskFilter.pending,
                    onTap: () => setModalState(() => temp = TodoTaskFilter.pending),
                  ),
                  _FilterChoice(
                    title: 'Completed',
                    selected: temp == TodoTaskFilter.completed,
                    onTap: () => setModalState(() => temp = TodoTaskFilter.completed),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            controller.clearAll();
                            _searchController.text = '';
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton( 
                          onPressed: () {
                            controller.setFilter(temp);
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E4A6B)),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor:  Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'All tasks',
          style: TextStyle(
            fontFamily: AppFonts.nunitoSans,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.loadError.value != null && !controller.isLoading.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load tasks.',
                    style: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    controller.loadError.value!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.loadTasks,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          backgroundColor: Colors.white,
          color: const Color(0xFF1E4A6B),
          onRefresh: controller.loadTasks,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: controller.setQuery,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontFamily: AppFonts.nunitoSans),
                      decoration: InputDecoration(
                        hintText: 'Search tasks…',
                        hintStyle: TextStyle(
                          fontFamily: AppFonts.nunitoSans,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF1E4A6B), width: 1.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _openFilterSheet(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Color(0xFF1E4A6B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Obx(() {
                    final v = controller.visibleCount;
                    final t = controller.totalCount;
                    final label = (controller.filter.value == TodoTaskFilter.all)
                        ? 'All items'
                        : (controller.filter.value == TodoTaskFilter.pending ? 'Pending' : 'Completed');
                    return Text(
                      '$v of $t • $label',
                      style: TextStyle(
                        fontFamily: AppFonts.nunitoSans,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              if (controller.isLoading.value && controller.totalCount == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No tasks found.',
                      style: TextStyle(
                        fontFamily: AppFonts.nunitoSans,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(controller.tasks.length, (i) {
                  final t = controller.tasks[i];
                  return Padding(
                    padding: EdgeInsets.only(bottom: i == controller.tasks.length - 1 ? 0 : 10),
                    child: _TaskCard(task: t),
                  );
                }),
            ],
          ),
        );
      }),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final TodoActivityController controller;
  const _ActivityTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Activities',
          style: TextStyle(
            fontFamily: AppFonts.nunitoSans,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        
      ),
      body: Obx(() {
        if (controller.loadError.value != null && !controller.isLoading.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load activities.',
                    style: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    controller.loadError.value!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.loadActivities,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          backgroundColor: Colors.white,
          color: const Color(0xFF1E4A6B),
          onRefresh: controller.loadActivities,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: controller.activities.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = controller.activities[i];
              return _ActivityCard(
                activity: a,
                icon: controller.iconForActivity(a),
                onMarkDone: () async {
                  await controller.markAsDone(a);
                  if (Get.context != null) {
                    ScaffoldMessenger.of(Get.context!).showSnackBar(
                      const SnackBar(content: Text('Activity marked as done')),
                    );
                  }
                },
                onCancel: () async {
                  await controller.cancelActivity(a);
                  if (Get.context != null) {
                    ScaffoldMessenger.of(Get.context!).showSnackBar(
                      const SnackBar(content: Text('Activity canceled')),
                    );
                  }
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TodoTaskRow task;
  const _TaskCard({required this.task});

  IconData _iconFromOdoo(String icon) {
    final s = icon.toLowerCase();
    if (s.contains('calendar')) return Icons.event_outlined;
    if (s.contains('phone')) return Icons.call_outlined;
    if (s.contains('envelope') || s.contains('mail')) return Icons.email_outlined;
    if (s.contains('check')) return Icons.task_alt_outlined;
    if (s.contains('clock')) return Icons.schedule_outlined;
    if (s.contains('video')) return Icons.videocam_outlined;
    return Icons.notifications_none_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
                  Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.assignees.isEmpty ? 'Unassigned' : task.assignees.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFromOdoo(task.activityIcon),
              color: const Color(0xFFFF6B35),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final TodoActivityRow activity;
  final IconData icon;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onCancel;
  const _ActivityCard({
    required this.activity,
    required this.icon,
    required this.onMarkDone,
    required this.onCancel,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'overdue':
        return const Color(0xFFD32F2F);
      case 'today':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'overdue':
        return 'Overdue';
      case 'today':
        return 'Today';
      default:
        return 'Planned';
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(activity.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFFF6B35)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activity.summary.isEmpty ? activity.typeName : activity.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (v) async {
                  if (v == 'done') await onMarkDone();
                  if (v == 'cancel') await onCancel();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'done', child: Text('Mark as done')),
                  PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Related to: ${activity.taskName.isEmpty ? '-' : activity.taskName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              fontSize: 12.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Created: ${_formatDate(activity.createdAt)}',
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              fontSize: 12.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assigned to: ${activity.assignedTo.isEmpty ? '-' : activity.assignedTo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              fontSize: 12.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel(activity.status),
                      style: TextStyle(
                        fontFamily: AppFonts.nunitoSans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChoice({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E4A6B).withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF1E4A6B) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF1E4A6B))
              else
                Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating pill-style bottom bar with clear selection state and theme alignment.
class _ModernBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color accent;

  const _ModernBottomBar({
    required this.currentIndex,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5F7FA).withValues(alpha: 0),
            const Color(0xFFF5F7FA),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, bottomInset > 0 ? 10 : 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModernNavSlot(
                    selected: currentIndex == 0,
                    label: 'Dashboard',
                    icon: Icons.dashboard_customize_outlined,
                    activeIcon: Icons.dashboard_customize_rounded,
                    accent: accent,
                    onTap: () => onChanged(0),
                  ),
                ),
                Expanded(
                  child: _ModernNavSlot(
                    selected: currentIndex == 1,
                    label: 'All tasks',
                    icon: Icons.checklist_rtl_rounded,
                    activeIcon: Icons.fact_check_rounded,
                    accent: accent,
                    onTap: () => onChanged(1),
                  ),
                ),
                Expanded(
                  child: _ModernNavSlot(
                    selected: currentIndex == 2,
                    label: 'Activity',
                    icon: Icons.bolt_outlined,
                    activeIcon: Icons.bolt_rounded,
                    accent: accent,
                    onTap: () => onChanged(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernNavSlot extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData? icon;
  final IconData? activeIcon;
  final String? iconAsset;
  final Color accent;
  final VoidCallback onTap;

  _ModernNavSlot({
    required this.selected,
    required this.label,
    this.icon,
    this.activeIcon,
    this.iconAsset,
    required this.accent,
    required this.onTap,
  }) : assert(
          iconAsset != null || (icon != null && activeIcon != null),
          'Provide iconAsset or both icon and activeIcon',
        );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconAsset != null)
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      selected ? accent : Colors.grey.shade500,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      iconAsset!,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Icon(
                    selected ? activeIcon! : icon!,
                    size: 26,
                    color: selected ? accent : Colors.grey.shade500,
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 11.5,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.15,
                    color: selected ? accent : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
