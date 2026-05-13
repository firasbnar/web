class Customer {
  final String id;
  final String? boutiqueId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? governorate;
  final String? notes;
  final String? createdAt;

  Customer({
    required this.id, this.boutiqueId, required this.fullName,
    this.email, this.phone, this.address, this.city,
    this.governorate, this.notes, this.createdAt,
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
    notes: json['notes'],
    createdAt: json['createdAt'],
  );
}
