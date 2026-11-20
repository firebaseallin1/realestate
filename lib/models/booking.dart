import 'package:flutter/material.dart';
import '../core/api/json.dart';
import 'site.dart';

/// BookingType: a plot alone, or a plot with construction by Kaira.
enum BookingType {
  withoutConstruction('Without Construction', 'Plot only', Icons.crop_square_rounded),
  withConstruction('With Construction', 'Plot + house construction', Icons.home_work_outlined);

  const BookingType(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

/// PaymentPart is what a payment is for. A booking without construction
/// has only the plot part; with construction it has both.
enum PaymentPart {
  plot('Plot Value', Icons.crop_square_rounded),
  construction('Construction Value', Icons.home_work_outlined);

  const PaymentPart(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// How the customer pays for a part: in full themselves, or with a loan.
enum PaymentMode {
  fullPayment('Full Payment', Icons.account_balance_wallet_outlined),
  loan('Bank Loan', Icons.account_balance_outlined);

  const PaymentMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum LoanStatus {
  applied('Applied'),
  sanctioned('Sanctioned'),
  partlyDisbursed('Partly Disbursed'),
  disbursed('Disbursed');

  const LoanStatus(this.label);

  final String label;

  /// Set by hand. The others follow the bank's loan disbursement payments.
  static const manual = [applied, sanctioned];

  bool get isManual => manual.contains(this);
}

/// LoanDetails for a part paid with a bank loan.
class LoanDetails {
  final String bankName;
  final double amount;
  final String reference;
  final LoanStatus status;

  const LoanDetails({
    required this.bankName,
    required this.amount,
    this.reference = '',
    this.status = LoanStatus.applied,
  });

  factory LoanDetails.fromJson(Map<String, dynamic> json) => LoanDetails(
        bankName: json['bankName'] as String,
        amount: fromPaise(json['amountPaise'] as num),
        reference: json['reference'] as String? ?? '',
        status: LoanStatus.values.byName(json['status'] as String),
      );

  LoanDetails copyWith({LoanStatus? status}) =>
      LoanDetails(bankName: bankName, amount: amount, reference: reference, status: status ?? this.status);

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'amountPaise': toPaise(amount),
        'reference': reference,
        'status': status.name,
      };
}

/// PaymentPlan is one part's value and how it will be paid.
class PaymentPlan {
  final PaymentPart part;
  final double value;
  final PaymentMode mode;
  final LoanDetails? loan;

  const PaymentPlan({
    required this.part,
    required this.value,
    required this.mode,
    this.loan,
  });

  factory PaymentPlan.fromJson(Map<String, dynamic> json) => PaymentPlan(
        part: PaymentPart.values.byName(json['part'] as String),
        value: fromPaise(json['valuePaise'] as num),
        mode: PaymentMode.values.byName(json['mode'] as String),
        loan: json['loan'] == null ? null : LoanDetails.fromJson(json['loan'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'part': part.name,
        'valuePaise': toPaise(value),
        'mode': mode.name,
        if (loan != null) 'loan': loan!.toJson(),
      };

  PaymentPlan withLoan(LoanDetails loan) => PaymentPlan(part: part, value: value, mode: mode, loan: loan);

  /// What the customer pays themselves, beyond the loan.
  double get ownContribution => value - (loan?.amount ?? 0);
}

enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  cheque('Cheque'),
  bankTransfer('Bank Transfer'),
  loanDisbursement('Loan Disbursement');

  const PaymentMethod(this.label);

  final String label;
}

/// PaymentEntry is one amount received against a part.
class PaymentEntry {
  final String id;
  final PaymentPart part;
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final String reference;

  const PaymentEntry({
    required this.id,
    required this.part,
    required this.amount,
    required this.date,
    required this.method,
    this.reference = '',
  });

  factory PaymentEntry.fromJson(Map<String, dynamic> json) => PaymentEntry(
        id: json['id'] as String,
        part: PaymentPart.values.byName(json['part'] as String),
        amount: fromPaise(json['amountPaise'] as num),
        date: dayFromJson(json['date'] as String),
        method: PaymentMethod.values.byName(json['method'] as String),
        reference: json['reference'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'part': part.name,
        'amountPaise': toPaise(amount),
        'date': dayToJson(date),
        'method': method.name,
        'reference': reference,
      };
}

/// BookingStatus: sales raise bookings, the Admin approves or rejects them.
enum BookingStatus {
  pending('Pending Approval', Color(0xFFC98A2E), Icons.hourglass_top_rounded),
  approved('Approved', Color(0xFF3F8F5A), Icons.verified_rounded),
  rejected('Rejected', Color(0xFFD9534F), Icons.cancel_outlined);

  const BookingStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class Customer {
  final String name;
  final String mobile;
  final String email;
  final String address;

  const Customer({
    required this.name,
    required this.mobile,
    this.email = '',
    this.address = '',
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        name: json['name'] as String,
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'mobile': mobile, 'email': email, 'address': address};
}

/// Booking is one plot booked for a customer, with its payment plans
/// (plot, and construction when chosen) and the payments received.
class Booking {
  final String id;
  final String siteId;
  final String siteName;
  final String plotNumber;

  /// Set when the plot was picked from the site's drawn layout.
  final String? plotId;
  final String? plotSize;
  final PlotFacing? facing;
  final Customer customer;
  final BookingType type;
  final List<PaymentPlan> plans;
  final List<PaymentEntry> payments;
  final BookingStatus status;
  final DateTime bookedOn;
  final String bookedBy;

  const Booking({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.plotNumber,
    this.plotId,
    this.plotSize,
    this.facing,
    required this.customer,
    required this.type,
    required this.plans,
    this.payments = const [],
    this.status = BookingStatus.pending,
    required this.bookedOn,
    required this.bookedBy,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        siteId: json['siteId'] as String,
        siteName: json['siteName'] as String,
        plotNumber: json['plotNumber'] as String,
        plotId: json['plotId'] as String?,
        plotSize: json['plotSize'] as String?,
        facing: json['facing'] == null ? null : PlotFacing.values.byName(json['facing'] as String),
        customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
        type: BookingType.values.byName(json['type'] as String),
        plans: [
          for (final plan in json['plans'] as List<dynamic>) PaymentPlan.fromJson(plan as Map<String, dynamic>),
        ],
        payments: [
          for (final payment in json['payments'] as List<dynamic>? ?? const [])
            PaymentEntry.fromJson(payment as Map<String, dynamic>),
        ],
        status: BookingStatus.values.byName(json['status'] as String),
        bookedOn: dayFromJson(json['bookedOn'] as String),
        bookedBy: json['bookedBy'] as String,
      );

  /// What can be corrected on an approved booking.
  Map<String, dynamic> toUpdateJson() => {
        'customer': customer.toJson(),
        'plans': [for (final plan in plans) plan.toJson()],
      };

  /// What the server needs to raise a booking. It adds the date and who booked.
  Map<String, dynamic> toCreateJson() => {
        'siteId': siteId,
        'plotId': plotId,
        'plotNumber': plotNumber,
        'plotSize': plotSize,
        'facing': facing?.name,
        'customer': customer.toJson(),
        'type': type.name,
        'plans': [for (final plan in plans) plan.toJson()],
        if (payments.isNotEmpty) 'initialPayments': [for (final payment in payments) payment.toJson()],
      };

  PaymentPlan? plan(PaymentPart part) {
    for (final plan in plans) {
      if (plan.part == part) return plan;
    }
    return null;
  }

  double get totalValue => plans.fold(0, (sum, p) => sum + p.value);

  double paidFor(PaymentPart part) =>
      payments.where((p) => p.part == part).fold(0, (sum, p) => sum + p.amount);

  double balanceFor(PaymentPart part) => (plan(part)?.value ?? 0) - paidFor(part);

  double get totalPaid => payments.fold(0, (sum, p) => sum + p.amount);

  double get balance => totalValue - totalPaid;

  /// Share of the total value paid, from 0.0 to 1.0.
  double get paidRatio => totalValue == 0 ? 0 : (totalPaid / totalValue).clamp(0, 1);

  bool get isFullyPaid => totalValue > 0 && balance <= 0;

  bool get hasLoan => plans.any((p) => p.mode == PaymentMode.loan);

  /// What the bank has paid so far towards [part]'s loan.
  double loanReceivedFor(PaymentPart part) => payments
      .where((p) => p.part == part && p.method == PaymentMethod.loanDisbursement)
      .fold(0, (sum, p) => sum + p.amount);

  /// The part of [part]'s loan the bank has still to pay.
  double loanToComeFor(PaymentPart part) => (plan(part)?.loan?.amount ?? 0) - loanReceivedFor(part);

  Booking copyWith({
    BookingStatus? status,
    Customer? customer,
    List<PaymentPlan>? plans,
    List<PaymentEntry>? payments,
  }) {
    return Booking(
      id: id,
      siteId: siteId,
      siteName: siteName,
      plotNumber: plotNumber,
      plotId: plotId,
      plotSize: plotSize,
      facing: facing,
      customer: customer ?? this.customer,
      type: type,
      plans: plans ?? this.plans,
      payments: payments ?? this.payments,
      status: status ?? this.status,
      bookedOn: bookedOn,
      bookedBy: bookedBy,
    );
  }
}
