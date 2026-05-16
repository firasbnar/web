class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? role;
  final String? tenantId;
  final String? language;
  final String? avatarUrl;

  User({required this.id, required this.fullName, required this.email, this.phone, this.role, this.tenantId, this.language, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'].toString(),
    fullName: json['fullName'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'],
    role: json['role'],
    tenantId: json['tenantId']?.toString(),
    language: json['language'],
    avatarUrl: json['avatarUrl'],
  );

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? tenantId,
    String? language,
    String? avatarUrl,
  }) => User(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    tenantId: tenantId ?? this.tenantId,
    language: language ?? this.language,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'fullName': fullName, 'email': email,
    'phone': phone, 'role': role, 'tenantId': tenantId, 'language': language, 'avatarUrl': avatarUrl,
  };
}
