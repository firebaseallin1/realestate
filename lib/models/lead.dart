import 'package:flutter/material.dart';

import '../core/api/json.dart';
import 'booking.dart';

/// Where the enquiry came from.
enum LeadSource {
  walkIn('Walk-in', Icons.directions_walk_rounded),
  phoneCall('Phone Call', Icons.call_outlined),
  website('Website', Icons.language_rounded),
  referral('Referral', Icons.handshake_outlined),
  socialMedia('Social Media', Icons.share_outlined),
  advertisement('Advertisement', Icons.campaign_outlined),
  other('Other', Icons.more_horiz_rounded);

  const LeadSource(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Where a lead stands, from first enquiry to booked (won) or dropped (lost).
enum LeadStatus {
  newLead('New', Color(0xFF4A7FB5), Icons.fiber_new_outlined),
  contacted('Contacted', Color(0xFF6B7FA8), Icons.phone_callback_outlined),
  interested('Interested', Color(0xFFC98A2E), Icons.thumb_up_alt_outlined),
  siteVisit('Site Visit', Color(0xFF8A6BB5), Icons.place_outlined),
  negotiation('Negotiation', Color(0xFFB5743F), Icons.forum_outlined),
  won('Won', Color(0xFF3F8F5A), Icons.emoji_events_outlined),
  lost('Lost', Color(0xFFB54A4A), Icons.cancel_outlined);

  const LeadStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  /// Won and lost leads need no more follow-ups.
  bool get isClosed => this == won || this == lost;
}

/// How the lead was contacted.
enum FollowUpMode {
  call('Call', Icons.call_outlined),
  whatsApp('WhatsApp', Icons.chat_outlined),
  siteVisit('Site Visit', Icons.place_outlined),
  meeting('Office Meeting', Icons.groups_outlined),
  email('Email', Icons.mail_outline_rounded);

  const FollowUpMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One contact with a lead: what was discussed, where the lead stood
/// after it, and when to follow up next.
class FollowUp {
  final String id;
  final DateTime date;
  final FollowUpMode mode;
  final String note;
  final LeadStatus status;
  final DateTime? nextDate;
  final String by;

  const FollowUp({
    required this.id,
    required this.date,
    required this.mode,
    required this.note,
    required this.status,
    this.nextDate,
    this.by = '',
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) => FollowUp(
    id: json['id'] as String,
    date: dayFromJson(json['date'] as String),
    mode: FollowUpMode.values.byName(json['mode'] as String),
    note: json['note'] as String,
    status: LeadStatus.values.byName(json['status'] as String),
    nextDate: json['nextDate'] == null ? null : dayFromJson(json['nextDate'] as String),
    by: json['by'] as String? ?? '',
  );

  /// The server records who made the follow-up.
  Map<String, dynamic> toJson() => {
    'date': dayToJson(date),
    'mode': mode.name,
    'note': note,
    'status': status.name,
    'nextDate': nextDate == null ? null : dayToJson(nextDate!),
  };
}

/// Lead is someone enquiring about a plot, before they book: their
/// details, what they are looking for, and every follow-up with them.
class Lead {
  final String id;
  final String name;
  final String mobile;
  final String email;
  final String area;
  final LeadSource source;
  final String? siteId;
  final String siteName;

  /// Plot only, or plot with a house built.
  final BookingType? interest;
  final double? budget;
  final String notes;
  final LeadStatus status;
  final DateTime? nextFollowUp;

  /// The Sales Executive looking after the lead.
  final String ownerName;
  final DateTime createdAt;

  /// Oldest first.
  final List<FollowUp> followUps;

  /// Set once the lead has become a customer.
  final String? customerId;
  final DateTime? convertedAt;

  const Lead({
    required this.id,
    required this.name,
    required this.mobile,
    required this.source,
    required this.createdAt,
    this.email = '',
    this.area = '',
    this.siteId,
    this.siteName = '',
    this.interest,
    this.budget,
    this.notes = '',
    this.status = LeadStatus.newLead,
    this.nextFollowUp,
    this.ownerName = '',
    this.followUps = const [],
    this.customerId,
    this.convertedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) => Lead(
    id: json['id'] as String,
    name: json['name'] as String,
    mobile: json['mobile'] as String,
    email: json['email'] as String? ?? '',
    area: json['area'] as String? ?? '',
    source: LeadSource.values.byName(json['source'] as String),
    siteId: json['siteId'] as String?,
    siteName: json['siteName'] as String? ?? '',
    interest: json['interest'] == null ? null : BookingType.values.byName(json['interest'] as String),
    budget: json['budgetPaise'] == null ? null : fromPaise(json['budgetPaise'] as num),
    notes: json['notes'] as String? ?? '',
    status: LeadStatus.values.byName(json['status'] as String),
    nextFollowUp: json['nextFollowUp'] == null ? null : dayFromJson(json['nextFollowUp'] as String),
    ownerName: json['ownerName'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    customerId: json['customerId'] as String?,
    convertedAt: json['convertedAt'] == null ? null : DateTime.parse(json['convertedAt'] as String).toLocal(),
    followUps: [
      for (final row in json['followUps'] as List<dynamic>? ?? const []) FollowUp.fromJson(row as Map<String, dynamic>),
    ],
  );

  /// The basic details. The server sets the owner, status and follow-ups.
  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'email': email,
    'area': area,
    'source': source.name,
    'siteId': siteId,
    'interest': interest?.name,
    'budgetPaise': budget == null ? null : toPaise(budget!),
    'notes': notes,
    'nextFollowUp': nextFollowUp == null ? null : dayToJson(nextFollowUp!),
  };

  /// The last 10 digits: "+91 98480-12345" and "9848012345" are the same.
  static String mobileKey(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  }

  bool get isConverted => customerId != null;

  /// This lead once it became customer [id]: Won, with nothing to follow up.
  Lead convertedTo(String id, DateTime at) => Lead(
    id: this.id,
    name: name,
    mobile: mobile,
    email: email,
    area: area,
    source: source,
    siteId: siteId,
    siteName: siteName,
    interest: interest,
    budget: budget,
    notes: notes,
    status: LeadStatus.won,
    ownerName: ownerName,
    createdAt: createdAt,
    followUps: followUps,
    customerId: id,
    convertedAt: at,
  );

  FollowUp? get lastFollowUp => followUps.isEmpty ? null : followUps.last;

  /// The next follow-up is before [today].
  bool isOverdue(DateTime today) => !status.isClosed && nextFollowUp != null && nextFollowUp!.isBefore(_day(today));

  /// The next follow-up is [today].
  bool isDueOn(DateTime today) => !status.isClosed && nextFollowUp != null && nextFollowUp == _day(today);

  static DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  /// [details] with this lead's id, owner, status and follow-ups: an edit.
  Lead withDetails(Lead details) => Lead(
    id: id,
    name: details.name,
    mobile: details.mobile,
    email: details.email,
    area: details.area,
    source: details.source,
    siteId: details.siteId,
    siteName: details.siteName,
    interest: details.interest,
    budget: details.budget,
    notes: details.notes,
    status: status,
    nextFollowUp: status.isClosed ? null : details.nextFollowUp,
    ownerName: ownerName,
    createdAt: createdAt,
    customerId: customerId,
    convertedAt: convertedAt,
    followUps: followUps,
  );

  /// This lead after [followUp]: its status and next date.
  Lead withFollowUp(FollowUp followUp) => Lead(
    id: id,
    name: name,
    mobile: mobile,
    email: email,
    area: area,
    source: source,
    siteId: siteId,
    siteName: siteName,
    interest: interest,
    budget: budget,
    notes: notes,
    status: followUp.status,
    nextFollowUp: followUp.status.isClosed ? null : followUp.nextDate,
    ownerName: ownerName,
    createdAt: createdAt,
    customerId: customerId,
    convertedAt: convertedAt,
    followUps: [...followUps, followUp],
  );
}
