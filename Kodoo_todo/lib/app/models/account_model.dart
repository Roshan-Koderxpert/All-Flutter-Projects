class AccountModel {
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
  });

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
    'image_1920': image1920,
  };

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    // ✅ Handle Odoo's false value for image
    final imageValue = json['image_1920'];
    final String? imageString = (imageValue == false || imageValue == null)
        ? null
        : imageValue as String;

    return AccountModel(
      id: json['id'] as String,
      url: json['url'] as String,
      database: json['database'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      userId: json['userId'] as int,
      sessionId: json['sessionId'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      name: json['name'] as String?,
      email: json['email'] as String?,
      image1920: imageString,
    );
  }

  AccountModel copyWith({
    String? id,
    String? url,
    String? database,
    String? username,
    String? password,
    int? userId,
    String? sessionId,
    DateTime? lastLogin,
    bool? isActive,
    String? name,
    String? email,
    String? image1920,
  }) {
    return AccountModel(
      id: id ?? this.id,
      url: url ?? this.url,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      isActive: isActive ?? this.isActive,
      name: name ?? this.name,
      email: email ?? this.email,
      image1920: image1920 ?? this.image1920, // ✅ ADD THIS LINE!
    );
  }
}