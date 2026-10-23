class UserModel {
  final int uid;
  final String name;
  final String username;   // login field from Odoo
  final String db;
  final String? email;
  final String? lang;
  final String? tz;
  final bool isSystem;

  const UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.db,
    this.email,
    this.lang,
    this.tz,
    this.isSystem = false,
  });

  // Maps directly from Odoo /web/session/authenticate result
  factory UserModel.fromOdooSession(Map<String, dynamic> json) {
    final dynamic uidRaw = json['uid'];
    final int uid = uidRaw is int
        ? uidRaw
        : uidRaw is num
            ? uidRaw.toInt()
            : int.tryParse(uidRaw?.toString() ?? '') ?? 0;

    final username = json['username'] as String? ??
        json['login'] as String? ??
        '';

    return UserModel(
      uid:      uid,
      name:     json['name']?.toString() ?? '',
      username: username,
      db:       json['db']?.toString() ?? '',
      email:    json['partner_display_name']?.toString(),
      lang:     json['user_context'] is Map
          ? (json['user_context'] as Map)['lang']?.toString()
          : null,
      tz:       json['user_context'] is Map
          ? (json['user_context'] as Map)['tz']?.toString()
          : null,
      isSystem: json['is_system'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid':      uid,
    'name':     name,
    'username': username,
    'db':       db,
    'email':    email,
    'lang':     lang,
    'tz':       tz,
    'is_system':isSystem,
  };

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, username: $username, db: $db)';
}