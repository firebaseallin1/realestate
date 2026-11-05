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
/// (plot value, construction value) is paid: in full or with a bank loan.
class BookingForm extends StatefulWidget {
  final List<Site> sites;
  final bool Function(String siteId, String plotNumber) isPlotTaken;
  final String newId;
  final String bookedBy;
  final ValueChanged<Booking> onSubmit;

  const BookingForm({
    super.key,
    required this.sites,
    required this.isPlotTaken,
    required this.newId,
    required this.bookedBy,
    required this.onSubmit,
  });

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
  PaymentMode mode = PaymentMode.fullPayment;
  LoanStatus loanStatus = LoanStatus.applied;

  _PlanDraft(this.part);

  double get valueAmount => MoneyText.parse(value.text) ?? 0;

  PaymentPlan toPlan() => PaymentPlan(
        part: part,
        value: valueAmount,
        mode: mode,
        loan: mode == PaymentMode.loan
            ? LoanDetails(
                bankName: bank.text.trim(),
                amount: MoneyText.parse(loanAmount.text) ?? 0,
                reference: reference.text.trim(),
                status: loanStatus,
              )
            : null,
      );

  void dispose() {
    value.dispose();
    bank.dispose();
    loanAmount.dispose();
    reference.dispose();
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
    return site.plots
        .where((p) => p.status == PlotStatus.available && !widget.isPlotTaken(site.id, p.number))
        .toList();
  }

  List<_PlanDraft> get _plans =>
      _type == BookingType.withConstruction ? [_plotPlan, _constructionPlan] : [_plotPlan];

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
    for (final plot in _openPlots) {
      if (plot.id == plotId && plot.price != null && _plotPlan.value.text.isEmpty) {
        _plotPlan.value.text = plot.price!.round().toString();
      }
    }
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final site = _site!;
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
        plotSize: plot?.sizeLabel ??
            (_plotSizeController.text.trim().isEmpty ? null : _plotSizeController.text.trim()),
        facing: plot?.facing ?? _facing,
        customer: Customer(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
        ),
        type: _type,
        plans: [for (final draft in _plans) draft.toPlan()],
        bookedOn: DateTime.now(),
        bookedBy: widget.bookedBy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = _site;
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
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Booking',
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      'Book a plot, with or without construction',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Site & plot
          const _StepHeader(step: 1, title: 'Site & Plot'),
          AppDropdown<String>(
            key: const ValueKey('booking-site'),
            label: 'Site',
            hint: 'Select a site',
            value: _siteId,
            prefixIcon: const Icon(Icons.domain_rounded),
            items: [
              for (final s in widget.sites)
                AppDropdownOption(value: s.id, title: s.name, subtitle: '${s.location} · ${s.availableUnits} available'),
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
                  AppDropdownOption(value: p.id, title: 'Plot ${p.number}', subtitle: '${p.sizeLabel} · ${p.facing.label} facing'),
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
                items: [
                  for (final f in PlotFacing.values) AppDropdownOption(value: f, title: f.label),
                ],
                onChanged: (f) => setState(() => _facing = f),
              ),
            ),
          ],

          // 2. Customer
          const _StepHeader(step: 2, title: 'Customer Details'),
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

          // 3. Booking type
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
                    onTap: () => setState(() => _type = type),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 4. Payment for each part
          const _StepHeader(step: 4, title: 'Payment Details'),
          for (final draft in _plans)
            _PlanFields(
              draft: draft,
              onChanged: () => setState(() {}),
            ),

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
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.brandDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  MoneyText.full(total),
                  key: const ValueKey('booking-total'),
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.brandDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  key: const ValueKey('booking-submit'),
                  text: 'Create Booking',
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

  const _PlanFields({required this.draft, required this.onChanged});

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
              return null;
            },
          ),
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
              right: AppDropdown<LoanStatus>(
                key: ValueKey('$name-loan-status'),
                label: 'Loan Status',
                value: draft.loanStatus,
                prefixIcon: const Icon(Icons.flag_outlined),
                items: [
                  for (final s in LoanStatus.values) AppDropdownOption(value: s, title: s.label),
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
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
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
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w700,
              ),
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
