import '../core/url_utils.dart';

class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? role;
  final String? tenantId;
  final String? language;
  final String? avatarUrl;
  final String? authProvider;
  final String? providerId;

  User({required this.id, required this.fullName, required this.email, this.phone, this.role, this.tenantId, this.language, this.avatarUrl, this.authProvider, this.providerId});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'].toString(),
    fullName: json['fullName'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'],
    role: json['role'],
    tenantId: json['tenantId']?.toString(),
    language: json['language'],
    avatarUrl: normalizeRemoteUrl(json['avatarUrl']),
    authProvider: json['authProvider'],
    providerId: json['providerId'],
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
    String? authProvider,
    String? providerId,
  }) => User(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    tenantId: tenantId ?? this.tenantId,
    language: language ?? this.language,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    authProvider: authProvider ?? this.authProvider,
    providerId: providerId ?? this.providerId,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'fullName': fullName, 'email': email,
    'phone': phone, 'role': role, 'tenantId': tenantId, 'language': language, 'avatarUrl': avatarUrl,
    'authProvider': authProvider, 'providerId': providerId,
  };
}
