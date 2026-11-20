import 'lead.dart';

/// CustomerProfile is a buyer's own record, made when a lead is converted.
/// Bookings carry a copy of the customer's name and contact; the two are
/// matched on the mobile number.
class CustomerProfile {
  final String id;
  final String name;
  final String mobile;
  final String alternateMobile;
  final String email;
  final String address;
  final String occupation;
  final String notes;

  /// The lead this customer came from, and how that lead heard of us.
  final String? leadId;
  final LeadSource? source;

  /// Who converted them.
  final String ownerName;
  final DateTime createdAt;

  const CustomerProfile({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    required this.createdAt,
    this.alternateMobile = '',
    this.email = '',
    this.occupation = '',
    this.notes = '',
    this.leadId,
    this.source,
    this.ownerName = '',
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) => CustomerProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    mobile: json['mobile'] as String,
    alternateMobile: json['alternateMobile'] as String? ?? '',
    email: json['email'] as String? ?? '',
    address: json['address'] as String? ?? '',
    occupation: json['occupation'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    leadId: json['leadId'] as String?,
    source: json['source'] == null ? null : LeadSource.values.byName(json['source'] as String),
    ownerName: json['ownerName'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  /// The details sent when converting a lead. The server links the lead.
  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'alternateMobile': alternateMobile,
    'email': email,
    'address': address,
    'occupation': occupation,
    'notes': notes,
  };

  /// The last 10 digits, to match bookings with this customer.
  String get mobileKey => Lead.mobileKey(mobile);
}
