import 'package:get/get.dart';
import '../../../data/models/task_record.dart';
import '../../../data/repositories/task_repository.dart';
import '../../auth/controllers/auth_controller.dart';

enum TaskModuleStatus { loading, available, unavailable, error }

enum TaskViewMode { list, kanban }

enum TaskSort { deadline, priority }

class TaskController extends GetxController {
  late final TaskRepository _repo;

  final tasks = <TaskRecord>[].obs;
  final stages = <TaskStage>[].obs;
  final status = TaskModuleStatus.loading.obs;
  final viewMode = TaskViewMode.list.obs;
  final query = ''.obs;
  final isMovingTask = false.obs;

  @override
  void onInit() {
    super.onInit();
    final client = Get.find<AuthController>().odooClient;
    _repo = TaskRepository(client!);
  }

  int? get _userId => Get.find<AuthController>().activeAccount.value?.userId;

  Future<void> loadAll() async {
    final userId = _userId;
    if (userId == null) return;
    status.value = TaskModuleStatus.loading;
    try {
      final myTasks = await _repo.fetchMine(userId);
      tasks.value = myTasks;

      stages.value = await _repo.fetchPersonalStages(userId);

      status.value = TaskModuleStatus.available;
    } on TaskModuleUnavailable {
      status.value = TaskModuleStatus.unavailable;
    } catch (e) {
      status.value = TaskModuleStatus.error;
    }
  }

  void setViewMode(TaskViewMode mode) => viewMode.value = mode;

  void onSearchChanged(String value) => query.value = value;

  List<TaskRecord> get filteredTasks {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return tasks;
    return tasks.where((t) {
      return t.name.toLowerCase().contains(q) ||
          (t.projectName?.toLowerCase().contains(q) ?? false) ||
          (t.stageName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Grouped for the kanban board: stage name -> tasks. Tasks whose stage
  /// wasn't resolved (rare — e.g. stage from another company) fall under
  /// 'Other' so nothing silently disappears from the board.
  Map<String, List<TaskRecord>> get groupedByStage {
    final map = <String, List<TaskRecord>>{};
    for (final stage in stages) {
      map[stage.name] = [];
    }
    for (final t in filteredTasks) {
      final key = t.stageName ?? 'Other';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  int get overdueCount => tasks.where((t) => t.isOverdue).length;
  int get dueTodayCount => tasks.where((t) => t.isDueToday).length;

  Future<bool> moveTaskToStage(TaskRecord task, int newStageId, String newStageName) async {
    isMovingTask.value = true;
    try {
      final ok = await _repo.updateStage(task.id, newStageId);
      if (ok) await loadAll();
      return ok;
    } finally {
      isMovingTask.value = false;
    }
  }
}