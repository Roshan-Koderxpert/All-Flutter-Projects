import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/utils/api_logger.dart';
import '../../core/utils/odoo_datetime.dart';
import '../models/attendance_record.dart';

class AttendanceRepository {
  AttendanceRepository(this._client);

  final OdooClient _client;

  static const _fieldsBasic = [
    'id',
    'check_in',
    'check_out',
    'worked_hours',
    'employee_id',
  ];

  static const _fieldsExtended = [
    ..._fieldsBasic,
    'overtime_hours',
    // Odoo 17+ compute overtime against the employee's own schedule; asking
    // for these is what keeps the app's numbers equal to the web client's
    // instead of derived from an assumed 8-hour day.
    'expected_hours',
    'validated_overtime_hours',
    'in_mode',
    'out_mode',
  ];

  /// Field names `hr.attendance` actually offers here, read once per server.
  /// A `search_read` fails entirely if one requested field is unknown, and
  /// these hour fields differ between Odoo versions.
  static final Map<String, Set<String>> _fieldCache = {};

  static void resetFieldCache() => _fieldCache.clear();

  Future<Set<String>> _availableFields() async {
    final key = _client.baseURL;
    final cached = _fieldCache[key];
    if (cached != null) return cached;
    try {
      final result = await _client.callKw({
        'model': 'hr.attendance',
        'method': 'fields_get',
        'args': [<String>[], ['type']],
        'kwargs': {},
      });
      if (result is Map) {
        final names = result.keys.map((k) => k.toString()).toSet();
        ApiLogger.info(
          'hr.attendance hour fields => '
          '${names.where((n) => n.contains('hour')).toList()}',
        );
        return _fieldCache[key] = names;
      }
    } catch (e) {
      ApiLogger.info('hr.attendance fields_get failed: $e');
    }
    return _fieldCache[key] = <String>{};
  }

  /// [wanted] minus anything this database doesn't have.
  Future<List<String>> _supported(List<String> wanted) async {
    final available = await _availableFields();
    if (available.isEmpty) return _fieldsBasic;
    final fields = wanted.where(available.contains).toList();
    return fields.isEmpty ? _fieldsBasic : fields;
  }

  static const _fieldsDetail = [
    ..._fieldsExtended,
    'in_ip_address',
    'out_ip_address',
    'in_browser',
    'out_browser',
    'in_latitude',
    'in_longitude',
    'out_latitude',
    'out_longitude',
    'in_city',
    'in_country_name',
    'out_city',
    'out_country_name',
    'overtime_status',
  ];

  Future<List<Map<String, dynamic>>> _readRecords({
    required List<int> ids,
    required List<String> fields,
  }) async {
    final result = await _client.callKw({
      'model': 'hr.attendance',
      'method': 'read',
      'args': [ids],
      'kwargs': {'fields': fields},
    });
    if (result is List) {
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<AttendanceRecord?> fetchRecordById(int id) async {
    ApiLogger.info('--- fetchRecordById id=$id ---');

    for (final fields in [
      await _supported(_fieldsDetail),
      await _supported(_fieldsExtended),
      _fieldsBasic,
    ]) {
      try {
        final rows = await _readRecords(ids: [id], fields: fields);
        if (rows.isEmpty) return null;

        var record = AttendanceRecord.fromOdoo(rows.first);
        final enriched = await _enrichWithEmployeeData([record]);
        record = enriched.first;
        ApiLogger.info('fetchRecordById ok fields=${fields.length}');
        return record;
      } catch (e, st) {
        ApiLogger.error('fetchRecordById failed fields=$fields', e, st);
        if (fields == _fieldsBasic) rethrow;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _searchRead({
    required List<List<dynamic>> domain,
    required String order,
    int? limit,
  }) async {
    for (final fields in [
      await _supported(_fieldsExtended),
      _fieldsBasic,
    ]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.attendance',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': fields,
            'order': order,
            'limit': ?limit,
          },
        });
        if (result is List) {
          ApiLogger.info('search_read fields=${fields.join(",")} ok');
          return result
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (e, st) {
        ApiLogger.error('search_read failed for fields=$fields', e, st);
        if (fields == _fieldsBasic) rethrow;
      }
    }
    return [];
  }

  Future<List<AttendanceRecord>> fetchByEmployee({
    required int employeeId,
    DateTime? fromLocal,
    DateTime? toLocal,
    int limit = 80,
  }) async {
    return fetchAttendance(
      domain: _withDateRange(
        [
          ['employee_id', '=', employeeId],
        ],
        fromLocal,
        toLocal,
      ),
      limit: limit,
    );
  }

  Future<List<AttendanceRecord>> fetchAttendance({
    required List<List<dynamic>> domain,
    int limit = 200,
  }) async {
    ApiLogger.info('--- fetchAttendance ---');
    ApiLogger.json('domain', domain);

    try {
      final result = await _searchRead(
        domain: domain,
        order: 'check_in desc',
        limit: limit,
      );

      final records = <AttendanceRecord>[];
      for (final item in result) {
        try {
          records.add(AttendanceRecord.fromOdoo(item));
        } catch (e, st) {
          ApiLogger.error('Failed to parse record: $item', e, st);
        }
      }
      return _enrichWithEmployeeData(records);
    } catch (e, st) {
      ApiLogger.error('fetchAttendance failed', e, st);
      rethrow;
    }
  }

  Future<List<int>> fetchTeamEmployeeIds(int managerEmployeeId) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search',
        'args': [
          [
            ['parent_id', '=', managerEmployeeId],
          ],
        ],
        'kwargs': {},
      });
      if (result is List) {
        return result.cast<int>();
      }
    } catch (e, st) {
      ApiLogger.error('fetchTeamEmployeeIds failed', e, st);
    }
    return [];
  }

  List<List<dynamic>> _withDateRange(
    List<List<dynamic>> domain,
    DateTime? fromLocal,
    DateTime? toLocal,
  ) {
    final d = List<List<dynamic>>.from(domain);
    if (fromLocal != null) {
      d.add(['check_in', '>=', OdooDateTime.toOdooUtc(fromLocal)]);
    }
    if (toLocal != null) {
      d.add(['check_in', '<', OdooDateTime.toOdooUtc(toLocal)]);
    }
    return d;
  }

  Future<List<AttendanceRecord>> _enrichWithEmployeeData(
    List<AttendanceRecord> records,
  ) async {
    final ids = records.map((r) => r.employeeId).whereType<int>().toSet();
    if (ids.isEmpty) return records;

    final meta = <int, Map<String, dynamic>>{};
    try {
      final rows = await _client.callKw({
        'model': 'hr.employee',
        'method': 'read',
        'args': [ids.toList()],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'active',
            'department_id',
            'parent_id',
          ],
        },
      });
      if (rows is List) {
        for (final row in rows) {
          final m = Map<String, dynamic>.from(row as Map);
          meta[m['id'] as int] = m;
        }
      }
    } catch (e, st) {
      ApiLogger.error('enrich employee meta failed', e, st);
      return records;
    }

    return records.map((r) {
      final eid = r.employeeId;
      if (eid == null) return r;
      final m = meta[eid];
      if (m == null) return r;

      final dept = m['department_id'];
      final parent = m['parent_id'];
      return r.copyWith(
        departmentName: dept is List && dept.length > 1
            ? dept[1].toString()
            : r.departmentName,
        managerName: parent is List && parent.length > 1
            ? parent[1].toString()
            : r.managerName,
        employeeActive: m['active'] != false,
      );
    }).toList();
  }

  Future<List<AttendanceRecord>> fetchForLocalDay({
    required int employeeId,
    required DateTime day,
  }) async {
    final range = OdooDateTime.localDayRangeUtc(day);
    final domain = [
      ['employee_id', '=', employeeId],
      ['check_in', '>=', range.start],
      ['check_in', '<', range.end],
    ];

    ApiLogger.info('--- fetchForLocalDay (today) ---');
    ApiLogger.json('employeeId', employeeId);
    ApiLogger.json('local day', day.toString());
    ApiLogger.json('UTC range start', range.start);
    ApiLogger.json('UTC range end', range.end);
    ApiLogger.json('domain', domain);

    try {
      final result = await _searchRead(
        domain: domain,
        order: 'check_in asc',
      );

      ApiLogger.json('raw response count', result.length);

      ApiLogger.info('today records count: ${result.length}');

      if (result.isEmpty) {
        await _debugFetchAnyAttendanceForEmployee(employeeId);
      }

      return result.map(AttendanceRecord.fromOdoo).toList();
    } catch (e, st) {
      ApiLogger.error('fetchForLocalDay failed', e, st);
      rethrow;
    }
  }

  /// When today filter returns empty, log recent records without date filter.
  Future<void> _debugFetchAnyAttendanceForEmployee(int employeeId) async {
    ApiLogger.info('--- DEBUG: fetch last 5 attendances (no date filter) ---');
    try {
      final result = await _searchRead(
        domain: [
          ['employee_id', '=', employeeId],
        ],
        order: 'check_in desc',
        limit: 5,
      );
      ApiLogger.json('last 5 records (any date)', result);

      final count = await _client.callKw({
        'model': 'hr.attendance',
        'method': 'search_count',
        'args': [
          [
            ['employee_id', '=', employeeId],
          ],
        ],
        'kwargs': {},
      });
      ApiLogger.json('total attendance count for employee', count);
    } catch (e, st) {
      ApiLogger.error('debug fetch failed', e, st);
    }
  }

  /// Today's hours straight from `hr.employee`, the same fields Odoo's own
  /// systray shows.
  ///
  /// `hours_today` is Odoo's "Total today" and `hours_previously_today` its
  /// "Before [check-in time]". Summing the day's records app-side gave a
  /// number that drifted from the web client, so the server's own figures are
  /// used whenever this database has them.
  Future<({double total, double previously})?> _employeeHoursToday(
    int employeeId,
  ) async {
    const wanted = ['hours_today', 'hours_previously_today'];
    try {
      final available = await _availableEmployeeFields();
      final fields = wanted.where(available.contains).toList();
      if (fields.isEmpty) return null;

      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'read',
        'args': [
          [employeeId],
          fields,
        ],
        'kwargs': {},
      });
      if (result is! List || result.isEmpty) return null;
      final row = Map<String, dynamic>.from(result.first as Map);

      final total = row['hours_today'];
      final previously = row['hours_previously_today'];
      if (total is! num) return null;

      ApiLogger.info(
        'hr.employee hours_today=$total hours_previously_today=$previously',
      );
      return (
        total: total.toDouble(),
        previously: previously is num ? previously.toDouble() : 0.0,
      );
    } catch (e) {
      ApiLogger.info('hours_today unavailable: $e');
      return null;
    }
  }

  static final Map<String, Set<String>> _employeeFieldCache = {};

  Future<Set<String>> _availableEmployeeFields() async {
    final key = _client.baseURL;
    final cached = _employeeFieldCache[key];
    if (cached != null) return cached;
    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'fields_get',
        'args': [<String>[], ['type']],
        'kwargs': {},
      });
      if (result is Map) {
        return _employeeFieldCache[key] =
            result.keys.map((k) => k.toString()).toSet();
      }
    } catch (e) {
      ApiLogger.info('hr.employee fields_get failed: $e');
    }
    return _employeeFieldCache[key] = <String>{};
  }

  Future<TodayAttendanceSummary> fetchTodaySummary(int employeeId) async {
    ApiLogger.info('=== fetchTodaySummary START ===');
    final records = await fetchForLocalDay(
      employeeId: employeeId,
      day: DateTime.now(),
    );

    if (records.isEmpty) {
      ApiLogger.info('No today records -> returning empty summary');
      return TodayAttendanceSummary.empty();
    }

    AttendanceRecord? open;
    for (final r in records.reversed) {
      if (r.isOpen) {
        open = r;
        break;
      }
    }

    double totalHours = 0;
    double closedHours = 0;
    DateTime? lastCheckOut;

    for (final r in records) {
      if (r.isOpen) {
        totalHours += r.effectiveWorkedHours;
      } else {
        final hours = r.workedHours > 0 ? r.workedHours : r.effectiveWorkedHours;
        totalHours += hours;
        // Kept apart so the card can add the running session itself and stay
        // current between refreshes.
        closedHours += hours;
        lastCheckOut = r.checkOut;
      }
    }

    // Itemised so a mismatch with Odoo's "Total today" can be traced to a
    // specific record rather than guessed at.
    for (final r in records) {
      ApiLogger.info(
        'today record id=${r.id} in=${r.checkIn} out=${r.checkOut} '
        'stored_worked=${r.workedHours}',
      );
    }
    ApiLogger.info(
      'today totals: closed=$closedHours total=$totalHours '
      'records=${records.length}',
    );

    // Odoo's own numbers win where the database exposes them.
    final serverHours = await _employeeHoursToday(employeeId);
    if (serverHours != null) {
      ApiLogger.info(
        'today totals: server total=${serverHours.total} '
        'previously=${serverHours.previously} '
        '(app sum was closed=$closedHours total=$totalHours)',
      );
      totalHours = serverHours.total;
      closedHours = serverHours.previously;
    }

    final displayCheckIn = open?.checkIn ?? records.last.checkIn;

    final status = open != null
        ? 'checked_in'
        : (records.any((r) => !r.isOpen) ? 'checked_out' : 'not_checked');

    final summary = TodayAttendanceSummary(
      status: status,
      checkIn: displayCheckIn,
      checkOut: open == null ? lastCheckOut : null,
      workedHours: totalHours,
      closedHours: closedHours,
      openRecord: open,
    );

    ApiLogger.info(
      'SUMMARY => status=$status checkIn=${summary.checkIn} '
      'checkOut=${summary.checkOut} hours=${summary.workedHours}',
    );
    ApiLogger.info('=== fetchTodaySummary END ===');
    return summary;
  }

  Future<void> checkIn(
    int employeeId, {
    double? latitude,
    double? longitude,
  }) async {
    await _performAttendanceAction(
      employeeId: employeeId,
      expectCheckedIn: true,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> checkOut(
    int employeeId, {
    double? latitude,
    double? longitude,
  }) async {
    await _performAttendanceAction(
      employeeId: employeeId,
      expectCheckedIn: false,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Uses Odoo's `/hr_attendance/systray_check_in_out` route (same as the web
  /// systray button). Falls back to direct create/write for older setups.
  Future<void> _performAttendanceAction({
    required int employeeId,
    required bool expectCheckedIn,
    double? latitude,
    double? longitude,
  }) async {
    ApiLogger.info(
      'attendance action employeeId=$employeeId '
      'expectCheckedIn=$expectCheckedIn',
    );

    try {
      final result = await _client.callRPC(
        '/hr_attendance/systray_check_in_out',
        'call',
        {
          'latitude': latitude ?? false,
          'longitude': longitude ?? false,
        },
      );
      _validateSystrayResult(result, expectCheckedIn: expectCheckedIn);
      ApiLogger.info('attendance SUCCESS via systray');
      return;
    } catch (e, st) {
      ApiLogger.error('systray attendance failed, trying fallback', e, st);
    }

    if (expectCheckedIn) {
      await _checkInDirect(employeeId, latitude: latitude, longitude: longitude);
    } else {
      await _checkOutDirect(employeeId,
          latitude: latitude, longitude: longitude);
    }
  }

  void _validateSystrayResult(
    dynamic result, {
    required bool expectCheckedIn,
  }) {
    if (result is! Map) {
      throw Exception('Unexpected attendance response from server');
    }

    final map = Map<String, dynamic>.from(result);
    if (map.isEmpty) {
      throw Exception(
        'No employee is linked to your user. Contact your administrator.',
      );
    }

    final state = map['attendance_state']?.toString();
    if (state == null || state.isEmpty) return;

    if (expectCheckedIn && state != 'checked_in') {
      throw Exception('Check in was not recorded. Please try again.');
    }
    if (!expectCheckedIn && state != 'checked_out') {
      throw Exception('Check out was not recorded. Please try again.');
    }
  }

  Future<void> _checkInDirect(
    int employeeId, {
    double? latitude,
    double? longitude,
  }) async {
    final checkInUtc = OdooDateTime.toOdooUtc(DateTime.now());
    ApiLogger.info('checkIn (direct) employeeId=$employeeId at $checkInUtc');
    final values = <String, dynamic>{
      'employee_id': employeeId,
      'check_in': checkInUtc,
      'in_mode': 'systray',
    };
    if (latitude != null && longitude != null) {
      values['in_latitude'] = latitude;
      values['in_longitude'] = longitude;
    }
    await _client.callKw({
      'model': 'hr.attendance',
      'method': 'create',
      'args': [values],
      'kwargs': {},
    });
    ApiLogger.info('checkIn SUCCESS (direct)');
  }

  Future<void> _checkOutDirect(
    int employeeId, {
    double? latitude,
    double? longitude,
  }) async {
    ApiLogger.info('checkOut (direct) employeeId=$employeeId');
    final open = await _client.callKw({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
          ['check_out', '=', false],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'check_in', 'check_out'],
        'order': 'check_in desc',
        'limit': 1,
      },
    });

    ApiLogger.json('open attendance search', open);

    if (open is! List || open.isEmpty) {
      ApiLogger.error('No open attendance found for checkout');
      throw Exception('No open attendance found to check out');
    }

    final id = (open.first as Map)['id'] as int;
    final checkOutUtc = OdooDateTime.toOdooUtc(DateTime.now());
    ApiLogger.info('writing check_out on id=$id at $checkOutUtc');

    final values = <String, dynamic>{
      'check_out': checkOutUtc,
      'out_mode': 'systray',
    };
    if (latitude != null && longitude != null) {
      values['out_latitude'] = latitude;
      values['out_longitude'] = longitude;
    }
    await _client.callKw({
      'model': 'hr.attendance',
      'method': 'write',
      'args': [
        [id],
        values,
      ],
      'kwargs': {},
    });
    ApiLogger.info('checkOut SUCCESS (direct)');
  }
}
