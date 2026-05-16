class ActivityLog {
  final String id;
  final String? boutiqueId;
  final String? userId;
  final String userName;
  final String action;
  final String status;
  final String? ipAddress;
  final String? deviceInfo;
  final String? sessionId;
  final String? details;
  final String? metadata;
  final String? createdAt;

  ActivityLog({
    required this.id, this.boutiqueId, this.userId, required this.userName,
    required this.action, this.status = 'SUCCESS', this.ipAddress, this.deviceInfo,
    this.sessionId, this.details, this.metadata, this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
    id: json['id']?.toString() ?? '',
    boutiqueId: json['boutiqueId']?.toString(),
    userId: json['userId']?.toString(),
    userName: json['userName'] ?? '',
    action: json['action'] ?? '',
    status: json['status'] ?? 'SUCCESS',
    ipAddress: json['ipAddress'],
    deviceInfo: json['deviceInfo'],
    sessionId: json['sessionId']?.toString(),
    details: json['details'],
    metadata: json['metadata'],
    createdAt: json['createdAt'],
  );

  String get actionLabel {
    switch (action) {
      case 'CONNEXION_CAISSE_REUSSIE': return 'Connexion caisse réussie';
      case 'CONNEXION_CAISSE_ECHOUEE': return 'Connexion caisse échouée';
      case 'DECONNEXION_CAISSE': return 'Déconnexion caisse';
      case 'OUVERTURE_CAISSE': return 'Ouverture caisse';
      case 'FERMETURE_CAISSE': return 'Fermeture caisse';
      case 'CREATION_COMMANDE': return 'Création commande';
      case 'ANNULATION_COMMANDE': return 'Annulation commande';
      case 'MODIFICATION_UTILISATEUR': return 'Modification utilisateur';
      case 'RESET_STATISTIQUES': return 'Reset statistiques';
      case 'SESSION_EXPIREE': return 'Session expirée';
      case 'ORDER_STATUS_CHANGED': return 'Statut commande modifié';
      case 'LOGIN': return 'Connexion';
      case 'LOGIN_FAILED': return 'Échec connexion';
      case 'LOGOUT': return 'Déconnexion';
      case 'ORDER_CREATED': return 'Nouvelle commande';
      default: return action;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'SUCCESS': return 'Succès';
      case 'FAILED': return 'Échec';
      case 'EXPIRED': return 'Expiré';
      default: return status;
    }
  }
}
