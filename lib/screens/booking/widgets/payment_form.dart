import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';

/// PaymentForm records an amount received against one part of a booking
/// (plot value, or construction value for bookings with construction).
class PaymentForm extends StatefulWidget {
  final Booking booking;
  final String newId;
  final ValueChanged<PaymentEntry> onSubmit;

  const PaymentForm({
    super.key,
    required this.booking,
    required this.newId,
    required this.onSubmit,
  });

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  late PaymentPart _part;
  PaymentMethod? _method;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Start on the first part that still has a balance.
    final open = widget.booking.plans.where((p) => widget.booking.balanceFor(p.part) > 0);
    _part = (open.isEmpty ? widget.booking.plans.first : open.first).part;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double get _balance => widget.booking.balanceFor(_part);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _validateAmount(String? value) {
    final amount = MoneyText.parse(value);
    if (amount == null || amount <= 0) return 'Enter the amount received.';
    if (amount > _balance) return 'More than the balance of ${MoneyText.full(_balance)}.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      PaymentEntry(
        id: widget.newId,
        part: _part,
        amount: MoneyText.parse(_amountController.text)!,
        date: _date,
        method: _method!,
        reference: _referenceController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final plan = booking.plan(_part)!;

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
                child: const Icon(Icons.payments_rounded, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Payment',
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      '${booking.customer.name} · Plot ${booking.plotNumber}',
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
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (booking.plans.length > 1)
            AppDropdown<PaymentPart>(
              key: const ValueKey('payment-part'),
              label: 'Payment For',
              value: _part,
              prefixIcon: const Icon(Icons.category_outlined),
              items: [
                for (final p in booking.plans)
                  AppDropdownOption(
                    value: p.part,
                    title: p.part.label,
                    subtitle: 'Balance ${MoneyText.full(booking.balanceFor(p.part))}',
                  ),
              ],
              onChanged: (part) => setState(() {
                _part = part ?? _part;
                _method = null;
              }),
            ),

          // Value, paid and balance for the chosen part
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _Figure(label: _part.label, value: MoneyText.full(plan.value)),
                _Figure(label: 'Paid', value: MoneyText.full(booking.paidFor(_part))),
                _Figure(label: 'Balance', value: MoneyText.full(_balance), color: AppColors.error),
              ],
            ),
          ),

          AppTextField(
            key: const ValueKey('payment-amount'),
            controller: _amountController,
            label: 'Amount Received (₹)',
            hintText: 'e.g. 2,00,000',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.currency_rupee_rounded),
            validator: _validateAmount,
          ),
          AppDropdown<PaymentMethod>(
            // Rebuilt per part: only loan parts offer Loan Disbursement.
            key: ValueKey('payment-method-${_part.name}'),
            label: 'Payment Method',
            hint: 'Select method',
            value: _method,
            prefixIcon: const Icon(Icons.swap_horiz_rounded),
            items: [
              for (final m in PaymentMethod.values)
                if (m != PaymentMethod.loanDisbursement || plan.mode == PaymentMode.loan)
                  AppDropdownOption(value: m, title: m.label),
            ],
            onChanged: (m) => setState(() => _method = m),
            validator: (m) => m == null ? 'Please select a method.' : null,
          ),
          // Date
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: InkWell(
              key: const ValueKey('payment-date'),
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.lightBorder, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 20, color: AppColors.textSecondaryLight),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Received on ${DateText.shortDate(_date)}',
                        style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimaryLight),
                      ),
                    ),
                    Text(
                      'Change',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppTextField(
            key: const ValueKey('payment-reference'),
            controller: _referenceController,
            label: 'Reference / Note (optional)',
            hintText: 'Cheque no., UTR, receipt no.',
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.receipt_long_outlined),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),

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
                  key: const ValueKey('payment-submit'),
                  text: 'Save Payment',
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

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Figure({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.titleSmall.copyWith(
                color: color ?? AppColors.brandDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
