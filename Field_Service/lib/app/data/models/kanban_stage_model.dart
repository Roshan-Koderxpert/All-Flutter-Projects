/// One stage/column from Odoo (e.g. `project.task.type` for FSM / project tasks).
class KanbanStageModel {
  final int id;
  final String name;
  final int sequence;
  final bool folded;

  const KanbanStageModel({
    required this.id,
    required this.name,
    this.sequence = 0,
    this.folded = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sequence': sequence,
    'fold': folded,
  };

  factory KanbanStageModel.fromMap(Map<String, dynamic> map) {
    return KanbanStageModel(
      id: _asInt(map['id']) ?? 0,
      name: map['name']?.toString() ?? '',
      sequence: _asInt(map['sequence']) ?? 0,
      folded: map['fold'] == true,
    );
  }

  factory KanbanStageModel.fromOdooRecord(Map<String, dynamic> m) {
    return KanbanStageModel(
      id: _asInt(m['id']) ?? 0,
      name: m['name']?.toString().trim() ?? '—',
      sequence: _asInt(m['sequence']) ?? 0,
      folded: m['fold'] == true,
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
