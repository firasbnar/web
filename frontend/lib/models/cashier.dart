class Cashier {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final bool isSuspended;
  final String? phone;
  final double totalVentes;
  final int commandesCount;
  final bool online;
  final String? lastActivity;

  Cashier({
    required this.id, required this.fullName, required this.email, required this.role,
    required this.isActive, required this.isSuspended, this.phone,
    required this.totalVentes, required this.commandesCount, required this.online,
    this.lastActivity,
  });

  factory Cashier.fromJson(Map<String, dynamic> json) => Cashier(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName'] ?? '',
    email: json['email'] ?? '',
    role: json['role'] ?? 'STAFF',
    isActive: json['active'] ?? json['isActive'] ?? true,
    isSuspended: json['suspended'] ?? json['isSuspended'] ?? false,
    phone: json['phone'],
    totalVentes: (json['totalVentes'] ?? 0).toDouble(),
    commandesCount: (json['commandesCount'] ?? 0).toInt(),
    online: json['online'] ?? false,
    lastActivity: json['lastActivity'],
  );
}
