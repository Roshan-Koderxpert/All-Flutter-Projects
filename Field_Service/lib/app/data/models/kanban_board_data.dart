import 'kanban_column_vm.dart';
import 'kanban_stage_model.dart';
import 'order_model.dart';

void _sortOrdersKanban(List<OrderModel> list) {
  list.sort(OrderModel.compareKanban);
}

/// Stages from Odoo + orders; UI builds one column per stage (plus optional "Other").
class KanbanBoardData {
  const KanbanBoardData({
    required this.stages,
    required this.orders,
  });

  final List<KanbanStageModel> stages;
  final List<OrderModel> orders;
}

/// One column per Odoo stage (sequence order). Tasks with missing/unknown `stageId`
/// go under **Other**. If [stages] is empty, groups by [OrderModel.sectionLabel].
List<KanbanColumnVm> buildKanbanColumns(
  List<KanbanStageModel> stages,
  List<OrderModel> orders,
) {
  if (stages.isEmpty) {
    return _fallbackColumnsBySection(orders);
  }

  final known = {for (final s in stages) s.id};
  final byStage = <int, List<OrderModel>>{};
  for (final o in orders) {
    final sid = o.stageId;
    if (sid != null && known.contains(sid)) {
      byStage.putIfAbsent(sid, () => []).add(o);
    }
  }
  for (final list in byStage.values) {
    _sortOrdersKanban(list);
  }

  final unmatched = <OrderModel>[];
  for (final o in orders) {
    final sid = o.stageId;
    if (sid == null || !known.contains(sid)) {
      unmatched.add(o);
    }
  }
  _sortOrdersKanban(unmatched);

  final columns = <KanbanColumnVm>[];
  for (final s in stages) {
    columns.add(KanbanColumnVm(
      title: s.name.trim().isEmpty ? '—' : s.name,
      stageId: s.id,
      folded: s.folded,
      orders: List<OrderModel>.from(byStage[s.id] ?? const []),
    ));
  }
  if (unmatched.isNotEmpty) {
    columns.add(KanbanColumnVm(
      title: 'Other',
      stageId: null,
      orders: unmatched,
    ));
  }
  return columns;
}

List<KanbanColumnVm> _fallbackColumnsBySection(List<OrderModel> orders) {
  final keys = <String>[];
  final map = <String, List<OrderModel>>{};
  for (final o in orders) {
    final key = o.sectionLabel.trim().isEmpty ? 'None' : o.sectionLabel;
    if (!map.containsKey(key)) {
      keys.add(key);
      map[key] = [];
    }
    map[key]!.add(o);
  }
  for (final list in map.values) {
    _sortOrdersKanban(list);
  }
  return keys
      .map((k) => KanbanColumnVm(title: k, orders: map[k]!))
      .toList();
}
