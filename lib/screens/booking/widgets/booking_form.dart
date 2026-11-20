import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../models/site.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';

/// BookingForm books a plot for a customer, in four steps: site and plot,
/// customer details, with or without construction, and how each part
/// (plot value, construction value) is paid: in full or with a bank loan,
/// and what the customer paid towards each part at booking.
class BookingForm extends StatefulWidget {
  final List<Site> sites;
  final bool Function(String siteId, String plotNumber) isPlotTaken;
  final String newId;
  final String bookedBy;
  final ValueChanged<Booking> onSubmit;

  /// The booking being corrected, or null for a new booking.
  final Booking? editing;

  /// Saving sends the rejected booking back for approval.
  final bool resubmit;

  const BookingForm({
    super.key,
    required this.sites,
    required this.isPlotTaken,
    required this.newId,
    required this.bookedBy,
    required this.onSubmit,
    this.customer,
  }) : editing = null,
       resubmit = false;

  /// Fills in a known customer's details, e.g. one converted from a lead.
  final Customer? customer;

  /// Corrects an approved booking, or a rejected one before sending it for
  /// re-approval ([resubmit]): customer, values, payment mode and loan.
  /// The site, plot and booking type stay as booked.
  const BookingForm.edit({super.key, required Booking booking, required this.onSubmit, this.resubmit = false})
    : editing = booking,
      sites = const [],
      customer = null,
      isPlotTaken = _never,
      newId = '',
      bookedBy = '';

  static bool _never(String siteId, String plotNumber) => false;

  @override
  State<BookingForm> createState() => _BookingFormState();
}

/// The fields of one part's payment plan while the form is open.
class _PlanDraft {
  final PaymentPart part;
  final value = TextEditingController();
  final bank = TextEditingController();
  final loanAmount = TextEditingController();
  final reference = TextEditingController();
  final paidNow = TextEditingController();
  final paidReference = TextEditingController();
  PaymentMode mode = PaymentMode.fullPayment;
  LoanStatus loanStatus = LoanStatus.applied;
  PaymentMethod paidMethod = PaymentMethod.cash;

  /// When editing: already paid on this part, and of that from the bank.
  /// Values cannot go below them.
  double paid = 0;
  double loanReceived = 0;

  _PlanDraft(this.part);

  /// Starts from a saved plan, for editing.
  void fill(Booking booking, PaymentPlan plan) {
    value.text = plan.value.round().toString();
    mode = plan.mode;
    final loan = plan.loan;
    if (loan != null) {
      bank.text = loan.bankName;
      loanAmount.text = loan.amount.round().toString();
      reference.text = loan.reference;
      loanStatus = loan.status;
    }
    paid = booking.paidFor(part);
    loanReceived = booking.loanReceivedFor(part);
  }

  /// Once the bank has paid, the status follows its payments.
  LoanStatus get effectiveLoanStatus {
    if (loanReceived <= 0) return loanStatus;
    return loanReceived >= loanAmountValue ? LoanStatus.disbursed : LoanStatus.partlyDisbursed;
  }

  double get valueAmount => MoneyText.parse(value.text) ?? 0;
  double get loanAmountValue => mode == PaymentMode.loan ? MoneyText.parse(loanAmount.text) ?? 0 : 0;

  /// What the customer pays themselves; the bank pays the loan later.
  double get ownShare => valueAmount - loanAmountValue;
  double get paidNowAmount => MoneyText.parse(paidNow.text) ?? 0;

  /// The payment made at booking for this part, if any.
  PaymentEntry? toPayment(String id, DateTime date) => paidNowAmount <= 0
      ? null
      : PaymentEntry(
          id: id,
          part: part,
          amount: paidNowAmount,
          date: date,
          method: paidMethod,
          reference: paidReference.text.trim(),
        );

  /// Empties every field, for a fresh start when the booking type changes.
  void reset() {
    for (final c in [value, bank, loanAmount, reference, paidNow, paidReference]) {
      c.clear();
    }
    mode = PaymentMode.fullPayment;
    loanStatus = LoanStatus.applied;
    paidMethod = PaymentMethod.cash;
  }

  PaymentPlan toPlan() => PaymentPlan(
    part: part,
    value: valueAmount,
    mode: mode,
    loan: mode == PaymentMode.loan
        ? LoanDetails(
            bankName: bank.text.trim(),
            amount: MoneyText.parse(loanAmount.text) ?? 0,
            reference: reference.text.trim(),
            status: effectiveLoanStatus,
          )
        : null,
  );

  void dispose() {
    value.dispose();
    bank.dispose();
    loanAmount.dispose();
    reference.dispose();
    paidNow.dispose();
    paidReference.dispose();
  }
}

class _BookingFormState extends State<BookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _plotNumberController = TextEditingController();
  final _plotSizeController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _plotPlan = _PlanDraft(PaymentPart.plot);
  final _constructionPlan = _PlanDraft(PaymentPart.construction);

  String? _siteId;
  String? _plotId;
  PlotFacing? _facing;
  BookingType _type = BookingType.withoutConstruction;

  Site? get _site {
    for (final site in widget.sites) {
      if (site.id == _siteId) return site;
    }
    return null;
  }

  /// Layout plots still free to book at the chosen site.
  List<Plot> get _openPlots {
    final site = _site;
    if (site == null) return const [];
    return site.plots.where((p) => p.status == PlotStatus.available && !widget.isPlotTaken(site.id, p.number)).toList();
  }

  @override
  void initState() {
    super.initState();
    final booking = widget.editing;
    final customer = widget.customer;
    if (booking == null && customer != null) {
      _nameController.text = customer.name;
      _mobileController.text = customer.mobile;
      _emailController.text = customer.email;
      _addressController.text = customer.address;
    }
    if (booking == null) return;
    _type = booking.type;
    _nameController.text = booking.customer.name;
    _mobileController.text = booking.customer.mobile;
    _emailController.text = booking.customer.email;
    _addressController.text = booking.customer.address;
    for (final plan in booking.plans) {
      (plan.part == PaymentPart.plot ? _plotPlan : _constructionPlan).fill(booking, plan);
    }
  }

  List<_PlanDraft> get _plans => _type == BookingType.withConstruction ? [_plotPlan, _constructionPlan] : [_plotPlan];

  @override
  void dispose() {
    for (final c in [
      _plotNumberController,
      _plotSizeController,
      _nameController,
      _mobileController,
      _emailController,
      _addressController,
    ]) {
      c.dispose();
    }
    _plotPlan.dispose();
    _constructionPlan.dispose();
    super.dispose();
  }

  void _pickPlot(String? plotId) {
    setState(() => _plotId = plotId);
    _fillPlotPrice();
  }

  /// The layout plot's price, when it has one and nothing is typed yet.
  void _fillPlotPrice() {
    for (final plot in _openPlots) {
      if (plot.id == _plotId && plot.price != null && _plotPlan.value.text.isEmpty) {
        _plotPlan.value.text = plot.price!.round().toString();
      }
    }
  }

  /// A different booking type means a different payment plan, so the
  /// payment details start again (the plot's layout price is kept).
  void _changeType(BookingType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _plotPlan.reset();
      _constructionPlan.reset();
      _fillPlotPrice();
    });
  }

  String? _validatePlotNumber(String? value) {
    final number = value?.trim() ?? '';
    if (number.isEmpty) return 'Please enter the plot number.';
    if (_siteId != null && widget.isPlotTaken(_siteId!, number)) {
      return 'Plot $number is already booked.';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return 'Please enter a mobile number.';
    if (!RegExp(r'^(\+91)?\d{10}$').hasMatch(digits)) return 'Enter a 10-digit mobile number.';
    return null;
  }

  Customer get _customer => Customer(
    name: _nameController.text.trim(),
    mobile: _mobileController.text.trim(),
    email: _emailController.text.trim(),
    address: _addressController.text.trim(),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final editing = widget.editing;
    if (editing != null) {
      widget.onSubmit(editing.copyWith(customer: _customer, plans: [for (final draft in _plans) draft.toPlan()]));
      return;
    }
    final site = _site!;
    final today = DateTime.now();
    Plot? plot;
    for (final p in site.plots) {
      if (p.id == _plotId) plot = p;
    }

    widget.onSubmit(
      Booking(
        id: widget.newId,
        siteId: site.id,
        siteName: site.name,
        plotNumber: plot?.number ?? _plotNumberController.text.trim(),
        plotId: plot?.id,
        plotSize: plot?.sizeLabel ?? (_plotSizeController.text.trim().isEmpty ? null : _plotSizeController.text.trim()),
        facing: plot?.facing ?? _facing,
        customer: _customer,
        type: _type,
        plans: [for (final draft in _plans) draft.toPlan()],
        payments: [for (final draft in _plans) ?draft.toPayment('${widget.newId}-${draft.part.name}', today)],
        bookedOn: today,
        bookedBy: widget.bookedBy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = _site;
    final editing = widget.editing;
    final total = _plans.fold<double>(0, (sum, d) => sum + d.valueAmount);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event_available_rounded, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing == null
                          ? 'New Booking'
                          : widget.resubmit
                          ? 'Edit & Re-submit'
                          : 'Edit Booking',
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      editing == null
                          ? 'Book a plot, with or without construction'
                          : 'Plot ${editing.plotNumber} · ${editing.siteName} · ${editing.type.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Site & plot (fixed once booked)
          if (editing == null) ...[
            const _StepHeader(step: 1, title: 'Site & Plot'),
            AppDropdown<String>(
              key: const ValueKey('booking-site'),
              label: 'Site',
              hint: 'Select a site',
              value: _siteId,
              prefixIcon: const Icon(Icons.domain_rounded),
              items: [
                for (final s in widget.sites)
                  AppDropdownOption(
                    value: s.id,
                    title: s.name,
                    subtitle: '${s.location} · ${s.availableUnits} available',
                  ),
              ],
              onChanged: (id) => setState(() {
                _siteId = id;
                _plotId = null;
              }),
              validator: (id) => id == null ? 'Please select a site.' : null,
            ),
            if (site != null && site.hasLayout)
              AppDropdown<String>(
                key: ValueKey('booking-plot-${site.id}'),
                label: 'Plot',
                hint: _openPlots.isEmpty ? 'No plots available' : 'Select a plot from the layout',
                value: _plotId,
                prefixIcon: const Icon(Icons.crop_square_rounded),
                items: [
                  for (final p in _openPlots)
                    AppDropdownOption(
                      value: p.id,
                      title: 'Plot ${p.number}',
                      subtitle: '${p.sizeLabel} · ${p.facing.label} facing',
                    ),
                ],
                onChanged: _pickPlot,
                validator: (id) => id == null ? 'Please select a plot.' : null,
              )
            else ...[
              AppTextField(
                key: const ValueKey('booking-plot-number'),
                controller: _plotNumberController,
                label: 'Plot No.',
                hintText: 'e.g. 5',
                prefixIcon: const Icon(Icons.tag_rounded),
                validator: _validatePlotNumber,
              ),
              _TwoUp(
                left: AppTextField(
                  key: const ValueKey('booking-plot-size'),
                  controller: _plotSizeController,
                  label: 'Plot Size (optional)',
                  hintText: 'e.g. 30 × 40 ft',
                  prefixIcon: const Icon(Icons.straighten_rounded),
                ),
                right: AppDropdown<PlotFacing>(
                  label: 'Facing (optional)',
                  hint: 'Select',
                  value: _facing,
                  prefixIcon: const Icon(Icons.explore_outlined),
                  items: [for (final f in PlotFacing.values) AppDropdownOption(value: f, title: f.label)],
                  onChanged: (f) => setState(() => _facing = f),
                ),
              ),
            ],
          ],

          // 2. Customer
          _StepHeader(step: editing == null ? 2 : 1, title: 'Customer Details'),
          AppTextField(
            key: const ValueKey('customer-name'),
            controller: _nameController,
            label: 'Customer Name',
            hintText: 'Full name',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            validator: (v) => (v?.trim() ?? '').isEmpty ? 'Please enter the customer name.' : null,
          ),
          _TwoUp(
            left: AppTextField(
              key: const ValueKey('customer-mobile'),
              controller: _mobileController,
              label: 'Mobile No.',
              hintText: '10-digit number',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
              validator: _validateMobile,
            ),
            right: AppTextField(
              key: const ValueKey('customer-email'),
              controller: _emailController,
              label: 'Email (optional)',
              hintText: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          AppTextField(
            key: const ValueKey('customer-address'),
            controller: _addressController,
            label: 'Address (optional)',
            hintText: 'House, street, city',
            prefixIcon: const Icon(Icons.home_outlined),
          ),

          // 3. Booking type (fixed once booked)
          if (editing == null) ...[
            const _StepHeader(step: 3, title: 'Booking Type'),
            Row(
              children: [
                for (final type in BookingType.values) ...[
                  if (type != BookingType.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceTile(
                      key: ValueKey('type-${type.name}'),
                      icon: type.icon,
                      title: type.label,
                      subtitle: type.description,
                      selected: _type == type,
                      onTap: () => _changeType(type),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 4. Payment for each part
          _StepHeader(step: editing == null ? 4 : 2, title: 'Payment Details'),
          for (final draft in _plans)
            _PlanFields(draft: draft, showPaidNow: editing == null, onChanged: () => setState(() {})),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _type == BookingType.withConstruction ? 'Total (plot + construction)' : 'Total plot value',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  MoneyText.full(total),
                  key: const ValueKey('booking-total'),
                  style: AppTypography.titleMedium.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: AppButton.outline(text: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  key: const ValueKey('booking-submit'),
                  text: editing == null
                      ? 'Create Booking'
                      : widget.resubmit
                      ? 'Send for Re-approval'
                      : 'Save Changes',
                  gradient: AppColors.brandGradient,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One part's value, payment mode, and loan details when on a loan.
class _PlanFields extends StatelessWidget {
  final _PlanDraft draft;
  final VoidCallback onChanged;

  /// New bookings record what was paid now; edits do not.
  final bool showPaidNow;

  const _PlanFields({required this.draft, required this.onChanged, this.showPaidNow = true});

  @override
  Widget build(BuildContext context) {
    final part = draft.part;
    final name = part.name;
    final loan = MoneyText.parse(draft.loanAmount.text) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(part.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            key: ValueKey('$name-value'),
            controller: draft.value,
            label: '${part.label} (₹)',
            hintText: 'e.g. 15,00,000',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.currency_rupee_rounded),
            onChanged: (_) => onChanged(),
            validator: (v) {
              final amount = MoneyText.parse(v);
              if (amount == null || amount <= 0) return 'Enter the ${part.label.toLowerCase()}.';
              if (amount < draft.paid) return '${MoneyText.full(draft.paid)} is already paid; it cannot be less.';
              return null;
            },
          ),
          if (draft.loanReceived > 0)
            _Note(
              icon: Icons.lock_outline_rounded,
              text: 'The bank has paid ${MoneyText.full(draft.loanReceived)} on this loan, so it stays a bank loan.',
            )
          else
            Row(
              children: [
                for (final mode in PaymentMode.values) ...[
                  if (mode != PaymentMode.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceTile(
                      key: ValueKey('$name-mode-${mode.name}'),
                      icon: mode.icon,
                      title: mode.label,
                      selected: draft.mode == mode,
                      dense: true,
                      onTap: () {
                        draft.mode = mode;
                        onChanged();
                      },
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          if (draft.mode == PaymentMode.loan) ...[
            _TwoUp(
              left: AppTextField(
                key: ValueKey('$name-loan-bank'),
                controller: draft.bank,
                label: 'Bank / Lender',
                hintText: 'e.g. SBI',
                prefixIcon: const Icon(Icons.account_balance_outlined),
                validator: (v) => (v?.trim() ?? '').isEmpty ? 'Please enter the bank.' : null,
              ),
              right: AppTextField(
                key: ValueKey('$name-loan-amount'),
                controller: draft.loanAmount,
                label: 'Loan Amount (₹)',
                hintText: 'Sanctioned / applied',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                onChanged: (_) => onChanged(),
                validator: (v) {
                  final amount = MoneyText.parse(v);
                  if (amount == null || amount <= 0) return 'Enter the loan amount.';
                  if (amount > draft.valueAmount) return 'Loan is more than the value.';
                  if (amount < draft.loanReceived) {
                    return 'The bank has already paid ${MoneyText.full(draft.loanReceived)}.';
                  }
                  return null;
                },
              ),
            ),
            _TwoUp(
              left: AppTextField(
                key: ValueKey('$name-loan-reference'),
                controller: draft.reference,
                label: 'Loan A/c / Ref. (optional)',
                hintText: 'e.g. HL-55120',
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
              // Once the bank pays, the status follows its payments.
              right: AppDropdown<LoanStatus>(
                key: ValueKey('$name-loan-status'),
                label: 'Loan Status',
                value: draft.loanReceived > 0 ? draft.effectiveLoanStatus : draft.loanStatus,
                enabled: draft.loanReceived <= 0,
                prefixIcon: const Icon(Icons.flag_outlined),
                items: [
                  if (draft.loanReceived > 0)
                    AppDropdownOption(value: draft.effectiveLoanStatus, title: draft.effectiveLoanStatus.label)
                  else
                    for (final s in LoanStatus.manual) AppDropdownOption(value: s, title: s.label),
                ],
                onChanged: (s) {
                  if (s != null) draft.loanStatus = s;
                  onChanged();
                },
              ),
            ),
            if (draft.valueAmount > 0 && loan > 0 && loan <= draft.valueAmount)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Customer pays ${MoneyText.full(draft.valueAmount - loan)} + loan ${MoneyText.full(loan)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          if (showPaidNow) _PaidNowFields(draft: draft, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final String title;

  const _StepHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Text(
              '$step',
              style: AppTypography.caption.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two fields side by side when there is room, stacked otherwise.
class _TwoUp extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TwoUp({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

/// A selectable tile, filled sage when chosen.
class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  const _ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    this.dense = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.pureWhite : AppColors.textPrimaryLight;

    return Material(
      color: selected ? AppColors.primary : AppColors.pureWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 11 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.lightBorder, width: 1.2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.pureWhite : AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(color: foreground, fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: selected ? AppColors.mint : AppColors.textMutedLight,
                        ),
                      ),
                  ],
                ),
              ),
              // Dense tiles (payment mode) show selection by fill alone, to fit.
              if (selected && !dense) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.pureWhite),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the customer paid towards this part at booking: an advance or
/// part of their own share. The rest, and any loan, are recorded later.
class _PaidNowFields extends StatelessWidget {
  final _PlanDraft draft;
  final VoidCallback onChanged;

  const _PaidNowFields({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final name = draft.part.name;
    final onLoan = draft.mode == PaymentMode.loan;
    final share = draft.ownShare;
    final paid = draft.paidNowAmount;
    final shareLabel = onLoan ? "customer's share" : draft.part.label.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: AppColors.lightBorder),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Paid by customer now',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
              ),
            ),
            Text('Optional', style: AppTypography.caption.copyWith(color: AppColors.textMutedLight)),
          ],
        ),
        const SizedBox(height: 10),
        _TwoUp(
          left: AppTextField(
            key: ValueKey('$name-paid-now'),
            controller: draft.paidNow,
            label: 'Amount Paid (₹)',
            hintText: share > 0 ? 'Up to ${MoneyText.full(share)}' : 'e.g. 50,000',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.currency_rupee_rounded),
            onChanged: (_) => onChanged(),
            validator: (v) {
              if ((v?.trim() ?? '').isEmpty) return null;
              final amount = MoneyText.parse(v);
              if (amount == null || amount < 0) return 'Enter a valid amount.';
              if (amount > share) return 'More than the $shareLabel (${MoneyText.full(share)}).';
              return null;
            },
          ),
          right: AppDropdown<PaymentMethod>(
            key: ValueKey('$name-paid-method'),
            label: 'Paid By',
            value: draft.paidMethod,
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            items: [
              // The bank's loan is not the customer's own payment.
              for (final m in PaymentMethod.values)
                if (m != PaymentMethod.loanDisbursement) AppDropdownOption(value: m, title: m.label),
            ],
            onChanged: (m) {
              if (m != null) draft.paidMethod = m;
              onChanged();
            },
          ),
        ),
        if (paid > 0)
          AppTextField(
            key: ValueKey('$name-paid-reference'),
            controller: draft.paidReference,
            label: 'Receipt / UTR / Cheque No. (optional)',
            hintText: 'e.g. UTR 4521…',
            prefixIcon: const Icon(Icons.receipt_long_outlined),
          ),
        if (share > 0 && paid > 0 && paid <= share)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Figure(label: onLoan ? "Customer's share" : 'Value', amount: share),
                _Figure(label: 'Paid now', amount: paid),
                _Figure(label: 'Still to pay', amount: share - paid, strong: true),
                if (onLoan) _Figure(label: 'Loan (later)', amount: draft.loanAmountValue),
              ],
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final double amount;
  final bool strong;

  const _Figure({required this.label, required this.amount, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
          ),
          TextSpan(
            text: MoneyText.full(amount),
            style: AppTypography.caption.copyWith(
              color: strong ? AppColors.brandDeep : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small explanatory line inside a payment part.
class _Note extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.brandDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryLight)),
          ),
        ],
      ),
    );
  }
}
