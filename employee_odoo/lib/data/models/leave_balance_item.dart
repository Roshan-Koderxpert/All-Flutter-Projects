class LeaveBalanceItem {
  LeaveBalanceItem({
    required this.name,
    required this.remaining,
    required this.total,
    this.typeId,
    this.taken = 0,
  });

  final String name;
  final double remaining;
  final double total;
  final int? typeId;
  final double taken;

  double get used => total - remaining;
}
