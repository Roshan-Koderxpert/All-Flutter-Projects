import 'dart:convert';

import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/utils/api_logger.dart';
import '../../core/utils/odoo_datetime.dart';
import '../models/leave_allocation_record.dart';
import '../models/leave_balance_item.dart';
import '../models/leave_calendar_info_item.dart';
import '../models/leave_record.dart';

class LeaveRepository {
  LeaveRepository(this._client);

  final OdooClient _client;

  static const _fieldsLeave = [
    'id',
    'name',
    'employee_id',
    'holiday_status_id',
    'request_date_from',
    'request_date_to',
    'date_from',
    'date_to',
    'number_of_days',
    'state',
    'create_date',
  ];

  static const _fieldsLeaveBasic = [
    'id',
    'employee_id',
    'holiday_status_id',
    'request_date_from',
    'request_date_to',
    'date_from',
    'date_to',
    'number_of_days',
    'state',
    'name',
  ];

  static const _fieldsAllocationList = [
    'id',
    'name',
    'name_validity',
    'employee_id',
    'holiday_status_id',
    'number_of_days',
    'allocation_type',
    'accrual_plan_id',
    'state',
    'date_from',
    'date_to',
  ];

  static const _fieldsAllocationListBasic = [
    'id',
    'name',
    'name_validity',
    'employee_id',
    'holiday_status_id',
    'number_of_days',
    'state',
    'date_from',
    'date_to',
  ];

  static const _fieldsAllocationDetail = [
    'id',
    'name',
    'name_validity',
    'employee_id',
    'holiday_status_id',
    'number_of_days',
    'allocation_type',
    'accrual_plan_id',
    'state',
    'date_from',
    'date_to',
  ];

  static const _fieldsAllocationDates = [
    'id',
    'date_from',
    'date_to',
    'name_validity',
  ];

  Future<List<LeaveCalendarInfoItem>> fetchMandatoryDays({
    required int employeeId,
    int limit = 50,
  }) async {
    ApiLogger.info(
      '--- LeaveRepository.fetchMandatoryDays emp=$employeeId ---',
    );
    // Odoo list uses search filter "Period: <year>" (full calendar year).
    final range = _currentYearRange();
    final ctx = await _employeeHolidayContext(employeeId);

    // 1) hr.leave.mandatory.day — fields `name`, `start_date`, `end_date`, `company_id`.
    for (final domain in _mandatoryDayDomainVariants(
      ctx: ctx,
      rangeStart: range.start,
      rangeEnd: range.end,
    )) {
      final items = await _readMandatoryDays(domain: domain, limit: limit);
      if (items.isNotEmpty) {
        ApiLogger.info(
          'fetchMandatoryDays hr.leave.mandatory.day count=${items.length}',
        );
        return items;
      }
    }

    // 2) Odoo calendar RPC fallback.
    final fromApi = await _fetchMandatoryDaysViaOdooApi(
      employeeId: employeeId,
      rangeStart: range.start,
      rangeEnd: range.end,
      limit: limit,
    );
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;

    return [];
  }

  /// Matches Odoo mandatory days search filter `Period: <current year>`.
  ({String start, String end}) _currentYearRange() {
    final y = DateTime.now().year;
    return (start: '$y-01-01', end: '$y-12-31');
  }

  /// Exact copy of Odoo `hr.employee._get_mandatory_days` domain.
  List<dynamic> _odooMandatoryDayDomain(
    _EmployeeHolidayContext ctx,
    String rangeStart,
    String rangeEnd,
  ) {
    final domain = <dynamic>[
      ['start_date', '<=', rangeEnd],
      ['end_date', '>=', rangeStart],
      if (ctx.companyIds.isNotEmpty) ['company_id', 'in', ctx.companyIds],
      '|',
      ['resource_calendar_id', '=', false],
      ['resource_calendar_id', '=', ctx.calendarId ?? false],
    ];

    if (ctx.departmentId != null) {
      domain.add('|');
      domain.add(['department_ids', '=', false]);
      // Odoo passes a list of department ids to parent_of.
      domain.add(['department_ids', 'parent_of', [ctx.departmentId]]);
    } else {
      domain.add(['department_ids', '=', false]);
    }

    return domain;
  }

  List<List<dynamic>> _mandatoryDayDomainVariants({
    required _EmployeeHolidayContext ctx,
    required String rangeStart,
    required String rangeEnd,
  }) {
    final yearOverlap = <dynamic>[
      ['start_date', '<=', rangeEnd],
      ['end_date', '>=', rangeStart],
    ];

    return [
      // Same as Odoo config list with Period = current year (no extra filters).
      [...yearOverlap],
      [
        ...yearOverlap,
        if (ctx.companyIds.isNotEmpty) ['company_id', 'in', ctx.companyIds],
      ],
      _odooMandatoryDayDomain(ctx, rangeStart, rangeEnd),
      [
        ...yearOverlap,
        if (ctx.companyIds.isNotEmpty) ['company_id', 'in', ctx.companyIds],
        '|',
        ['resource_calendar_id', '=', false],
        ['resource_calendar_id', '=', ctx.calendarId ?? false],
      ],
    ];
  }

  /// Reads [hr.leave.mandatory.day] — `name` + `company_id` like Odoo list view.
  Future<List<LeaveCalendarInfoItem>> _readMandatoryDays({
    required List<dynamic> domain,
    required int limit,
  }) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave.mandatory.day',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['name', 'start_date', 'end_date', 'company_id'],
          'order': 'start_date asc',
          'limit': limit,
        },
      });

      if (result is! List) return [];

      final items = <LeaveCalendarInfoItem>[];

      for (final raw in result) {
        final row = Map<String, dynamic>.from(raw as Map);
        final from = OdooDateTime.parseDate(row['start_date']);
        final to = OdooDateTime.parseDate(row['end_date']) ?? from;
        final name = row['name']?.toString().trim() ?? '';
        final company = row['company_id'];
        String? companyName;
        if (company is List && company.length > 1) {
          companyName = company[1]?.toString();
        }

        items.add(
          LeaveCalendarInfoItem(
            title: name.isNotEmpty ? name : 'Mandatory Day',
            dateFrom: from,
            dateTo: to,
            subtitle: companyName,
          ),
        );
      }

      return items;
    } catch (e, st) {
      ApiLogger.error('_readMandatoryDays domain=$domain', e, st);
      return [];
    }
  }

  Future<List<LeaveCalendarInfoItem>> fetchPublicHolidays({
    required int employeeId,
    int limit = 30,
  }) async {
    ApiLogger.info(
      '--- LeaveRepository.fetchPublicHolidays emp=$employeeId ---',
    );
    final range = _defaultHolidayRange();
    final ctx = await _employeeHolidayContext(employeeId);
    final todayStr = range.start;

    // Primary: resource.calendar.leaves (field `name`) — same model as Odoo UI.
    for (final domain in _publicHolidayDomainVariants(
      ctx: ctx,
      rangeStart: range.start,
      rangeEnd: range.end,
      todayStr: todayStr,
    )) {
      final items = await _readResourceCalendarLeaves(
        domain: domain,
        limit: limit,
        onlyUpcoming: true,
      );
      if (items.isNotEmpty) {
        ApiLogger.info(
          'fetchPublicHolidays resource.calendar.leaves count=${items.length}',
        );
        return items;
      }
    }

    // Fallback only if search_read returned nothing.
    final fromApi = await _fetchPublicHolidaysViaOdooApi(
      employeeId: employeeId,
      rangeStart: range.start,
      rangeEnd: range.end,
      onlyUpcoming: true,
      limit: limit,
    );
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;

    return [];
  }

  List<List<dynamic>> _publicHolidayDomainVariants({
    required _EmployeeHolidayContext ctx,
    required String rangeStart,
    required String rangeEnd,
    required String todayStr,
  }) {
    final calId = ctx.calendarId;
    final calendarOrGlobal = <dynamic>[
      '|',
      ['calendar_id', '=', false],
      if (calId != null)
        ['calendar_id', '=', calId]
      else
        ['calendar_id', '=', false],
    ];

    return [
      // Odoo hr.employee._get_public_holidays
      [
        ['resource_id', '=', false],
        if (ctx.companyId != null) ['company_id', 'in', [ctx.companyId]],
        ['date_from', '<=', rangeEnd],
        ['date_to', '>=', rangeStart],
        ...calendarOrGlobal,
      ],
      // Same without company (some DBs store company_id empty on globals)
      [
        ['resource_id', '=', false],
        ['date_from', '<=', rangeEnd],
        ['date_to', '>=', rangeStart],
        ...calendarOrGlobal,
      ],
      // Upcoming globals + employee working schedule
      [
        ['resource_id', '=', false],
        ['date_to', '>=', todayStr],
        ...calendarOrGlobal,
      ],
      // Minimal: company public holidays only (no calendar filter)
      [
        ['resource_id', '=', false],
        ['date_to', '>=', todayStr],
      ],
    ];
  }

  /// Reads [resource.calendar.leaves] using the `name` field (public holiday label).
  Future<List<LeaveCalendarInfoItem>> _readResourceCalendarLeaves({
    required List<dynamic> domain,
    required int limit,
    required bool onlyUpcoming,
  }) async {
    const fields = ['name', 'date_from', 'date_to', 'resource_id'];

    try {
      final result = await _client.callKw({
        'model': 'resource.calendar.leaves',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': fields,
          'order': 'date_from asc',
          'limit': limit,
        },
      });

      if (result is! List) return [];

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final items = <LeaveCalendarInfoItem>[];

      for (final raw in result) {
        final row = Map<String, dynamic>.from(raw as Map);
        // Exclude rows tied to a specific employee resource (validated time off).
        final resource = row['resource_id'];
        if (resource is List && resource.isNotEmpty) continue;

        final from = OdooDateTime.parse(row['date_from']) ??
            OdooDateTime.parseDate(row['date_from']);
        final to = OdooDateTime.parse(row['date_to']) ??
            OdooDateTime.parseDate(row['date_to']) ??
            from;

        if (onlyUpcoming && to != null) {
          final endDate = DateTime(to.year, to.month, to.day);
          if (endDate.isBefore(todayDate)) continue;
        }

        final name = row['name']?.toString().trim() ?? '';
        items.add(
          LeaveCalendarInfoItem(
            title: name.isNotEmpty ? name : 'Public Holiday',
            dateFrom: from,
            dateTo: to,
          ),
        );
      }

      return items;
    } catch (e, st) {
      ApiLogger.error(
        '_readResourceCalendarLeaves domain=$domain',
        e,
        st,
      );
      return [];
    }
  }

  /// Same window Odoo Time Off calendar uses for special days (±1 year).
  ({String start, String end}) _defaultHolidayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year + 1, now.month, now.day);
    return (start: _toDateOnly(start), end: _toDateOnly(end));
  }

  Map<String, dynamic> _employeeRpcContext(int employeeId) => {
        'employee_id': employeeId,
        'default_employee_id': employeeId,
      };

  /// Full RPC context for Time Off APIs (needs company scope on Odoo 17+).
  Future<Map<String, dynamic>> _buildEmployeeRpcContext(int employeeId) async {
    final ctx = _employeeRpcContext(employeeId);
    try {
      final holidayCtx = await _employeeHolidayContext(employeeId);
      if (holidayCtx.companyIds.isNotEmpty) {
        ctx['allowed_company_ids'] = holidayCtx.companyIds;
      }
    } catch (e, st) {
      ApiLogger.error('_buildEmployeeRpcContext company ids', e, st);
    }
    return ctx;
  }

  String _rangeStartDateTime(String date) => '$date 00:00:00';
  String _rangeEndDateTime(String date) => '$date 23:59:59';

  /// Official Odoo Time Off calendar RPC (`hr.employee.get_public_holidays_data`).
  Future<List<LeaveCalendarInfoItem>?> _fetchPublicHolidaysViaOdooApi({
    required int employeeId,
    required String rangeStart,
    required String rangeEnd,
    required bool onlyUpcoming,
    required int limit,
  }) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'get_public_holidays_data',
        'args': [rangeStart, rangeEnd],
        'kwargs': {'context': _employeeRpcContext(employeeId)},
      });
      if (result is List) {
        ApiLogger.info('fetchPublicHolidays via get_public_holidays_data');
        return _parseOdooCalendarEvents(
          result,
          defaultTitle: 'Public Holiday',
          onlyUpcoming: onlyUpcoming,
          limit: limit,
        );
      }
    } catch (e, st) {
      ApiLogger.error('get_public_holidays_data', e, st);
    }

    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'get_special_days_data',
        'args': [rangeStart, rangeEnd],
        'kwargs': {'context': _employeeRpcContext(employeeId)},
      });
      if (result is Map && result['bankHolidays'] is List) {
        ApiLogger.info('fetchPublicHolidays via get_special_days_data');
        return _parseOdooCalendarEvents(
          result['bankHolidays'] as List,
          defaultTitle: 'Public Holiday',
          onlyUpcoming: onlyUpcoming,
          limit: limit,
        );
      }
    } catch (e, st) {
      ApiLogger.error('get_special_days_data bankHolidays', e, st);
    }

    return null;
  }

  Future<List<LeaveCalendarInfoItem>?> _fetchMandatoryDaysViaOdooApi({
    required int employeeId,
    required String rangeStart,
    required String rangeEnd,
    required int limit,
  }) async {
    final dateArgSets = [
      [rangeStart, rangeEnd],
      [_rangeStartDateTime(rangeStart), _rangeEndDateTime(rangeEnd)],
    ];
    final rpcContext = _employeeRpcContext(employeeId);

    for (final args in dateArgSets) {
      try {
        final result = await _client.callKw({
          'model': 'hr.employee',
          'method': 'get_mandatory_days_data',
          'args': args,
          'kwargs': {'context': rpcContext},
        });
        if (result is List && result.isNotEmpty) {
          ApiLogger.info('fetchMandatoryDays via get_mandatory_days_data');
          return _parseOdooCalendarEvents(
            result,
            defaultTitle: 'Mandatory Day',
            onlyUpcoming: false,
            limit: limit,
          );
        }
      } catch (e, st) {
        ApiLogger.error('get_mandatory_days_data args=$args', e, st);
      }

      try {
        final result = await _client.callKw({
          'model': 'hr.employee',
          'method': 'get_special_days_data',
          'args': args,
          'kwargs': {'context': rpcContext},
        });
        if (result is Map && result['mandatoryDays'] is List) {
          final days = result['mandatoryDays'] as List;
          if (days.isNotEmpty) {
            ApiLogger.info('fetchMandatoryDays via get_special_days_data');
            return _parseOdooCalendarEvents(
              days,
              defaultTitle: 'Mandatory Day',
              onlyUpcoming: false,
              limit: limit,
            );
          }
        }
      } catch (e, st) {
        ApiLogger.error('get_special_days_data args=$args', e, st);
      }
    }

    return null;
  }

  List<LeaveCalendarInfoItem> _parseOdooCalendarEvents(
    List events, {
    required String defaultTitle,
    required bool onlyUpcoming,
    required int limit,
  }) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final items = <LeaveCalendarInfoItem>[];

    for (final raw in events) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final title = row['title']?.toString().trim();
      final from = _parseOdooEventInstant(row['start']);
      final to = _parseOdooEventInstant(row['end']) ?? from;

      if (onlyUpcoming && to != null) {
        final endDate = DateTime(to.year, to.month, to.day);
        if (endDate.isBefore(todayDate)) continue;
      }

      items.add(
        LeaveCalendarInfoItem(
          title: title != null && title.isNotEmpty ? title : defaultTitle,
          dateFrom: from,
          dateTo: to ?? from,
        ),
      );
    }

    items.sort((a, b) {
      final af = a.dateFrom ?? DateTime(2100);
      final bf = b.dateFrom ?? DateTime(2100);
      return af.compareTo(bf);
    });

    if (items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }

  DateTime? _parseOdooEventInstant(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value) ?? OdooDateTime.parseDate(value);
    }
    return OdooDateTime.parse(value) ?? OdooDateTime.parseDate(value);
  }

  Future<_EmployeeHolidayContext> _employeeHolidayContext(int employeeId) async {
    int? calendarId;
    int? companyId;
    int? departmentId;

    for (final model in ['hr.employee', 'hr.employee.public']) {
      try {
        final result = await _client.callKw({
          'model': model,
          'method': 'search_read',
          'args': [
            [
              ['id', '=', employeeId],
            ],
          ],
          'kwargs': {
            'fields': [
              'resource_calendar_id',
              'company_id',
              'department_id',
            ],
            'limit': 1,
          },
        });
        if (result is! List || result.isEmpty) continue;
        final row = Map<String, dynamic>.from(result.first as Map);
        calendarId = _m2oId(row['resource_calendar_id']);
        companyId = _m2oId(row['company_id']);
        departmentId = _m2oId(row['department_id']);
        break;
      } catch (e, st) {
        ApiLogger.error('_employeeHolidayContext model=$model', e, st);
      }
    }

    final companyIds = await _resolveCompanyIds(companyId);
    return _EmployeeHolidayContext(
      calendarId: calendarId,
      companyId: companyId,
      companyIds: companyIds,
      departmentId: departmentId,
    );
  }

  /// Odoo uses `env.companies.ids` — include employee company + allowed companies.
  Future<List<int>> _resolveCompanyIds(int? employeeCompanyId) async {
    final ids = <int>{};
    if (employeeCompanyId != null) ids.add(employeeCompanyId);

    try {
      final result = await _client.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id'],
          'limit': 32,
        },
      });
      if (result is List) {
        for (final raw in result) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'];
          if (id is int) ids.add(id);
        }
      }
    } catch (e, st) {
      ApiLogger.error('_resolveCompanyIds', e, st);
    }

    return ids.toList();
  }

  int? _m2oId(dynamic field) {
    if (field is List && field.isNotEmpty) return field[0] as int?;
    return null;
  }

  Future<List<LeaveBalanceItem>> fetchBalances(int employeeId) async {
    ApiLogger.info('--- LeaveRepository.fetchBalances emp=$employeeId ---');

    final fromApi = await _fetchBalancesViaOdooApi(employeeId);
    if (fromApi != null && fromApi.isNotEmpty) {
      ApiLogger.info(
        'fetchBalances ok via Odoo API emp=$employeeId count=${fromApi.length}',
      );
      return fromApi;
    }

    final fromAllocations = await _fetchBalancesFromAllocations(employeeId);
    ApiLogger.info(
      'fetchBalances ok via allocations emp=$employeeId count=${fromAllocations.length}',
    );
    return fromAllocations;
  }

  String _todayDateString() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// Uses the same RPC Odoo's Time Off dashboard uses (accurate remaining days).
  Future<List<LeaveBalanceItem>?> _fetchBalancesViaOdooApi(int employeeId) async {
    final ctx = await _buildEmployeeRpcContext(employeeId);
    final targetDate = _todayDateString();

    // Odoo 18 self-service API — uses contextual employee from RPC context.
    // Do not call get_allocation_data directly; JSON-RPC cannot pass hr.employee
    // recordsets correctly and throws on this server (hr_holidays_attendance).
    for (final args in [
      [targetDate],
      const <String>[],
    ]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave.type',
          'method': 'get_allocation_data_request',
          'args': args,
          'kwargs': {'context': ctx},
        });
        final rows = result is List
            ? result
            : _extractEmployeeAllocationRows(result, employeeId);
        final items = _parseOdooBalanceApiResult(rows);
        if (items.isNotEmpty) {
          ApiLogger.info(
            'fetchBalances via get_allocation_data_request emp=$employeeId count=${items.length}',
          );
          return items;
        }
      } catch (e, st) {
        ApiLogger.error(
          'fetchBalances get_allocation_data_request emp=$employeeId args=$args',
          e,
          st,
        );
      }
    }

    return null;
  }

  List<dynamic>? _extractEmployeeAllocationRows(
    dynamic result,
    int employeeId,
  ) {
    if (result is List) return result;
    if (result is! Map) return null;

    final keyed = result[employeeId] ?? result['$employeeId'];
    if (keyed is List) return keyed;

    if (result.length == 1) {
      final only = result.values.first;
      if (only is List) return only;
    }
    return null;
  }

  List<LeaveBalanceItem> _parseOdooBalanceApiResult(List<dynamic>? rows) {
    if (rows == null || rows.isEmpty) return [];

    final items = <LeaveBalanceItem>[];
    for (final raw in rows) {
      if (raw is! List || raw.length < 2) continue;

      final name = raw[0]?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final stats = raw[1];
      if (stats is! Map) continue;
      final data = Map<String, dynamic>.from(stats);

      final typeId = raw.length >= 4 && raw[3] is int ? raw[3] as int : null;
      final maxLeaves = _toDouble(data['max_leaves']);
      final remaining = _toDouble(
        data['virtual_remaining_leaves'] ?? data['remaining_leaves'],
      );
      final taken = _toDouble(data['leaves_taken']);

      if (maxLeaves <= 0 && remaining <= 0 && taken <= 0) continue;

      final total = maxLeaves > 0 ? maxLeaves : remaining + taken;
      items.add(
        LeaveBalanceItem(
          name: name,
          typeId: typeId,
          total: total,
          remaining: remaining,
          taken: taken,
        ),
      );
    }

    return _aggregateBalancesByType(items);
  }

  Future<List<LeaveBalanceItem>> _fetchBalancesFromAllocations(
    int employeeId,
  ) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave.allocation',
        'method': 'search_read',
        'args': [
          [
            ['employee_id', '=', employeeId],
            ['state', '=', 'validate'],
          ],
        ],
        'kwargs': {
          'fields': ['holiday_status_id', 'number_of_days'],
        },
      });

      if (result is! List || result.isEmpty) return [];

      final consumedByType = await _fetchConsumedDaysByLeaveType(employeeId);
      final totalsByType = <int, ({String name, double total})>{};

      for (final raw in result) {
        final row = Map<String, dynamic>.from(raw as Map);
        final type = row['holiday_status_id'];
        var name = 'Leave';
        int? typeId;
        if (type is List && type.isNotEmpty) {
          typeId = type[0] as int?;
          if (type.length > 1) name = type[1].toString();
        }
        if (typeId == null) continue;

        final days = _toDouble(row['number_of_days']);
        final existing = totalsByType[typeId];
        if (existing == null) {
          totalsByType[typeId] = (name: name, total: days);
        } else {
          totalsByType[typeId] = (
            name: existing.name,
            total: existing.total + days,
          );
        }
      }

      final items = totalsByType.entries.map((entry) {
        final typeId = entry.key;
        final total = entry.value.total;
        final taken = consumedByType[typeId] ?? 0;
        return LeaveBalanceItem(
          name: entry.value.name,
          typeId: typeId,
          total: total,
          taken: taken,
          remaining: total - taken,
        );
      }).toList();

      return items.where((b) => b.total > 0 || b.remaining > 0).toList();
    } catch (e, st) {
      ApiLogger.error('fetchBalances search_read allocations', e, st);
      return [];
    }
  }

  Future<Map<int, double>> _fetchConsumedDaysByLeaveType(int employeeId) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [
          [
            ['employee_id', '=', employeeId],
            ['state', 'in', ['confirm', 'validate1', 'validate']],
          ],
        ],
        'kwargs': {
          'fields': ['holiday_status_id', 'number_of_days'],
        },
      });

      if (result is! List) return {};

      final consumed = <int, double>{};
      for (final raw in result) {
        final row = Map<String, dynamic>.from(raw as Map);
        final typeId = _m2oId(row['holiday_status_id']);
        if (typeId == null) continue;
        consumed[typeId] =
            (consumed[typeId] ?? 0) + _toDouble(row['number_of_days']);
      }
      return consumed;
    } catch (e, st) {
      ApiLogger.error('_fetchConsumedDaysByLeaveType emp=$employeeId', e, st);
      return {};
    }
  }

  List<LeaveBalanceItem> _aggregateBalancesByType(List<LeaveBalanceItem> items) {
    final byType = <int, LeaveBalanceItem>{};
    final unnamed = <LeaveBalanceItem>[];

    for (final item in items) {
      final typeId = item.typeId;
      if (typeId == null) {
        unnamed.add(item);
        continue;
      }
      final existing = byType[typeId];
      if (existing == null) {
        byType[typeId] = item;
      } else {
        byType[typeId] = LeaveBalanceItem(
          name: existing.name,
          typeId: typeId,
          total: existing.total + item.total,
          remaining: existing.remaining + item.remaining,
          taken: existing.taken + item.taken,
        );
      }
    }

    return [...byType.values, ...unnamed];
  }

  double _toDouble(dynamic value) {
    if (value == null || value == false) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<List<LeaveRecord>> fetchLeaveRequests({
    required int employeeId,
    int limit = 80,
  }) async {
    ApiLogger.info(
      '--- LeaveRepository.fetchLeaveRequests emp=$employeeId ---',
    );

    final ctx = await _buildEmployeeRpcContext(employeeId);

    for (final fields in [_fieldsLeave, _fieldsLeaveBasic]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave',
          'method': 'search_read',
          'args': [
            [
              ['employee_id', '=', employeeId],
            ],
          ],
          'kwargs': {
            'fields': fields,
            'order': 'date_from desc',
            'limit': limit,
            'context': ctx,
          },
        });

        if (result is! List) return [];

        final records = result
            .map((e) => LeaveRecord.fromOdoo(Map<String, dynamic>.from(e as Map)))
            .where((r) => r.employeeId == null || r.employeeId == employeeId)
            .toList();
        ApiLogger.info(
          'fetchLeaveRequests ok emp=$employeeId count=${records.length}',
        );
        return records;
      } catch (e, st) {
        ApiLogger.error('fetchLeaveRequests fields=$fields', e, st);
        if (fields == _fieldsLeaveBasic) rethrow;
      }
    }
    return [];
  }

  /// All time off records across employees, no state filter — mirrors the
  /// Odoo Time Off "Management" list. Record rules on the server still scope
  /// what a non-manager account can actually see.
  Future<List<LeaveRecord>> fetchAllLeaveRequests({
    int limit = 200,
    List<int>? employeeIds,
  }) async {
    ApiLogger.info('--- LeaveRepository.fetchAllLeaveRequests ---');

    final domain = [
      if (employeeIds != null) ['employee_id', 'in', employeeIds],
    ];

    for (final fields in [_fieldsLeave, _fieldsLeaveBasic]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': fields,
            'order': 'date_from desc, id desc',
            'limit': limit,
          },
        });

        if (result is! List) return [];

        final records = result
            .map((e) => LeaveRecord.fromOdoo(Map<String, dynamic>.from(e as Map)))
            .toList();
        ApiLogger.info('fetchAllLeaveRequests ok count=${records.length}');
        return records;
      } catch (e, st) {
        ApiLogger.error('fetchAllLeaveRequests fields=$fields', e, st);
        if (fields == _fieldsLeaveBasic) rethrow;
      }
    }
    return [];
  }

  Future<List<LeaveRecord>> fetchApprovalRequests({
    int limit = 80,
    List<int>? employeeIds,
  }) async {
    ApiLogger.info('--- LeaveRepository.fetchApprovalRequests ---');

    final domain = [
      ['state', 'in', ['confirm', 'validate1']],
      if (employeeIds != null) ['employee_id', 'in', employeeIds],
    ];

    for (final fields in [_fieldsLeave, _fieldsLeaveBasic]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': fields,
            'order': 'date_from desc',
            'limit': limit,
          },
        });

        if (result is! List) return [];

        return result
            .map((e) => LeaveRecord.fromOdoo(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e, st) {
        ApiLogger.error('fetchApprovalRequests fields=$fields', e, st);
        if (fields == _fieldsLeaveBasic) rethrow;
      }
    }
    return [];
  }

  Future<void> approveLeave(int leaveId) async {
    ApiLogger.info('--- LeaveRepository.approveLeave id=$leaveId ---');
    final methods = ['action_validate', 'action_approve'];
    var lastError = '';

    for (final method in methods) {
      try {
        await _client.callKw({
          'model': 'hr.leave',
          'method': method,
          'args': [
            [leaveId],
          ],
          'kwargs': {},
        });
        return;
      } catch (e, st) {
        lastError = e.toString();
        ApiLogger.error('approveLeave failed method=$method', e, st);
      }
    }
    throw Exception('Could not approve leave. $lastError');
  }

  Future<List<LeaveAllocationRecord>> fetchAllocationRecords({
    int limit = 120,
    List<int>? employeeIds,
  }) async {
    ApiLogger.info('--- LeaveRepository.fetchAllocationRecords ---');

    final domain = [
      if (employeeIds != null) ['employee_id', 'in', employeeIds],
    ];

    for (final fields in [_fieldsAllocationList, _fieldsAllocationListBasic]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave.allocation',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': fields,
            'order': 'create_date desc, id desc',
            'limit': limit,
          },
        });

        if (result is! List) return [];

        final records = result
            .map(
              (e) => LeaveAllocationRecord.fromOdoo(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        ApiLogger.info('fetchAllocationRecords ok count=${records.length}');
        return records;
      } catch (e, st) {
        ApiLogger.error('fetchAllocationRecords fields=$fields', e, st);
        if (fields == _fieldsAllocationListBasic) rethrow;
      }
    }
    return [];
  }

  Future<LeaveAllocationRecord?> fetchAllocationById(int allocationId) async {
    ApiLogger.info(
      '--- LeaveRepository.fetchAllocationById id=$allocationId ---',
    );

    Map<String, dynamic>? rawRow;

    for (final fields in [_fieldsAllocationDetail, _fieldsAllocationListBasic]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave.allocation',
          'method': 'search_read',
          'args': [
            [
              ['id', '=', allocationId],
            ],
          ],
          'kwargs': {
            'fields': fields,
            'limit': 1,
          },
        });

        if (result is! List || result.isEmpty) return null;

        rawRow = Map<String, dynamic>.from(result.first as Map);
        break;
      } catch (e, st) {
        ApiLogger.error('fetchAllocationById fields=$fields', e, st);
        if (fields == _fieldsAllocationListBasic) rethrow;
      }
    }

    if (rawRow == null) return null;

    if (_needsDatePatch(rawRow)) {
      rawRow = await _patchAllocationDates(allocationId, rawRow);
    }

    ApiLogger.info(
      'fetchAllocationById dates from=${rawRow['date_from']} to=${rawRow['date_to']} '
      'name_validity=${rawRow['name_validity']}',
    );

    return LeaveAllocationRecord.fromOdoo(rawRow);
  }

  Future<LeaveRecord?> fetchLeaveById(int leaveId) async {
    ApiLogger.info('--- LeaveRepository.fetchLeaveById id=$leaveId ---');

    for (final fields in [_fieldsLeave, _fieldsLeaveBasic]) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave',
          'method': 'search_read',
          'args': [
            [['id', '=', leaveId]],
          ],
          'kwargs': {
            'fields': fields,
            'limit': 1,
          },
        });

        if (result is! List || result.isEmpty) return null;

        return LeaveRecord.fromOdoo(
          Map<String, dynamic>.from(result.first as Map),
        );
      } catch (e, st) {
        ApiLogger.error('fetchLeaveById fields=$fields', e, st);
        if (fields == _fieldsLeaveBasic) rethrow;
      }
    }
    return null;
  }

  bool _needsDatePatch(Map<String, dynamic> row) {
    final from = row['date_from'];
    final to = row['date_to'];
    final hasFrom = from != false && from != null && from.toString().isNotEmpty;
    final hasTo = to != false && to != null && to.toString().isNotEmpty;
    return !hasFrom && !hasTo;
  }

  Future<Map<String, dynamic>> _patchAllocationDates(
    int allocationId,
    Map<String, dynamic> row,
  ) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave.allocation',
        'method': 'read',
        'args': [
          [allocationId],
          _fieldsAllocationDates,
        ],
      });

      if (result is List && result.isNotEmpty) {
        final patch = Map<String, dynamic>.from(result.first as Map);
        return {...row, ...patch};
      }
    } catch (e, st) {
      ApiLogger.error('patchAllocationDates failed', e, st);
    }
    return row;
  }

  Future<void> approveAllocation(int allocationId) async {
    ApiLogger.info(
      '--- LeaveRepository.approveAllocation id=$allocationId ---',
    );
    final methods = ['action_validate', 'action_approve'];
    var lastError = '';

    for (final method in methods) {
      try {
        await _client.callKw({
          'model': 'hr.leave.allocation',
          'method': method,
          'args': [
            [allocationId],
          ],
          'kwargs': {},
        });
        return;
      } catch (e, st) {
        lastError = e.toString();
        ApiLogger.error('approveAllocation failed method=$method', e, st);
      }
    }
    throw Exception('Could not approve allocation. $lastError');
  }

  Future<void> refuseAllocation(int allocationId) async {
    ApiLogger.info(
      '--- LeaveRepository.refuseAllocation id=$allocationId ---',
    );
    final methods = ['action_refuse', 'action_reject'];
    var lastError = '';

    for (final method in methods) {
      try {
        await _client.callKw({
          'model': 'hr.leave.allocation',
          'method': method,
          'args': [
            [allocationId],
          ],
          'kwargs': {},
        });
        return;
      } catch (e, st) {
        lastError = e.toString();
        ApiLogger.error('refuseAllocation failed method=$method', e, st);
      }
    }
    throw Exception('Could not refuse allocation. $lastError');
  }

  Future<void> refuseLeave(int leaveId) async {
    ApiLogger.info('--- LeaveRepository.refuseLeave id=$leaveId ---');
    final methods = ['action_refuse', 'action_reject'];
    var lastError = '';

    for (final method in methods) {
      try {
        await _client.callKw({
          'model': 'hr.leave',
          'method': method,
          'args': [
            [leaveId],
          ],
          'kwargs': {},
        });
        return;
      } catch (e, st) {
        lastError = e.toString();
        ApiLogger.error('refuseLeave failed method=$method', e, st);
      }
    }
    throw Exception('Could not refuse leave. $lastError');
  }

  /// Leave types the employee can request, matching the Odoo web form:
  /// - types that don't require an allocation (Sick, Unpaid, …) are always
  ///   requestable and shown without a remaining-days suffix;
  /// - allocation-based types appear only with remaining days > 0.
  Future<List<LeaveTypeOption>> fetchRequestableTypes(
    int employeeId, {
    List<LeaveBalanceItem>? balances,
  }) async {
    final balanceList = balances ?? await fetchBalances(employeeId);

    final remainingByType = <int, double>{};
    final nameByType = <int, String>{};
    for (final b in balanceList) {
      final typeId = b.typeId;
      if (typeId == null) continue;
      remainingByType[typeId] = (remainingByType[typeId] ?? 0) + b.remaining;
      nameByType[typeId] = b.name;
    }

    final meta = await _fetchLeaveTypeMeta();
    if (meta.isNotEmpty) {
      final options = <LeaveTypeOption>[];
      final seen = <int>{};

      // meta is ordered by sequence, so the dropdown matches the web order.
      for (final t in meta) {
        seen.add(t.id);
        if (t.requiresAllocation) {
          final remaining = remainingByType[t.id];
          if (remaining == null || remaining <= 0) continue;
          options.add(LeaveTypeOption(
            id: t.id,
            name: t.name,
            remainingDays: remaining,
            requestUnit: t.requestUnit,
            supportsDocument: t.supportsDocument,
          ));
        } else {
          options.add(LeaveTypeOption(
            id: t.id,
            name: t.name,
            requiresAllocation: false,
            requestUnit: t.requestUnit,
            supportsDocument: t.supportsDocument,
          ));
        }
      }

      // Allocation-backed types the meta read missed (e.g. other company).
      for (final entry in remainingByType.entries) {
        if (seen.contains(entry.key) || entry.value <= 0) continue;
        options.add(LeaveTypeOption(
          id: entry.key,
          name: nameByType[entry.key] ?? 'Leave',
          remainingDays: entry.value,
        ));
      }

      if (options.isNotEmpty) return options;
    }

    // Fallback: previous behavior (allocation balances only, then any type).
    final fromAllocations = remainingByType.entries
        .where((e) => e.value > 0)
        .map((e) => LeaveTypeOption(
              id: e.key,
              name: nameByType[e.key] ?? 'Leave',
              remainingDays: e.value,
            ))
        .toList();
    if (fromAllocations.isNotEmpty) return fromAllocations;

    return _fetchActiveLeaveTypes();
  }

  /// Reads active leave types with their allocation requirement, tolerating
  /// the field's history: `requires_allocation` is 'yes'/'no' on Odoo 14–18
  /// and boolean on newer versions; Odoo ≤13 used `allocation_type` instead.
  Future<List<_LeaveTypeMeta>> _fetchLeaveTypeMeta() async {
    const attempts = [
      (
        fields: [
          'id',
          'name',
          'requires_allocation',
          'request_unit',
          'support_document',
        ],
        ordered: true,
      ),
      (
        fields: ['id', 'name', 'requires_allocation', 'request_unit'],
        ordered: true,
      ),
      (fields: ['id', 'name', 'requires_allocation'], ordered: true),
      (
        fields: ['id', 'name', 'allocation_type', 'request_unit'],
        ordered: true,
      ),
      (fields: ['id', 'name', 'allocation_type'], ordered: true),
      (fields: ['id', 'name'], ordered: false),
    ];

    for (final attempt in attempts) {
      try {
        final result = await _client.callKw({
          'model': 'hr.leave.type',
          'method': 'search_read',
          'args': [
            [
              ['active', '=', true],
            ],
          ],
          'kwargs': {
            'fields': attempt.fields,
            if (attempt.ordered) 'order': 'sequence asc, id asc',
            'limit': 50,
          },
        });
        if (result is! List) continue;

        final meta = <_LeaveTypeMeta>[];
        for (final raw in result) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'];
          if (id is! int) continue;
          meta.add(_LeaveTypeMeta(
            id: id,
            name: row['name']?.toString() ?? 'Leave',
            requiresAllocation: _parseRequiresAllocation(
              row.containsKey('requires_allocation')
                  ? row['requires_allocation']
                  : row['allocation_type'],
            ),
            requestUnit: leaveRequestUnitFromOdoo(row['request_unit']),
            supportsDocument: row['support_document'] == true,
          ));
        }
        ApiLogger.info(
          '_fetchLeaveTypeMeta ok fields=${attempt.fields} count=${meta.length}',
        );
        return meta;
      } catch (e, st) {
        ApiLogger.error('_fetchLeaveTypeMeta fields=${attempt.fields}', e, st);
      }
    }
    return [];
  }

  /// 'no'/false → no allocation needed; anything unknown counts as required,
  /// so we never offer a type the server would reject.
  bool _parseRequiresAllocation(dynamic value) {
    if (value is bool) return value;
    if (value == null) return true;
    return value.toString().toLowerCase() != 'no';
  }

  Future<List<LeaveTypeOption>> _fetchActiveLeaveTypes() async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave.type',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'limit': 20,
        },
      });

      if (result is! List) return [];

      return result.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return LeaveTypeOption(
          id: row['id'] as int,
          name: row['name']?.toString() ?? 'Leave',
          requiresAllocation: false,
        );
      }).toList();
    } catch (e, st) {
      ApiLogger.error('_fetchActiveLeaveTypes failed', e, st);
      return [];
    }
  }

  Future<Set<String>> fetchUnusualDays({
    required int employeeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave',
        'method': 'get_unusual_days',
        'args': [
          _toDateTime(rangeStart, endOfDay: false),
          _toDateTime(rangeEnd, endOfDay: true),
        ],
        'kwargs': {'context': _employeeRpcContext(employeeId)},
      });
      if (result is! Map) return {};

      final unusual = <String>{};
      for (final entry in result.entries) {
        if (entry.value == true) {
          unusual.add(entry.key.toString());
        }
      }
      ApiLogger.info(
        'fetchUnusualDays emp=$employeeId count=${unusual.length}',
      );
      return unusual;
    } catch (e, st) {
      ApiLogger.error('fetchUnusualDays emp=$employeeId', e, st);
      return {};
    }
  }

  Future<double> computeRequestedLeaveDays({
    required int employeeId,
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    List<LeaveCalendarInfoItem> publicHolidays = const [],
    List<LeaveCalendarInfoItem> mandatoryDays = const [],
  }) async {
    final start = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final end = DateTime(dateTo.year, dateTo.month, dateTo.day);
    if (end.isBefore(start)) return 0;

    final odooDays = await _computeLeaveDurationViaOdoo(
      employeeId: employeeId,
      leaveTypeId: leaveTypeId,
      dateFrom: start,
      dateTo: end,
    );
    if (odooDays != null && odooDays > 0) {
      return odooDays;
    }

    return _countLocalWorkingDays(
      start: start,
      end: end,
      publicHolidays: publicHolidays,
      mandatoryDays: mandatoryDays,
    );
  }

  Future<double?> _computeLeaveDurationViaOdoo({
    required int employeeId,
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final ctx = await _buildEmployeeRpcContext(employeeId);
    final values = _leaveRequestValues(
      employeeId: employeeId,
      leaveTypeId: leaveTypeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    try {
      final result = await _client.callKw({
        'model': 'hr.leave',
        'method': 'onchange',
        'args': [
          [],
          values,
          ['request_date_from', 'request_date_to', 'holiday_status_id'],
          {
            'employee_id': '',
            'holiday_status_id': '',
            'request_date_from': '',
            'request_date_to': '',
            'number_of_days': '',
          },
        ],
        'kwargs': {'context': ctx},
      });
      if (result is Map) {
        final value = result['value'];
        if (value is Map) {
          final days = _toDouble(value['number_of_days']);
          if (days > 0) return days;
        }
      }
    } catch (e, st) {
      ApiLogger.error('computeLeaveDurationViaOdoo onchange', e, st);
    }
    return null;
  }

  double _countLocalWorkingDays({
    required DateTime start,
    required DateTime end,
    required List<LeaveCalendarInfoItem> publicHolidays,
    required List<LeaveCalendarInfoItem> mandatoryDays,
  }) {
    var days = 0.0;
    var current = start;
    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday &&
          !_isCalendarDayBlocked(current, publicHolidays) &&
          !_isCalendarDayBlocked(current, mandatoryDays)) {
        days += 1;
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  bool _isCalendarDayBlocked(
    DateTime day,
    List<LeaveCalendarInfoItem> items,
  ) {
    final d = DateTime(day.year, day.month, day.day);
    for (final item in items) {
      final from = item.dateFrom;
      if (from == null) continue;
      final start = DateTime(from.year, from.month, from.day);
      final toRaw = item.dateTo ?? from;
      final end = DateTime(toRaw.year, toRaw.month, toRaw.day);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  Map<String, dynamic> _leaveRequestValues({
    required int employeeId,
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String description = '',
    bool halfDay = false,
    HalfDayPeriod halfDayPeriod = HalfDayPeriod.morning,
    bool customHours = false,
    double? hourFrom,
    double? hourTo,
    bool hoursAsString = false,
  }) {
    final start = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    // Half-day and custom-hours requests always cover a single date.
    final end = (halfDay || customHours)
        ? start
        : DateTime(dateTo.year, dateTo.month, dateTo.day);
    return {
      'employee_id': employeeId,
      'holiday_status_id': leaveTypeId,
      'request_date_from': _toDateOnly(start),
      'request_date_to': _toDateOnly(end),
      if (halfDay) 'request_unit_half': true,
      if (halfDay) 'request_date_from_period': halfDayPeriod.odooValue,
      if (customHours) 'request_unit_hours': true,
      if (customHours && hourFrom != null)
        'request_hour_from': hoursAsString ? _hourKey(hourFrom) : hourFrom,
      if (customHours && hourTo != null)
        'request_hour_to': hoursAsString ? _hourKey(hourTo) : hourTo,
      if (description.trim().isNotEmpty) 'name': description.trim(),
    };
  }

  /// Odoo 14–16 store request hours as selection keys ('8', '8.5', …);
  /// Odoo 17+ use plain floats.
  String _hourKey(double hour) {
    return hour == hour.truncateToDouble()
        ? hour.toInt().toString()
        : hour.toString();
  }

  int _calendarSpanDays(DateTime dateFrom, DateTime dateTo) {
    final start = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final end = DateTime(dateTo.year, dateTo.month, dateTo.day);
    return end.difference(start).inDays + 1;
  }

  Future<double?> _readLeaveDuration(int leaveId) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.leave',
        'method': 'read',
        'args': [
          [leaveId],
          ['number_of_days', 'request_date_from', 'request_date_to'],
        ],
        'kwargs': {},
      });
      if (result is List && result.isNotEmpty) {
        final row = Map<String, dynamic>.from(result.first as Map);
        return _toDouble(row['number_of_days']);
      }
    } catch (e, st) {
      ApiLogger.error('_readLeaveDuration id=$leaveId', e, st);
    }
    return null;
  }

  Future<void> _ensureLeaveDuration({
    required int leaveId,
    required int employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final span = _calendarSpanDays(dateFrom, dateTo);
    if (span <= 1) return;

    final duration = await _readLeaveDuration(leaveId);
    if (duration == null || duration >= 1.5) return;

    final ctx = await _buildEmployeeRpcContext(employeeId);
    final values = {
      'request_date_from': _toDateOnly(
        DateTime(dateFrom.year, dateFrom.month, dateFrom.day),
      ),
      'request_date_to': _toDateOnly(
        DateTime(dateTo.year, dateTo.month, dateTo.day),
      ),
    };

    try {
      await _client.callKw({
        'model': 'hr.leave',
        'method': 'write',
        'args': [
          [leaveId],
          values,
        ],
        'kwargs': {'context': ctx},
      });
      final fixed = await _readLeaveDuration(leaveId);
      ApiLogger.info(
        'createLeaveRequest recomputed days span=$span fixed=$fixed',
      );
    } catch (e, st) {
      ApiLogger.error('ensureLeaveDuration write id=$leaveId', e, st);
    }
  }

  Future<int?> createLeaveRequest({
    required int employeeId,
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String description = '',
    bool halfDay = false,
    HalfDayPeriod halfDayPeriod = HalfDayPeriod.morning,
    bool customHours = false,
    double? hourFrom,
    double? hourTo,
  }) async {
    ApiLogger.info('--- LeaveRepository.createLeaveRequest ---');

    final ctx = await _buildEmployeeRpcContext(employeeId);

    // Custom-hours values need a second attempt because the hour fields'
    // representation differs by Odoo version (float vs selection string).
    final valueVariants = [
      for (final asString in customHours ? [false, true] : [false])
        _leaveRequestValues(
          employeeId: employeeId,
          leaveTypeId: leaveTypeId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          description: description,
          halfDay: halfDay,
          halfDayPeriod: halfDayPeriod,
          customHours: customHours,
          hourFrom: hourFrom,
          hourTo: hourTo,
          hoursAsString: asString,
        ),
    ];

    for (var i = 0; i < valueVariants.length; i++) {
      final values = valueVariants[i];
      final isLastVariant = i == valueVariants.length - 1;
      try {
        final id = await _client.callKw({
          'model': 'hr.leave',
          'method': 'create',
          'args': [values],
          'kwargs': {'context': ctx},
        });
        if (id is! int) return null;

        if (!halfDay && !customHours) {
          await _ensureLeaveDuration(
            leaveId: id,
            employeeId: employeeId,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );
        }

        final days = await _readLeaveDuration(id);
        ApiLogger.info(
          'createLeaveRequest ok id=$id days=$days values=$values',
        );
        return id;
      } catch (e, st) {
        ApiLogger.error('createLeaveRequest failed values=$values', e, st);
        final msg = e.toString();
        if (msg.contains('overlaps with this period') ||
            msg.contains('allocation') ||
            msg.contains('not enough') ||
            msg.contains('valid allocation')) {
          rethrow;
        }
        if (isLastVariant) return null;
      }
    }
    return null;
  }

  /// Uploads supporting documents onto a leave request. Returns how many
  /// uploaded successfully; a failed file is logged and skipped so the
  /// already-created request survives.
  Future<int> uploadLeaveAttachments(
    int leaveId,
    List<LeaveAttachmentUpload> attachments,
  ) async {
    var uploaded = 0;
    for (final attachment in attachments) {
      try {
        await _client.callKw({
          'model': 'ir.attachment',
          'method': 'create',
          'args': [
            {
              'name': attachment.fileName,
              'res_model': 'hr.leave',
              'res_id': leaveId,
              'datas': base64Encode(attachment.bytes),
              'mimetype': attachment.mimeType,
            }
          ],
          'kwargs': {},
        });
        uploaded++;
      } catch (e, st) {
        ApiLogger.error(
          'uploadLeaveAttachments failed leave=$leaveId file=${attachment.fileName}',
          e,
          st,
        );
      }
    }
    ApiLogger.info(
      'uploadLeaveAttachments leave=$leaveId ok=$uploaded/${attachments.length}',
    );
    return uploaded;
  }

  /// Supporting documents for the given leave requests, keyed by leave id.
  Future<Map<int, List<LeaveAttachment>>> fetchLeaveAttachments(
    List<int> leaveIds,
  ) async {
    if (leaveIds.isEmpty) return {};
    try {
      final result = await _client.callKw({
        'model': 'ir.attachment',
        'method': 'search_read',
        'args': [
          [
            ['res_model', '=', 'hr.leave'],
            ['res_id', 'in', leaveIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'mimetype', 'res_id'],
          'order': 'id desc',
        },
      });
      if (result is! List) return {};

      final byLeave = <int, List<LeaveAttachment>>{};
      for (final raw in result) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id'];
        final resId = row['res_id'];
        if (id is! int || resId is! int) continue;
        byLeave.putIfAbsent(resId, () => []).add(LeaveAttachment(
              id: id,
              name: row['name']?.toString() ?? 'attachment',
              mimetype:
                  row['mimetype']?.toString() ?? 'application/octet-stream',
              leaveId: resId,
            ));
      }
      return byLeave;
    } catch (e, st) {
      ApiLogger.error('fetchLeaveAttachments ids=$leaveIds', e, st);
      return {};
    }
  }

  /// Reads an attachment's binary content over the authenticated session.
  Future<List<int>?> downloadAttachment(int attachmentId) async {
    try {
      final result = await _client.callKw({
        'model': 'ir.attachment',
        'method': 'read',
        'args': [
          [attachmentId],
          ['datas'],
        ],
        'kwargs': {},
      });
      if (result is! List || result.isEmpty) return null;
      final row = Map<String, dynamic>.from(result.first as Map);
      final base64Data = row['datas'];
      if (base64Data is! String) return null;
      return base64Decode(base64Data);
    } catch (e, st) {
      ApiLogger.error('downloadAttachment id=$attachmentId', e, st);
      return null;
    }
  }

  Future<void> updateLeaveRequest({
    required int leaveId,
    required int employeeId,
    required int leaveTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String description = '',
  }) async {
    ApiLogger.info('--- LeaveRepository.updateLeaveRequest id=$leaveId ---');

    final ctx = await _buildEmployeeRpcContext(employeeId);
    final values = {
      ..._leaveRequestValues(
        employeeId: employeeId,
        leaveTypeId: leaveTypeId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        description: description,
      ),
      'name': description.trim(),
    };

    try {
      await _client.callKw({
        'model': 'hr.leave',
        'method': 'write',
        'args': [
          [leaveId],
          values,
        ],
        'kwargs': {'context': ctx},
      });
      await _ensureLeaveDuration(
        leaveId: leaveId,
        employeeId: employeeId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      return;
    } catch (e, st) {
      ApiLogger.error('updateLeaveRequest failed values=$values', e, st);
      rethrow;
    }
  }

  Future<void> cancelLeaveRequest(
    int leaveId, {
    required LeaveState state,
  }) async {
    ApiLogger.info(
      '--- LeaveRepository.cancelLeaveRequest id=$leaveId state=$state ---',
    );

    final isPending = state == LeaveState.draft ||
        state == LeaveState.toApprove ||
        state == LeaveState.secondApproval;

    if (isPending) {
      try {
        await _client.callKw({
          'model': 'hr.leave',
          'method': 'unlink',
          'args': [
            [leaveId],
          ],
          'kwargs': {},
        });
        return;
      } catch (e, st) {
        ApiLogger.error('cancelLeaveRequest unlink failed id=$leaveId', e, st);
      }
    }

    var lastError = '';
    for (final method in ['_action_user_cancel']) {
      try {
        await _client.callKw({
          'model': 'hr.leave',
          'method': method,
          'args': [
            [leaveId],
          ],
          'kwargs': {},
        });
        return;
      } catch (e, st) {
        lastError = e.toString();
        ApiLogger.error('cancelLeaveRequest failed method=$method', e, st);
      }
    }

    try {
      await _client.callKw({
        'model': 'hr.leave',
        'method': 'write',
        'args': [
          [leaveId],
          {'state': 'cancel'},
        ],
        'kwargs': {},
      });
      return;
    } catch (e, st) {
      lastError = e.toString();
      ApiLogger.error('cancelLeaveRequest write-state fallback failed', e, st);
    }

    throw Exception('Could not cancel leave request. $lastError');
  }

  String _toDateOnly(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// `YYYY-MM-DD HH:MM:SS`, the only format Odoo's `_get_unusual_days` parses.
  ///
  /// It does a bare `datetime.strptime(date_from, '%Y-%m-%d %H:%M:%S')`, so a
  /// date-only string raises "time data '2026-07-27' does not match format".
  String _toDateTime(DateTime d, {required bool endOfDay}) {
    final time = endOfDay ? '23:59:59' : '00:00:00';
    return '${_toDateOnly(d)} $time';
  }

  /// Whether [uid] belongs to any of [xmlIds], via `res.users.has_group`.
  ///
  /// Returns null when the server answered none of the calls, so the caller
  /// can fall back to reading the group field directly. A single group that
  /// doesn't exist (its module isn't installed) counts as "not a member"
  /// rather than a reason to abandon the whole check.
  Future<bool?> _hasAnyGroup(int uid, Set<String> xmlIds) async {
    var anySucceeded = false;
    for (final xmlId in xmlIds) {
      try {
        final result = await _client.callKw({
          'model': 'res.users',
          'method': 'has_group',
          'args': [
            [uid],
            xmlId,
          ],
          'kwargs': {},
        });
        anySucceeded = true;
        if (result == true) return true;
      } catch (e) {
        ApiLogger.info('has_group($xmlId) unavailable: $e');
      }
    }
    return anySucceeded ? false : null;
  }

  /// Reads the user's group ids, tolerating the Odoo 19 field rename.
  Future<List<int>> _readUserGroupIds(int uid) async {
    // `group_ids` is Odoo 19+; `groups_id` is 18 and earlier.
    for (final field in const ['group_ids', 'groups_id']) {
      try {
        final users = await _client.callKw({
          'model': 'res.users',
          'method': 'search_read',
          'args': [
            [
              ['id', '=', uid],
            ],
          ],
          'kwargs': {
            'fields': [field],
            'limit': 1,
          },
        });
        if (users is! List || users.isEmpty) continue;
        final row = Map<String, dynamic>.from(users.first as Map);
        final raw = row[field];
        if (raw is List) return raw.whereType<int>().toList();
      } catch (e) {
        ApiLogger.info('res.users.$field unavailable: $e');
      }
    }
    return [];
  }

  /// Every employee under [managerEmployeeId] in the manager hierarchy
  /// (`hr.employee.parent_id`), including indirect reports, excluding the
  /// manager themselves. Empty when nobody reports to them.
  ///
  /// This is what decides — and scopes — Approvals for employee-mode logins,
  /// where there is no res.users account to check groups on.
  Future<List<int>> fetchManagedEmployeeIds(int managerEmployeeId) async {
    // child_of walks parent_id recursively; plain parent_id is the fallback
    // for servers where the hierarchy operator misbehaves.
    final domains = [
      [
        ['id', 'child_of', managerEmployeeId],
      ],
      [
        ['parent_id', '=', managerEmployeeId],
      ],
    ];

    for (final domain in domains) {
      try {
        final result = await _client.callKw({
          'model': 'hr.employee',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': ['id'],
            'limit': 1000,
          },
        });
        if (result is! List) continue;
        final ids = [
          for (final raw in result)
            if ((raw as Map)['id'] is int && raw['id'] != managerEmployeeId)
              raw['id'] as int,
        ];
        ApiLogger.info(
          'fetchManagedEmployeeIds manager=$managerEmployeeId count=${ids.length}',
        );
        return ids;
      } catch (e, st) {
        ApiLogger.error(
          'fetchManagedEmployeeIds domain=$domain manager=$managerEmployeeId',
          e,
          st,
        );
      }
    }
    return [];
  }

  /// Employees directly managed by [userId] — backs the "My Team" filter,
  /// same relation Odoo's filter uses (employee_id.parent_id.user_id).
  Future<List<int>> fetchTeamEmployeeIds(int userId) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['parent_id.user_id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': ['id'],
          'limit': 500,
        },
      });
      if (result is! List) return [];
      return [
        for (final raw in result)
          if ((raw as Map)['id'] is int) raw['id'] as int,
      ];
    } catch (e, st) {
      ApiLogger.error('fetchTeamEmployeeIds userId=$userId', e, st);
      return [];
    }
  }

  /// Employees in the current user's department (including sub-departments) —
  /// backs the "My Department" filter.
  Future<List<int>> fetchDepartmentEmployeeIds({
    int? userId,
    int? employeeId,
  }) async {
    try {
      final domain = employeeId != null
          ? [
              ['id', '=', employeeId],
            ]
          : [
              ['user_id', '=', userId],
            ];
      final me = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['department_id'],
          'limit': 1,
        },
      });
      if (me is! List || me.isEmpty) return [];
      final deptId = _m2oId((me.first as Map)['department_id']);
      if (deptId == null) return [];

      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['department_id', 'child_of', deptId],
          ],
        ],
        'kwargs': {
          'fields': ['id'],
          'limit': 1000,
        },
      });
      if (result is! List) return [];
      return [
        for (final raw in result)
          if ((raw as Map)['id'] is int) raw['id'] as int,
      ];
    } catch (e, st) {
      ApiLogger.error(
        'fetchDepartmentEmployeeIds userId=$userId employeeId=$employeeId',
        e,
        st,
      );
      return [];
    }
  }

  Future<bool> hasApprovalAccess() async {
    ApiLogger.info('--- LeaveRepository.hasApprovalAccess ---');
    // All Time Off access levels that can approve requests:
    // - Officer ("Manage All Requests", group_hr_holidays_user)
    // - Administrator (group_hr_holidays_manager)
    // - Responsible/team approver (group_hr_holidays_responsible)
    // - Settings admins (base.group_system)
    const approverXmlIds = {
      'hr_holidays.group_hr_holidays_manager',
      'hr_holidays.group_hr_holidays_user',
      'hr_holidays.group_hr_holidays_responsible',
      'base.group_system',
    };

    try {
      final session =
          await _client.callRPC('/web/session/get_session_info', 'call', {});
      final uid = (session is Map ? session['uid'] : null) as int?;
      ApiLogger.info('hasApprovalAccess session uid=$uid');
      if (uid == null || uid <= 0) {
        ApiLogger.info('hasApprovalAccess => false (invalid uid)');
        return false;
      }

      // Preferred path: `has_group` takes the XML id directly, so it works on
      // every Odoo version and avoids touching the res.users group field —
      // which Odoo 19 renamed from `groups_id` to `group_ids`. Reading the old
      // name there raised "Invalid field 'groups_id' on 'res.users'" and left
      // every v19 user without approvals access.
      final viaHasGroup = await _hasAnyGroup(uid, approverXmlIds);
      if (viaHasGroup == true) {
        ApiLogger.info('hasApprovalAccess => true (has_group)');
        return true;
      }
      if (viaHasGroup == false) {
        // Not in any approver group — a team leader can still be an
        // approver via employees' "Time Off Approver" field.
        final teamApprover = await _isTeamLeaveApprover(uid);
        ApiLogger.info(
          'hasApprovalAccess => $teamApprover (leave_manager fallback)',
        );
        return teamApprover;
      }

      final groupIds = await _readUserGroupIds(uid);
      ApiLogger.json('hasApprovalAccess groupIds', groupIds);
      if (groupIds.isEmpty) {
        final teamApprover = await _isTeamLeaveApprover(uid);
        ApiLogger.info(
          'hasApprovalAccess => $teamApprover (no groups, leave_manager fallback)',
        );
        return teamApprover;
      }

      final groupMeta = await _client.callKw({
        'model': 'ir.model.data',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'res.groups'],
            ['res_id', 'in', groupIds],
            ['module', 'in', ['hr_holidays', 'base']],
          ],
        ],
        'kwargs': {
          'fields': ['module', 'name', 'res_id'],
          'limit': 200,
        },
      });
      if (groupMeta is! List) {
        ApiLogger.info('hasApprovalAccess => false (group metadata not list)');
        return false;
      }

      final userXmlIds = <String>{};
      for (final raw in groupMeta) {
        final row = Map<String, dynamic>.from(raw as Map);
        final module = row['module']?.toString() ?? '';
        final name = row['name']?.toString() ?? '';
        if (module.isEmpty || name.isEmpty) continue;
        userXmlIds.add('$module.$name');
      }
      ApiLogger.json('hasApprovalAccess groupXmlIds', userXmlIds.toList());

      final hasAccess = userXmlIds.any(approverXmlIds.contains);
      if (hasAccess) {
        ApiLogger.info('hasApprovalAccess => true (group metadata)');
        return true;
      }

      final teamApprover = await _isTeamLeaveApprover(uid);
      ApiLogger.info(
        'hasApprovalAccess => $teamApprover (metadata miss, leave_manager fallback)',
      );
      return teamApprover;
    } catch (e, st) {
      ApiLogger.error('hasApprovalAccess failed', e, st);
    }

    return false;
  }

  /// Whether any employee has [uid] set as their "Time Off Approver"
  /// (`hr.employee.leave_manager_id`). Odoo normally auto-adds such users to
  /// the responsible group, but databases exist where that didn't happen —
  /// this catches those approvers so the Approvals tab still shows for them.
  Future<bool> _isTeamLeaveApprover(int uid) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [
          [
            ['leave_manager_id', '=', uid],
          ],
        ],
        'kwargs': {},
      });
      return result is int && result > 0;
    } catch (e) {
      ApiLogger.info('_isTeamLeaveApprover unavailable uid=$uid: $e');
      return false;
    }
  }
}

class _LeaveTypeMeta {
  const _LeaveTypeMeta({
    required this.id,
    required this.name,
    required this.requiresAllocation,
    this.requestUnit = LeaveRequestUnit.day,
    this.supportsDocument = false,
  });

  final int id;
  final String name;
  final bool requiresAllocation;
  final LeaveRequestUnit requestUnit;
  final bool supportsDocument;
}

class _EmployeeHolidayContext {
  const _EmployeeHolidayContext({
    this.calendarId,
    this.companyId,
    this.companyIds = const [],
    this.departmentId,
  });

  final int? calendarId;
  final int? companyId;
  final List<int> companyIds;
  final int? departmentId;
}
