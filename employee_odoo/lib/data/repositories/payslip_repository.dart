import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/payslip_record.dart';
import '../../core/utils/api_logger.dart';

class PayslipModuleUnavailable implements Exception {}

class PayslipDownloadException implements Exception {
  final String message;
  PayslipDownloadException(this.message);
  @override
  String toString() => message;
}

class PayslipRepository {
  final OdooClient _client;
  PayslipRepository(this._client);

  // Without this, a slow/unresponsive server (common on runbot test
  // instances) leaves the await hanging forever — no exception, nothing
  // to log, and the UI stuck on a spinner indefinitely. Every network
  // call below is wrapped with this so a stuck request always becomes a
  // visible, loggable failure instead of silence.
  static const _requestTimeout = Duration(seconds: 20);

  // Only payslips that have actually been validated/confirmed should ever
  // reach an employee's device — draft and waiting payslips are excluded.
  static const _validatedStates = ['done', 'paid'];

  bool _netWageSupported = true;
  bool _structSupported = true;

  List<String> get _fields {
    final fields = ['id', 'name', 'number', 'date_from', 'date_to', 'state', 'employee_id'];
    if (_structSupported) fields.add('struct_id');
    if (_netWageSupported) fields.add('net_wage');
    return fields;
  }

  bool _isMissingModelError(Object e) {
    final msg = e.toString();
    return msg.contains('hr.payslip') &&
        (msg.contains('KeyError') || msg.contains('404') || msg.contains('Not Found'));
  }

  /// Whether the logged-in user has HR Payroll manager/officer rights (or
  /// full Settings admin) and should therefore see every employee's
  /// validated payslips, not just their own. Uses the exact same
  /// group-detection technique as LeaveRepository.hasApprovalAccess.
// new
  Future<bool> hasAllPayslipsAccess({required int userId}) async {
    const managerXmlIds = {
      'hr_payroll.group_hr_payroll_manager',
      'hr_payroll.group_hr_payroll_user',
      'hr_payslip.group_hr_payslip_manager',
      'base.group_system',
    };

    try {
      final uid = userId;

      final users = await _client
          .callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [['id', '=', uid]],
        ],
        'kwargs': {'fields': ['groups_id'], 'limit': 1},
      })
          .timeout(const Duration(seconds: 20));
      if (users is! List || users.isEmpty) return false;

      final userRow = Map<String, dynamic>.from(users.first as Map);
      final rawGroups = userRow['groups_id'];
      final groupIds = (rawGroups is List) ? rawGroups.whereType<int>().toList() : <int>[];
      if (groupIds.isEmpty) return false;

      final groupMeta = await _client
          .callKw({
        'model': 'ir.model.data',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'res.groups'],
            ['res_id', 'in', groupIds],
            ['module', 'in', ['hr_payroll', 'hr_payslip', 'base']],
          ],
        ],
        'kwargs': {'fields': ['module', 'name', 'res_id'], 'limit': 200},
      })
          .timeout(const Duration(seconds: 20));
      if (groupMeta is! List) return false;

      final userXmlIds = <String>{};
      for (final raw in groupMeta) {
        final row = Map<String, dynamic>.from(raw as Map);
        final module = row['module']?.toString() ?? '';
        final name = row['name']?.toString() ?? '';
        if (module.isEmpty || name.isEmpty) continue;
        userXmlIds.add('$module.$name');
      }

      return userXmlIds.any(managerXmlIds.contains);
    } catch (e, st) {
      ApiLogger.error('PayslipRepository.hasAllPayslipsAccess failed', e, st);
      return false;
    }
  }

  /// Resolves the logged-in user's hr.employee id independently — doesn't
  /// rely on any other controller having already fetched and cached it.
  /// Used as a fallback when HomeController's own employee lookup hasn't
  /// completed yet, or failed silently for this account (seen on some
  /// demo/Runbot servers where the user record isn't linked to an
  /// hr.employee the way it is on a normal production database).
// new
  Future<int?> fetchCurrentEmployeeId({required int userId}) async {
    try {
      final uid = userId;

      final result = await _client
          .callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [['user_id', '=', uid]],
        ],
        'kwargs': {'fields': ['id'], 'limit': 1},
      })
          .timeout(_requestTimeout);

      if (result is! List || result.isEmpty) {
        ApiLogger.error('PayslipRepository.fetchCurrentEmployeeId: no hr.employee linked to uid=$uid — this Odoo user has no employee record');
        return null;
      }

      final id = (result.first as Map)['id'] as int?;
      ApiLogger.info('PayslipRepository.fetchCurrentEmployeeId: resolved employeeId=$id for uid=$uid');
      return id;
    } catch (e, st) {
      ApiLogger.error('PayslipRepository.fetchCurrentEmployeeId failed', e, st);
      return null;
    }
  }

// new
  Future<List<PayslipRecord>> fetchMine(int employeeId, {List<int>? allowedCompanyIds}) async {
    return _fetch(
      [
        ['employee_id', '=', employeeId],
        ['state', 'in', _validatedStates],
      ],
      allowedCompanyIds: allowedCompanyIds,
    );
  }

  /// For payroll managers/admins — every employee's validated payslips,
  /// not just the logged-in user's own.
  Future<List<PayslipRecord>> fetchAll({List<int>? allowedCompanyIds}) async {
    return _fetch(
      [
        ['state', 'in', _validatedStates],
      ],
      allowedCompanyIds: allowedCompanyIds,
    );
  }

  Future<List<PayslipRecord>> _fetch(List<dynamic> domain, {List<int>? allowedCompanyIds}) async {
    ApiLogger.info('PayslipRepository._fetch: requesting domain=$domain allowedCompanyIds=$allowedCompanyIds');
    try {
      // Without this, search_read runs with the user's FULL company access
      // (every company they can see), not just the one currently selected
      // in the app/web company switcher — causing payslips from other
      // companies to appear here that the web UI doesn't show.
      final kwargs = <String, dynamic>{'fields': _fields, 'order': 'date_from desc, id desc'};
      if (allowedCompanyIds != null && allowedCompanyIds.isNotEmpty) {
        kwargs['context'] = {'allowed_company_ids': allowedCompanyIds};
      }
      final result = await _client
          .callKw({
        'model': 'hr.payslip',
        'method': 'search_read',
        'args': [domain],
        'kwargs': kwargs,
      })
          .timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('Timed out waiting for hr.payslip search_read response'),
      );
      ApiLogger.info('PayslipRepository._fetch: got ${(result is List) ? result.length : 0} rows');
      if (result is! List) return [];
      return result
          .map((e) => PayslipRecord.fromOdoo(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      if (_isMissingModelError(e)) throw PayslipModuleUnavailable();
      final msg = e.toString();
      if (_netWageSupported && msg.contains('net_wage')) {
        _netWageSupported = false;
        return _fetch(domain, allowedCompanyIds: allowedCompanyIds);
      }
      if (_structSupported && msg.contains('struct_id')) {
        _structSupported = false;
        return _fetch(domain, allowedCompanyIds: allowedCompanyIds);
      }
      ApiLogger.error('PayslipRepository._fetch failed', e, st);
      return [];
    }
  }

  /// Downloads the payslip PDF the same way Odoo's own "Print" button does —
  /// via the report controller, authenticated with the existing session
  /// cookie. (The RPC method behind report rendering is often private/
  /// underscore-prefixed in modern Odoo and blocked from external calls,
  /// so we go through the same HTTP endpoint the browser uses instead.)
  ///
  /// Tries multiple report XML IDs: since Odoo 15, the community payroll
  /// addon is named 'hr_payroll' (report id 'hr_payroll.action_report_payslip'),
  /// not the older 'hr_payslip.action_report_payslip'. The underlying
  /// model is still 'hr.payslip' either way — only the report's external
  /// ID prefix changed.
  static const _reportCandidates = [
    'hr_payroll.action_report_payslip',
    'hr_payslip.action_report_payslip',
  ];

  Future<List<int>> downloadPdf({
    required String baseUrl,
    required String sessionId,
    required int payslipId,
  }) async {
    final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    Object? lastError;

    for (final reportName in _reportCandidates) {
      final uri = Uri.parse('$cleanBase/report/pdf/$reportName/$payslipId');
      ApiLogger.info('PayslipRepository.downloadPdf: requesting $uri');
      try {
        final response = await http
            .get(
          uri,
          headers: {'Cookie': 'session_id=$sessionId'},
        )
            .timeout(
          const Duration(seconds: 25),
          onTimeout: () => throw PayslipDownloadException(
            'The server took too long to respond. This can happen on slow or shared test servers (e.g. Runbot) — please try again.',
          ),
        );
        ApiLogger.info('PayslipRepository.downloadPdf: $reportName responded status=${response.statusCode}');

        final contentType = response.headers['content-type'] ?? '';
        if (response.statusCode == 200 && contentType.contains('pdf')) {
          return response.bodyBytes;
        }

        final preview = response.body.length > 300 ? response.body.substring(0, 300) : response.body;
        ApiLogger.error(
          'PayslipRepository.downloadPdf: $reportName returned status=${response.statusCode} content-type=$contentType body="$preview"',
          null,
          null,
        );
        lastError = 'status=${response.statusCode} content-type=$contentType';
      } catch (e, st) {
        ApiLogger.error('PayslipRepository.downloadPdf request failed for $reportName', e, st);
        lastError = e;
      }
    }

    final expired = lastError.toString().contains('web/login') ||
        lastError.toString().contains('303') ||
        lastError.toString().contains('302');

    throw PayslipDownloadException(
      expired
          ? 'Your session has expired. Please log out and log in again.'
          : 'Could not generate this payslip PDF. Please check with your Odoo administrator that the Payroll report is configured correctly.',
    );
  }
}