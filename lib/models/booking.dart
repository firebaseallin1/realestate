import 'package:flutter/material.dart';
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
  disbursed('Disbursed');

  const LoanStatus(this.label);

  final String label;
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

  Booking copyWith({
    BookingStatus? status,
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
      customer: customer,
      type: type,
      plans: plans,
      payments: payments ?? this.payments,
      status: status ?? this.status,
      bookedOn: bookedOn,
      bookedBy: bookedBy,
    );
  }
}
