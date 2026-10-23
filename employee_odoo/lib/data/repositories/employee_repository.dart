import 'package:odoo_rpc/odoo_rpc.dart';

import '../../core/utils/api_logger.dart';
import '../../core/utils/odoo_image.dart';

class ResolvedEmployee {
  ResolvedEmployee({
    required this.id,
    required this.name,
    this.jobTitle = '',
    this.departmentName = '',
    this.avatarBase64,
  });

  final int id;
  final String name;
  final String jobTitle;
  final String departmentName;
  final String? avatarBase64;
}

/// Resolves employee for the logged-in user (handles Odoo ACL on hr.employee).
class EmployeeRepository {
  EmployeeRepository(this._client);

  final OdooClient _client;

  static const _employeeFields = [
    'id',
    'name',
    'job_title',
    'department_id',
    'image_128',
    'user_id',
  ];

  Future<ResolvedEmployee?> resolveForUser(int userId) async {
    ApiLogger.info('--- EmployeeRepository.resolveForUser userId=$userId ---');

    // 1) Full hr.employee by user_id
    var emp = await _readEmployee(
      model: 'hr.employee',
      domain: [
        ['user_id', '=', userId],
      ],
    );
    if (emp != null) {
      ApiLogger.info('Resolved via hr.employee + user_id');
      return emp;
    }

    // 2) employee_id on res.users (works when hr.employee read is blocked by ACL)
    final userRow = await _client.callKw({
      'model': 'res.users',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', userId],
        ],
      ],
      'kwargs': {
        'fields': ['employee_id', 'name'],
        'limit': 1,
      },
    });

    ApiLogger.json('res.users', userRow);

    if (userRow is! List || userRow.isEmpty) {
      ApiLogger.error('res.users not found');
      return null;
    }

    final user = Map<String, dynamic>.from(userRow.first as Map);
    final empField = user['employee_id'];
    if (empField is! List || empField.isEmpty) {
      ApiLogger.error('res.users has no employee_id');
      return null;
    }

    final employeeId = empField[0] as int;
    final displayName =
        empField.length > 1 ? empField[1].toString() : user['name']?.toString() ?? '';

    ApiLogger.info('employee_id from user => $employeeId ($displayName)');

    // 3) Try hr.employee.public (portal / limited HR access)
    emp = await _readEmployee(
      model: 'hr.employee.public',
      domain: [
        ['id', '=', employeeId],
      ],
    );
    if (emp != null) {
      ApiLogger.info('Resolved via hr.employee.public');
      return emp;
    }

    // 4) Try hr.employee by id with active_test false
    emp = await _readEmployee(
      model: 'hr.employee',
      domain: [
        ['id', '=', employeeId],
      ],
      activeTest: false,
    );
    if (emp != null) {
      ApiLogger.info('Resolved via hr.employee by id');
      return emp;
    }

    // 5) Use id + name from user only — enough for attendance API
    ApiLogger.info(
      'Using employee_id=$employeeId from res.users only (hr.employee read denied)',
    );
    return ResolvedEmployee(
      id: employeeId,
      name: displayName.isNotEmpty ? displayName : 'Employee',
    );
  }

  Future<ResolvedEmployee?> _readEmployee({
    required String model,
    required List<dynamic> domain,
    bool activeTest = true,
  }) async {
    try {
      final result = await _client.callKw({
        'model': model,
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': _employeeFields,
          'limit': 1,
          'context': {'active_test': activeTest},
        },
      });

      ApiLogger.json('$model search_read', result);

      if (result is! List || result.isEmpty) return null;

      return _mapEmployee(Map<String, dynamic>.from(result.first as Map));
    } catch (e, st) {
      ApiLogger.error('$model read failed', e, st);
      return null;
    }
  }

  ResolvedEmployee _mapEmployee(Map<String, dynamic> emp) {
    var name = emp['name']?.toString() ?? '';
    if (name.isEmpty) name = 'Employee';

    var job = '';
    final jt = emp['job_title'];
    if (jt != false && jt != null) job = jt.toString();

    var dept = '';
    final d = emp['department_id'];
    if (d is List && d.length > 1) dept = d[1].toString();

    return ResolvedEmployee(
      id: emp['id'] as int,
      name: name,
      jobTitle: job,
      departmentName: dept,
      avatarBase64: OdooImage.sanitize(emp['image_128']),
    );
  }
}
