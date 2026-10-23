import 'package:odoo_rpc/odoo_rpc.dart';
import '../models/employee_directory_record.dart';
import '../../core/utils/api_logger.dart';

class EmployeeDirectoryRepository {
  final OdooClient _client;
  EmployeeDirectoryRepository(this._client);

// new
  static const _baseFields = [
    'id', 'name', 'job_title', 'department_id',
    'work_email', 'work_phone', 'mobile_phone', 'image_128',
  ];
  static const _presenceField = 'attendance_state';

  // Once we learn a server doesn't support attendance_state, stop asking for it.
  bool _presenceSupported = true;

  List<String> get _fields =>
      _presenceSupported ? [..._baseFields, _presenceField] : _baseFields;


  Future<List<EmployeeDirectoryRecord>> search(String query, {int limit = 1000, int offset = 0}) async {
    final domain = query.trim().isEmpty
        ? []
        : [
      '|', '|',
      ['name', 'ilike', query],
      ['job_title', 'ilike', query],
      ['department_id.name', 'ilike', query],
    ];
    try {
      final result = await _client.callKw({
        'model': 'hr.employee.public',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': _fields,
          'order': 'name asc',
          'limit': limit,
          'offset': offset,
        },
      });
      if (result is! List) return [];
      return result
          .map((e) => EmployeeDirectoryRecord.fromOdoo(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      if (_presenceSupported && e.toString().contains('attendance_state')) {
        // Field not available on this server (hr_attendance not installed) — retry without it.
        _presenceSupported = false;
        return search(query, limit: limit, offset: offset);
      }
      ApiLogger.error('EmployeeDirectoryRepository.search failed', e, st);
      return [];
    }
  }

  Future<EmployeeDirectoryRecord?> fetchById(int id) async {
    try {
      final result = await _client.callKw({
        'model': 'hr.employee.public',
        'method': 'search_read',
        'args': [[['id', '=', id]]],
        'kwargs': {'fields': _fields, 'limit': 1},
      });
      if (result is! List || result.isEmpty) return null;
      return EmployeeDirectoryRecord.fromOdoo(Map<String, dynamic>.from(result.first as Map));
    } catch (e, st) {
      if (_presenceSupported && e.toString().contains('attendance_state')) {
        _presenceSupported = false;
        return fetchById(id);
      }
      ApiLogger.error('EmployeeDirectoryRepository.fetchById id=$id failed', e, st);
      return null;
    }
  }
}