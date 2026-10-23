/// Odoo model / fields for the Order tab (Field Service–style work).
///
/// Adjust [model], [searchDomain], and [fields] to match your database.
/// Stages for the kanban columns come from [stageModel] (`fsm.stage` with
/// [stageSearchDomain] so only order-type stages load as columns).
class OdooOrdersConfig {
  OdooOrdersConfig._();

  /// Records are loaded with `search_read` on this model.
  static const String model = 'fsm.order';

  /// First positional argument to `search_read` (the domain).
  static List<dynamic> get searchDomain => <dynamic>[];

  static const List<String> fields = [
    'id',
    'name',
    'location_id',
    'phone',
    'mobile',
    'street',
    'street2',
    'city',
    // 'state_id',
    'zip',
    // 'country_id',
    'scheduled_date_start',
    'person_id',
    'company_id',
    'stage_id',
    'priority',
    /// Kanban row order within a stage (same as Odoo web column ordering).
    'sequence',
  ];

  static const int searchLimit = 200;

  /// Matches typical Odoo kanban: group by stage, then `sequence`, then stable id.
  static const String searchOrder = 'stage_id, sequence, id';

  // ── Kanban columns (fetch stage names & order from DB) ───────────────

  /// Model for stage rows (`search_read` → id, name, sequence).
  static const String stageModel = 'fsm.stage';

  /// Only stages that apply to FSM orders (not worker/location/etc. stages).
  static List<dynamic> get stageSearchDomain => <dynamic>[
        <dynamic>['stage_type', '=', 'order'],
      ];

  static const List<String> stageFields = ['id', 'name', 'sequence', 'fold'];

  static const int stageLimit = 200;

  static const String stageOrder = 'sequence, id';

  // ── Datetime RPC (Odoo stores naive UTC strings in many JSON-RPC payloads) ─
  /// When true, naive `YYYY-MM-DD HH:mm:ss` values from Odoo are parsed as **UTC**
  /// and converted to the device **local** time for display.
  static const bool odooNaiveDatetimesAreUtc = true;

  /// When true, schedule / execution datetimes edited in the app are converted to
  /// UTC (same string format) before `create` / `write` so they match Odoo storage.
  static const bool writeScheduleDatetimesAsUtc = true;

  // ── Timesheets (lines linked to an FSM order) ─────────────────────────
  /// Model used for time entries (OCA / hr_timesheet: `account.analytic.line`).
  static const String timesheetLineModel = 'account.analytic.line';

  /// Domains tried (in addition to `timesheet_ids` on the order) for `search_read`.
  /// Change the field if your DB links lines differently (avoid unrelated `order_id` matches).
  static List<List<dynamic>> timesheetDomainsForOrder(int orderId) => <List<dynamic>>[
        <dynamic>['fsm_order_id', '=', orderId],
      ];

  /// Field name used on [timesheetLineModel] when creating a line from the app.
  static const String timesheetCreateOrderField = 'fsm_order_id';

  /// `search_read` fields for [timesheetLineModel] (only fields that exist on your server).
  static const List<String> timesheetLineFields = <String>[
    'id',
    'date',
    'name',
    'unit_amount',
    'employee_id',
    'timesheet_type_id',
  ];

  // ── `account.analytic.line` · `unit_amount` (float, hours) ────────────

  /// Parses Odoo `unit_amount` (float hours) from JSON-RPC (`num`, [String], etc.).
  static double parseUnitAmountHours(dynamic raw) {
    if (raw == null || raw == false) return 0.0;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    final s = raw.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  /// UI string for hours; keeps full precision from [hours] without broken trimming.
  /// Mimics Odoo's `timesheet_uom` widget: converts float hours → "HH:MM"
  static String formatUnitAmountHoursForUi(double hours) {
    if (hours == 0.0 || hours == -0.0) return '0:00';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes.remainder(60).abs();
    return '$h:${m.toString().padLeft(2, '0')}';
  }


  /// Parses Odoo float_time widget value → Duration
  /// e.g. 0.3167 → 00:19,  1.5 → 01:30
  static Duration durationFromFloatTime(double floatHours) {
    final totalSeconds = (floatHours * 3600).round();
    return Duration(seconds: totalSeconds);
  }

  /// Formats Duration as float_time string "HH:MM" (matches Odoo widget display)
  static String formatFloatTimeForUi(double floatHours) {
    final totalMinutes = (floatHours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes.remainder(60).abs();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
