class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? role;
  final String? language;
  final String? avatarUrl;

  User({required this.id, required this.fullName, required this.email, this.phone, this.role, this.language, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'].toString(),
    fullName: json['fullName'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'],
    role: json['role'],
    language: json['language'],
    avatarUrl: json['avatarUrl'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'fullName': fullName, 'email': email,
    'phone': phone, 'role': role, 'language': language, 'avatarUrl': avatarUrl,
  };
}
