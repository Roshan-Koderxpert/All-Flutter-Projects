/// FSM order row for kanban (Hive cache + Odoo).
class OrderModel {
  final String id;
  final String title;
  final String? _subtitle;
  /// Display line from Odoo `location_id` (Many2one label). Never null for callers.
  String get subtitle => _subtitle ?? '';
  /// Filled stars 0–3 from Odoo `priority`.
  final int priorityStars;
  /// Odoo `sequence` — order of cards within a kanban column (same stage).
  final int sequence;
  /// Kanban column fallback when stage list is not loaded.
  final String sectionLabel;
  final int? stageId;
  final String? _scheduledStart;
  final String? _assignedTo;
  final String? _company;
  final String? _phone;
  final String? _mobile;
  final String? _street;
  final String? _street2;
  final String? _city;
  final String? _state;
  final String? _zip;
  final String? _country;
  String get scheduledStart => _scheduledStart ?? '';
  String get assignedTo => _assignedTo ?? '';
  String get company => _company ?? '';
  String get phone => _phone ?? '';
  String get mobile => _mobile ?? '';
  String get street => _street ?? '';
  String get street2 => _street2 ?? '';
  String get city => _city ?? '';
  String get state => _state ?? '';
  String get zip => _zip ?? '';
  String get country => _country ?? '';

  /// True while the row is a negative-id local draft waiting for Odoo `create`.
  bool get isOfflineQueued {
    final n = int.tryParse(id);
    return n != null && n < 0;
  }

  OrderModel({
    required this.id,
    required this.title,
    String? subtitle,
    this.priorityStars = 0,
    this.sequence = 0,
    this.sectionLabel = 'None',
    this.stageId,
    String? scheduledStart,
    String? assignedTo,
    String? company,
    String? phone,
    String? mobile,
    String? street,
    String? street2,
    String? city,
    String? state,
    String? zip,
    String? country,
  })  : _scheduledStart = scheduledStart,
        _assignedTo = assignedTo,
        _company = company,
        _phone = phone,
        _mobile = mobile,
        _street = street,
        _street2 = street2,
        _city = city,
        _state = state,
        _zip = zip,
        _country = country,
        _subtitle = subtitle;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'priority_stars': priorityStars,
        'sequence': sequence,
        'section_label': sectionLabel,
        'scheduled_start': scheduledStart,
        'assigned_to': assignedTo,
        'company': company,
        'phone': phone,
        'mobile': mobile,
        'street': street,
        'street2': street2,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
        if (stageId != null) 'stage_id': stageId,
        // So Hive rows from Odoo refresh are not mistaken for "pending" overlays.
        'sync_status': 'synced',
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: _stringOrEmpty(map['id']),
      title: _stringOrEmpty(map['title'], fallback: '—'),
      subtitle: _subtitleFromMap(map),
      priorityStars: _clampStars(map['priority_stars'] ?? map['priority']),
      sequence: _parseSequence(map['sequence']),
      sectionLabel: _stringOrEmpty(map['section_label'], fallback: 'None'),
      stageId: _parseStageId(map['stage_id']),
      scheduledStart: _stringOrEmpty(
        map['scheduled_start'] ?? map['scheduled_date_start'],
      ),
      assignedTo: _stringOrEmpty(
        map['assigned_to'],
        fallback: _m2oLabel(map['person_id']),
      ),
      company: _stringOrEmpty(
        map['company'],
        fallback: _m2oLabel(map['company_id']),
      ),
      phone: _stringOrEmpty(map['phone']),
      mobile: _stringOrEmpty(map['mobile']),
      street: _stringOrEmpty(map['street']),
      street2: _stringOrEmpty(map['street2']),
      city: _stringOrEmpty(map['city']),
      state: _stringOrEmpty(map['state'], fallback: _m2oLabel(map['state_id'])),
      zip: _stringOrEmpty(map['zip']),
      country: _stringOrEmpty(map['country'], fallback: _m2oLabel(map['country_id'])),
    );
  }

  factory OrderModel.fromOdooRecord(Map<String, dynamic> m) {
    final idVal = m['id'];
    final id = idVal == null ? '' : idVal.toString();
    final name = m['name']?.toString().trim();
    final title = (name == null || name.isEmpty) ? '—' : name;

    final subtitle = _m2oLabel(m['location_id']);
    final stageRaw = m['stage_id'];
    final stageName = _m2oLabel(stageRaw);

    return OrderModel(
      id: id,
      title: title,
      subtitle: subtitle,
      priorityStars: _clampStars(m['priority']),
      sequence: _parseSequence(m['sequence']),
      sectionLabel: stageName.isEmpty ? 'None' : stageName,
      stageId: _m2oId(stageRaw),
      scheduledStart: _stringOrEmpty(m['scheduled_date_start']),
      assignedTo: _m2oLabel(m['person_id']),
      company: _m2oLabel(m['company_id']).isNotEmpty
          ? _m2oLabel(m['company_id'])
          : _stringOrEmpty(m['company_name']),
      phone: _stringOrEmpty(m['phone']),
      mobile: _stringOrEmpty(m['mobile']),
      street: _stringOrEmpty(m['street']),
      street2: _stringOrEmpty(m['street2']),
      city: _stringOrEmpty(m['city']),
      state: _m2oLabel(m['state_id']).isNotEmpty
          ? _m2oLabel(m['state_id'])
          : _stringOrEmpty(m['state']),
      zip: _stringOrEmpty(m['zip']),
      country: _m2oLabel(m['country_id']).isNotEmpty
          ? _m2oLabel(m['country_id'])
          : _stringOrEmpty(m['country']),
    );
  }

  /// Odoo kanban ordering: `sequence`, then database id, then display name.
  /// Offline-queued rows (negative id) are sorted last.
  static int compareKanban(OrderModel a, OrderModel b) {
    final ao = a.isOfflineQueued;
    final bo = b.isOfflineQueued;
    if (ao != bo) return ao ? 1 : -1;
    final cs = a.sequence.compareTo(b.sequence);
    if (cs != 0) return cs;
    final ida = int.tryParse(a.id) ?? 0;
    final idb = int.tryParse(b.id) ?? 0;
    final idc = ida.compareTo(idb);
    if (idc != 0) return idc;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static int _parseSequence(dynamic v) {
    if (v == null || v == false) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  static String _stringOrEmpty(dynamic v, {String fallback = ''}) {
    if (v == null || v == false) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static String _m2oLabel(dynamic v) {
    if (v == false || v == null) return '';
    if (v is List && v.length >= 2) {
      return v[1]?.toString() ?? '';
    }
    return '';
  }

  /// Hive / legacy maps: `subtitle` string, or Odoo-shaped `location_id` [id, name].
  static String? _subtitleFromMap(Map<String, dynamic> map) {
    final s = map['subtitle'];
    if (s != null && s != false) {
      if (s is String) return s;
      if (s is List && s.length >= 2) return s[1]?.toString();
      return s.toString();
    }
    final loc = map['location_id'];
    if (loc != null && loc != false) {
      if (loc is String) return loc;
      final label = _m2oLabel(loc);
      if (label.isNotEmpty) return label;
    }
    return null;
  }

  /// Odoo `priority` (int, string digit, or selection key) → 0–3 filled stars.
  static int _clampStars(dynamic v) {
    if (v == null || v == false) return 0;
    if (v is int) return v.clamp(0, 3);
    if (v is num) return v.toInt().clamp(0, 3);
    final n = int.tryParse(v.toString().trim());
    return (n ?? 0).clamp(0, 3);
  }

  static int? _parseStageId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static int? _m2oId(dynamic v) {
    if (v == false || v == null) return null;
    if (v is List && v.isNotEmpty) {
      final id = v[0];
      if (id is int) return id;
      if (id is num) return id.toInt();
      return int.tryParse(id.toString());
    }
    return null;
  }
}
