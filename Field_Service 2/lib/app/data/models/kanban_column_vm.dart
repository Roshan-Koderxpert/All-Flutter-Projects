import 'order_model.dart';

class KanbanColumnVm {
  const KanbanColumnVm({
    required this.title,
    required this.orders,
    this.stageId,
    this.folded = false,
  });

  final String title;
  final int? stageId;
  final List<OrderModel> orders;
  final bool folded;
}