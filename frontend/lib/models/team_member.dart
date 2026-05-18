class TeamMember {
  final String id;
  final String boutiqueId;
  final String? userId;
  final String? name;
  final String? invitedEmail;
  final String? userEmail;
  final String role;
  final String status;
  final String? invitedAt;
  final String? joinedAt;
  final String? lastActivityAt;
  final List<String> permissions;

  TeamMember({
    required this.id,
    required this.boutiqueId,
    this.userId,
    this.name,
    this.invitedEmail,
    this.userEmail,
    this.role = 'STAFF',
    this.status = 'PENDING',
    this.invitedAt,
    this.joinedAt,
    this.lastActivityAt,
    this.permissions = const [],
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      boutiqueId: json['boutiqueId'] as String,
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      invitedEmail: json['invitedEmail'] as String?,
      userEmail: json['userEmail'] as String?,
      role: json['role'] as String? ?? 'STAFF',
      status: json['status'] as String? ?? 'PENDING',
      invitedAt: json['invitedAt'] as String?,
      joinedAt: json['joinedAt'] as String?,
      lastActivityAt: json['lastActivityAt'] as String?,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  String get displayName => name ?? invitedEmail ?? 'Inconnu';
  String get displayEmail => userEmail ?? invitedEmail ?? '';
  bool get isActive => status == 'ACTIVE';
  bool get isPending => status == 'PENDING';
  bool get isDeactivated => status == 'DEACTIVATED';

  String get roleLabel {
    switch (role) {
      case 'ADMIN': return 'Administrateur';
      case 'MANAGER': return 'Manager';
      case 'STAFF': return 'Staff';
      case 'CAISSIER': return 'Caissier';
      default: return role;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'ACTIVE': return 'Actif';
      case 'PENDING': return 'En attente';
      case 'DEACTIVATED': return 'Desactive';
      default: return status;
    }
  }
}
