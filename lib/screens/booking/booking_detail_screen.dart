import 'package:flutter/material.dart';
import '../../core/controllers/booking_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/money_text.dart';
import '../../core/utils/responsive.dart';
import '../../models/booking.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/full_screen_dialog.dart';
import '../../widgets/list_table_switcher.dart';
import '../dashboard/widgets/report_table.dart';
import 'widgets/booking_form.dart';
import 'widgets/booking_widgets.dart';
import 'widgets/payment_form.dart';

/// BookingDetailScreen is one booking in full: customer and plot, each
/// part's payment plan (with loan details), what is paid and due, and
/// the payment history. Sales record payments; the Admin approves or
/// rejects pending bookings.
class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final BookingController controller;
  final bool canRecordPayments;
  final bool canApprove;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    required this.controller,
    this.canRecordPayments = false,
    this.canApprove = false,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  int _paymentCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _recordPayment(Booking booking) {
    return showAppForm(
      context,
      PaymentForm(
        booking: booking,
        newId: 'p${booking.id}-${booking.payments.length + ++_paymentCount}',
        onSubmit: (payment) async {
          if (!await runSave(context, () => widget.controller.addPayment(booking.id, payment)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${MoneyText.full(payment.amount)} recorded for ${booking.customer.name}.');
        },
      ),
    );
  }

  /// Corrects an approved booking, or a rejected one and sends it back
  /// for approval ([resubmit]).
  Future<void> _editBooking(Booking booking, {bool resubmit = false}) {
    return showAppForm(
      context,
      BookingForm.edit(
        booking: booking,
        resubmit: resubmit,
        onSubmit: (updated) async {
          final save = resubmit ? widget.controller.resubmit : widget.controller.updateBooking;
          if (!await runSave(context, () => save(updated)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(
            context,
            resubmit
                ? 'Booking for ${updated.customer.name} sent for re-approval.'
                : 'Booking for ${updated.customer.name} updated.',
          );
        },
      ),
    );
  }

  /// Sends a rejected booking back for approval as it is.
  Future<void> _resubmit(Booking booking) async {
    if (!await runSave(context, () => widget.controller.resubmit(booking)) || !mounted) return;
    showAppMessage(context, 'Booking for ${booking.customer.name} sent for re-approval.');
  }

  /// Null when this user may not change it, or the booking is not approved.
  ValueChanged<LoanStatus>? _loanStatusAction(Booking booking, PaymentPart part) {
    if (!widget.canRecordPayments || booking.status != BookingStatus.approved) return null;
    return (status) async {
      if (!await runSave(context, () => widget.controller.updateLoanStatus(booking.id, part, status)) || !mounted) return;
      showAppMessage(context, 'Loan marked ${status.label}.');
    };
  }

  Future<void> _approve(Booking booking) async {
    if (!await runSave(context, () => widget.controller.approve(booking.id)) || !mounted) return;
    showAppMessage(context, 'Booking for ${booking.customer.name} approved.');
  }

  Future<void> _reject(Booking booking) async {
    if (!await runSave(context, () => widget.controller.reject(booking.id)) || !mounted) return;
    showAppMessage(context, 'Booking for ${booking.customer.name} rejected. Plot ${booking.plotNumber} is free again.');
  }

  @override
  Widget build(BuildContext context) => FullScreenDialogFrame(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final booking = widget.controller.bookingById(widget.bookingId);
    final wide = Responsive.isWeb(context);

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: SafeArea(
          child: booking == null
              ? const Center(child: Text('This booking no longer exists.'))
              : Column(
                  children: [
                    _buildHeader(booking),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(wide ? 20 : 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: wide ? _buildWide(booking) : _buildNarrow(booking),
                          ),
                        ),
                      ),
                    ),
                    _buildActions(booking, wide),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(Booking booking) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Plot ${booking.plotNumber} · ${booking.siteName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: BookingChip.status(booking.status),
          ),
        ],
      ),
    );
  }

  Widget _buildWide(Booking booking) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _SummaryCard(booking: booking),
              const SizedBox(height: 14),
              _DetailsCard(booking: booking),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final plan in booking.plans) ...[
                _PlanCard(booking: booking, plan: plan, onLoanStatus: _loanStatusAction(booking, plan.part)),
                const SizedBox(height: 14),
              ],
              _PaymentsCard(booking: booking),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(Booking booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(booking: booking),
        const SizedBox(height: 12),
        for (final plan in booking.plans) ...[
          _PlanCard(booking: booking, plan: plan, onLoanStatus: _loanStatusAction(booking, plan.part)),
          const SizedBox(height: 12),
        ],
        _PaymentsCard(booking: booking),
        const SizedBox(height: 12),
        _DetailsCard(booking: booking),
      ],
    );
  }

  /// Bottom bar: Approve / Reject for a pending booking (Admin), and
  /// Record Payment while there is a balance.
  Widget _buildActions(Booking booking, bool wide) {
    final buttons = <Widget>[
      if (widget.canApprove && booking.status == BookingStatus.pending) ...[
        AppButton.outline(
          key: const ValueKey('detail-reject'),
          text: 'Reject',
          width: wide ? 160 : double.infinity,
          onPressed: () => _reject(booking),
        ),
        AppButton.primary(
          key: const ValueKey('detail-approve'),
          text: 'Approve',
          width: wide ? 180 : double.infinity,
          gradient: AppColors.brandGradient,
          icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
          onPressed: () => _approve(booking),
        ),
      ],
      // Only an approved booking can be corrected.
      if (widget.canRecordPayments && booking.status == BookingStatus.approved)
        AppButton.outline(
          key: const ValueKey('detail-edit'),
          text: 'Edit Booking',
          width: wide ? 180 : double.infinity,
          icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
          onPressed: () => _editBooking(booking),
        ),
      // A rejected booking can be corrected and sent back for approval.
      if (widget.canRecordPayments && booking.status == BookingStatus.rejected) ...[
        AppButton.outline(
          key: const ValueKey('detail-edit-resubmit'),
          text: 'Edit Details',
          width: wide ? 170 : double.infinity,
          icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
          onPressed: () => _editBooking(booking, resubmit: true),
        ),
        AppButton.primary(
          key: const ValueKey('detail-resubmit'),
          text: 'Send for Re-approval',
          width: wide ? 230 : double.infinity,
          gradient: AppColors.brandGradient,
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
          onPressed: () => _resubmit(booking),
        ),
      ],
      // Payments start once the Admin approves.
      if (widget.canRecordPayments && booking.status == BookingStatus.approved && booking.balance > 0)
        AppButton.primary(
          key: const ValueKey('record-payment'),
          text: 'Record Payment',
          width: wide ? 220 : double.infinity,
          gradient: AppColors.brandGradient,
          icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 16),
          onPressed: () => _recordPayment(booking),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, wide ? 32 : 16, 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(top: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            wide ? buttons[i] : Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}

/// White rounded card with a title.
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Card({super.key, required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Label on the left, value on the right.
Color loanStatusColor(LoanStatus status) => switch (status) {
      LoanStatus.applied => const Color(0xFFC98A2E),
      LoanStatus.sanctioned => const Color(0xFF3A7CA5),
      LoanStatus.partlyDisbursed => AppColors.primaryBright,
      LoanStatus.disbursed => const Color(0xFF3F8F5A),
    };

/// Loan status as a coloured chip, with a menu to mark it while the
/// loan is still Applied or Sanctioned.
class _LoanStatusRow extends StatelessWidget {
  final PaymentPart part;
  final LoanStatus status;
  final ValueChanged<LoanStatus>? onChange;

  const _LoanStatusRow({required this.part, required this.status, this.onChange});

  @override
  Widget build(BuildContext context) {
    final color = loanStatusColor(status);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.label,
            key: ValueKey('loan-status-${part.name}'),
            style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Loan Status',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: onChange == null
                  ? chip
                  : PopupMenuButton<LoanStatus>(
                      key: ValueKey('loan-status-menu-${part.name}'),
                      tooltip: 'Change loan status',
                      initialValue: status,
                      onSelected: onChange,
                      itemBuilder: (_) => [
                        for (final s in LoanStatus.manual) PopupMenuItem(value: s, child: Text(s.label)),
                      ],
                      child: chip,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sage card with the total value, paid and balance.
class _SummaryCard extends StatelessWidget {
  final Booking booking;

  const _SummaryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    Widget figure(String label, double value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondaryDark)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  MoneyText.full(value),
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.pureWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandDeep, AppColors.brandDark, Color.lerp(AppColors.brandDark, AppColors.sageMid, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LightChip(icon: booking.type.icon, label: booking.type.label),
              if (booking.hasLoan) const _LightChip(icon: Icons.account_balance_outlined, label: 'Loan'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              figure('Total Value', booking.totalValue),
              const SizedBox(width: 10),
              figure('Paid', booking.totalPaid),
              const SizedBox(width: 10),
              figure('Balance', booking.balance),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: booking.paidRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.mint),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            booking.isFullyPaid ? 'Fully paid' : '${(booking.paidRatio * 100).round()}% paid',
            style: AppTypography.caption.copyWith(color: AppColors.mint, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LightChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.pureWhite),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Customer and plot details.
class _DetailsCard extends StatelessWidget {
  final Booking booking;

  const _DetailsCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final c = booking.customer;

    return _Card(
      title: 'Customer & Plot',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _InfoRow('Name', c.name),
          _InfoRow('Mobile', c.mobile),
          if (c.email.isNotEmpty) _InfoRow('Email', c.email),
          if (c.address.isNotEmpty) _InfoRow('Address', c.address),
          Divider(color: AppColors.lightBorder, height: 20),
          _InfoRow('Site', booking.siteName),
          _InfoRow('Plot No.', booking.plotNumber),
          if (booking.plotSize != null) _InfoRow('Size', booking.plotSize!),
          if (booking.facing != null) _InfoRow('Facing', booking.facing!.label),
          _InfoRow('Booking Type', booking.type.label),
          _InfoRow('Booked On', DateText.shortDate(booking.bookedOn)),
          _InfoRow('Booked By', booking.bookedBy),
        ],
      ),
    );
  }
}

/// One part (plot or construction): value, mode, loan and paid so far.
class _PlanCard extends StatelessWidget {
  final Booking booking;
  final PaymentPlan plan;

  /// Marks the loan Applied or Sanctioned; null when not allowed.
  final ValueChanged<LoanStatus>? onLoanStatus;

  const _PlanCard({required this.booking, required this.plan, this.onLoanStatus});

  @override
  Widget build(BuildContext context) {
    final loan = plan.loan;

    return _Card(
      key: ValueKey('plan-${plan.part.name}'),
      title: plan.part.label,
      icon: plan.part.icon,
      trailing: BookingChip(
        label: plan.mode.label,
        icon: plan.mode.icon,
        color: plan.mode == PaymentMode.loan ? AppColors.accentGold : AppColors.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow('Value', MoneyText.full(plan.value)),
          if (loan != null) ...[
            _InfoRow('Bank / Lender', loan.bankName),
            _InfoRow('Loan Amount', MoneyText.full(loan.amount)),
            if (loan.reference.isNotEmpty) _InfoRow('Loan A/c / Ref.', loan.reference),
            _LoanStatusRow(
              part: plan.part,
              status: loan.status,
              // Once the bank pays, the status follows its payments.
              onChange: loan.status.isManual ? onLoanStatus : null,
            ),
            _InfoRow('Loan Received', MoneyText.full(booking.loanReceivedFor(plan.part))),
            _InfoRow('Loan to Come', MoneyText.full(booking.loanToComeFor(plan.part))),
            _InfoRow('Customer Share', MoneyText.full(plan.ownContribution)),
          ],
          const SizedBox(height: 4),
          PaidProgress(paid: booking.paidFor(plan.part), total: plan.value),
        ],
      ),
    );
  }
}

/// Every payment received, newest first.
class _PaymentsCard extends StatelessWidget {
  final Booking booking;

  const _PaymentsCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final payments = [...booking.payments]..sort((a, b) => b.date.compareTo(a.date));

    return _Card(
      title: 'Payment History',
      icon: Icons.receipt_long_outlined,
      trailing: Text(
        '${payments.length}',
        style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
      ),
      child: payments.isEmpty
          ? Text(
              'No payments yet.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
            )
          : ListTableSwitcher(
              id: 'booking-payments',
              list: (_) => Column(
                children: [
                  for (final p in payments) PaymentRow(payment: p, showPart: booking.plans.length > 1),
                ],
              ),
              table: (_) => ReportTable(
                minWidth: 620,
                columns: const [
                  ReportColumn('Date', flex: 1),
                  ReportColumn('Part', flex: 1.4),
                  ReportColumn('Method', flex: 1.2),
                  ReportColumn('Reference', flex: 1.2),
                  ReportColumn('Amount', flex: 1, numeric: true),
                ],
                rows: [
                  for (final p in payments)
                    [
                      ReportTable.text(DateText.shortDate(p.date)),
                      ReportTable.text(p.part.label),
                      ReportTable.text(p.method.label),
                      ReportTable.text(p.reference.isEmpty ? ReportTable.blank : p.reference),
                      ReportTable.text(MoneyText.full(p.amount), bold: true, color: AppColors.success),
                    ],
                ],
              ),
            ),
    );
  }
}

/// One received payment: method, date, part, reference and amount.
class PaymentRow extends StatelessWidget {
  final PaymentEntry payment;
  final bool showPart;
  final String? title;

  const PaymentRow({super.key, required this.payment, this.showPart = true, this.title});

  @override
  Widget build(BuildContext context) {
    final details = [
      DateText.shortDate(payment.date),
      if (showPart) payment.part.label,
      if (payment.reference.isNotEmpty) payment.reference,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.south_west_rounded, size: 18, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? payment.method.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  title == null ? details : '${payment.method.label} · $details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            MoneyText.full(payment.amount),
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
