class Plan {
  final int id;
  final String name;
  final double priceDt;
  final int durationDays;
  final int maxProducts;
  final double commissionPercent;
  final String? features;

  Plan({required this.id, required this.name, required this.priceDt, required this.durationDays, this.maxProducts = 250, this.commissionPercent = 0, this.features});

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    priceDt: (json['priceDt'] ?? 0).toDouble(),
    durationDays: json['durationDays'] ?? 0,
    maxProducts: json['maxProducts'] ?? 250,
    commissionPercent: (json['commissionPercent'] ?? 0).toDouble(),
    features: json['features'],
  );
}

class Subscription {
  final String id;
  final int? planId;
  final String? planName;
  final String status;
  final String? startedAt;
  final String? expiresAt;
  final String? paymentMethod;
  final String? paymentRef;

  Subscription({required this.id, this.planId, this.planName, this.status = 'ACTIVE', this.startedAt, this.expiresAt, this.paymentMethod, this.paymentRef});

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'].toString(),
    planId: json['planId'],
    planName: json['planName'],
    status: json['status'] ?? 'ACTIVE',
    startedAt: json['startedAt'],
    expiresAt: json['expiresAt'],
    paymentMethod: json['paymentMethod'],
    paymentRef: json['paymentRef'],
  );
}
