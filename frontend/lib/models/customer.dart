class Customer {
  final String id;
  final String? boutiqueId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? governorate;
  final String? postalCode;
  final String? country;
  final String? notes;
  final int totalOrders;
  final double totalSpent;
  final String? lastOrderDate;
  final String? createdAt;
  final String? updatedAt;

  Customer({
    required this.id,
    this.boutiqueId,
    required this.fullName,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.governorate,
    this.postalCode,
    this.country,
    this.notes,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.lastOrderDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'].toString(),
    boutiqueId: json['boutiqueId']?.toString(),
    fullName: json['fullName'] ?? '',
    email: json['email'],
    phone: json['phone'],
    address: json['address'],
    city: json['city'],
    governorate: json['governorate'],
    postalCode: json['postalCode'],
    country: json['country'],
    notes: json['notes'],
    totalOrders: json['totalOrders'] ?? 0,
    totalSpent: (json['totalSpent'] ?? 0).toDouble(),
    lastOrderDate: json['lastOrderDate'],
    createdAt: json['createdAt'],
    updatedAt: json['updatedAt'],
  );
}
