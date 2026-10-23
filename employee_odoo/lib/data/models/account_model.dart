class AccountModel {
  static const Object _unset = Object();

  /// Login mode values, persisted with the account.
  static const String modeUser = 'user';
  static const String modeEmployee = 'employee';

  /// Normalizes server URL for duplicate detection (case, trailing slashes).
  static String normalizeUrl(String url) {
    var normalized = url.trim().toLowerCase();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Same Odoo server + database + login + mode — one saved account per identity.
  ///
  /// Mode is part of the identity so a person who has both a full-user login
  /// and an employee login with the same email keeps two distinct accounts.
  static bool isSameIdentity(AccountModel a, AccountModel b) {
    return a.loginMode == b.loginMode &&
        a.matchesCredentials(
          url: b.url,
          database: b.database,
          username: b.username,
        );
  }

  bool matchesCredentials({
    required String url,
    required String database,
    required String username,
  }) {
    return normalizeUrl(this.url) == normalizeUrl(url) &&
        this.database.toLowerCase() == database.toLowerCase() &&
        this.username.toLowerCase() == username.toLowerCase();
  }

  AccountModel({
    required this.id,
    required this.url,
    required this.database,
    required this.username,
    required this.password,
    required this.userId,
    this.sessionId,
    this.isActive = false,
    this.name,
    this.email,
    this.image1920,
    this.lastLogin,
    this.loginMode = modeUser,
    this.employeeId,
  });

  final String id;
  final String url;
  final String database;
  final String username;
  final String password;
  final int userId;
  final String? sessionId;
  final bool isActive;
  final String? name;
  final String? email;
  final String? image1920;
  final DateTime? lastLogin;

  /// Whether this account signs in as a full Odoo user or as an employee
  /// (self-service, running on the shared predefined user). See [modeUser] /
  /// [modeEmployee].
  final String loginMode;

  /// The `hr.employee` id this account is scoped to. Set for employee-mode
  /// accounts (where the session's user is the shared app user, not the
  /// employee). Null for user-mode accounts, which resolve their employee from
  /// the logged-in user.
  final int? employeeId;

  bool get isEmployeeMode => loginMode == modeEmployee;

  bool get hasStoredSession =>
      sessionId != null && sessionId!.trim().isNotEmpty;

  bool get canSilentSignIn => hasStoredSession || password.isNotEmpty;

  AccountModel copyWith({
    String? id,
    String? url,
    String? database,
    String? username,
    Object? password = _unset,
    int? userId,
    Object? sessionId = _unset,
    bool? isActive,
    Object? name = _unset,
    Object? email = _unset,
    Object? image1920 = _unset,
    Object? lastLogin = _unset,
    String? loginMode,
    Object? employeeId = _unset,
  }) {
    return AccountModel(
      id: id ?? this.id,
      url: url ?? this.url,
      database: database ?? this.database,
      username: username ?? this.username,
      password: identical(password, _unset)
          ? this.password
          : password as String,
      userId: userId ?? this.userId,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as String?,
      isActive: isActive ?? this.isActive,
      name: identical(name, _unset) ? this.name : name as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      image1920: identical(image1920, _unset)
          ? this.image1920
          : image1920 as String?,
      lastLogin: identical(lastLogin, _unset)
          ? this.lastLogin
          : lastLogin as DateTime?,
      loginMode: loginMode ?? this.loginMode,
      employeeId: identical(employeeId, _unset)
          ? this.employeeId
          : employeeId as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'database': database,
        'username': username,
        'password': password,
        'userId': userId,
        'sessionId': sessionId,
        'isActive': isActive,
        'name': name,
        'email': email,
        'image1920': image1920,
        'lastLogin': lastLogin?.toIso8601String(),
        'loginMode': loginMode,
        'employeeId': employeeId,
      };

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      url: json['url'] as String,
      database: json['database'] as String,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
      userId: json['userId'] as int,
      sessionId: json['sessionId'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      name: json['name'] as String?,
      email: json['email'] as String?,
      image1920: json['image1920'] as String?,
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'] as String)
          : null,
      loginMode: json['loginMode'] as String? ?? modeUser,
      employeeId: json['employeeId'] as int?,
    );
  }
}
