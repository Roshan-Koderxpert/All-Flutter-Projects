enum EmployeePresence { checkedIn, checkedOut, unknown }


EmployeePresence _parsePresence(dynamic value) {
  if (value == 'checked_in') return EmployeePresence.checkedIn;
  if (value == 'checked_out') return EmployeePresence.checkedOut;
  return EmployeePresence.unknown;
}

class EmployeeDirectoryRecord {
  final int id;
  final String name;
  final String? jobTitle;
  final String? departmentName;
  final String? workEmail;
  final String? workPhone;
  final String? mobilePhone;
  final String? avatarBase64;
  final EmployeePresence presence;

  EmployeeDirectoryRecord({
    required this.id,
    required this.name,
    this.jobTitle,
    this.departmentName,
    this.workEmail,
    this.workPhone,
    this.mobilePhone,
    this.avatarBase64,
    this.presence = EmployeePresence.unknown,

  });

  factory EmployeeDirectoryRecord.fromOdoo(Map<String, dynamic> row) {
    String? _str(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

    return EmployeeDirectoryRecord(
      id: row['id'] as int,
      name: row['name'] is String ? row['name'] as String : '',
      jobTitle: _str(row['job_title']),
      departmentName: (row['department_id'] is List) ? row['department_id'][1] as String : null,
      workEmail: _str(row['work_email']),
      workPhone: _str(row['work_phone']),
      mobilePhone: _str(row['mobile_phone']),
      avatarBase64: _str(row['image_128']),
      presence: _parsePresence(row['attendance_state']),

    );
  }

  bool get hasContactInfo => workEmail != null || workPhone != null || mobilePhone != null;
}

