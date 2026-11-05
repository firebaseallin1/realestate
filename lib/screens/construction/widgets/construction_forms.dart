import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../models/construction.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_form_shell.dart';
import '../../../widgets/app_text_field.dart';

String? _requiredText(String? v, String message) => (v?.trim() ?? '').isEmpty ? message : null;

String? _positiveAmount(String? v, String message) {
  final amount = MoneyText.parse(v);
  return amount == null || amount <= 0 ? message : null;
}

/// StageForm updates a stage's status, progress and note.
class StageForm extends StatefulWidget {
  final ConstructionStage stage;
  final void Function(StageStatus status, int progress, String note) onSubmit;

  const StageForm({super.key, required this.stage, required this.onSubmit});

  @override
  State<StageForm> createState() => _StageFormState();
}

class _StageFormState extends State<StageForm> {
  final _formKey = GlobalKey<FormState>();
  late StageStatus _status = widget.stage.status;
  late double _progress = widget.stage.progress.clamp(1, 99).toDouble();
  late final _noteController = TextEditingController(text: widget.stage.note);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      icon: Icons.timeline_rounded,
      title: widget.stage.name,
      subtitle: 'Update the stage status and progress',
      submitLabel: 'Save Stage',
      submitKey: const ValueKey('stage-submit'),
      onSubmit: () => widget.onSubmit(_status, _progress.round(), _noteController.text.trim()),
      children: [
        Text('Status', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in StageStatus.values)
              ChoiceChip(
                key: ValueKey('stage-status-${status.name}'),
                label: Text(status.label),
                avatar: Icon(status.icon, size: 16, color: _status == status ? AppColors.pureWhite : status.color),
                selected: _status == status,
                showCheckmark: false,
                selectedColor: status.color,
                labelStyle: AppTypography.bodySmall.copyWith(
                  color: _status == status ? AppColors.pureWhite : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _status = status),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_status == StageStatus.inProgress) ...[
          Text(
            'Progress: ${_progress.round()}%',
            style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
          ),
          Slider(
            key: const ValueKey('stage-progress'),
            value: _progress,
            min: 1,
            max: 99,
            divisions: 98,
            label: '${_progress.round()}%',
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _progress = v),
          ),
          const SizedBox(height: 8),
        ],
        AppTextField(
          key: const ValueKey('stage-note'),
          controller: _noteController,
          label: 'Note (optional)',
          hintText: 'e.g. Waiting for curing',
          prefixIcon: const Icon(Icons.notes_rounded),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

/// DailyWorkForm records today's update: stage, work done and the workers
/// present (their attendance earns the day's wage).
class DailyWorkForm extends StatefulWidget {
  final ConstructionProject project;
  final String newId;
  final String updatedBy;
  final ValueChanged<DailyWork> onSubmit;

  const DailyWorkForm({
    super.key,
    required this.project,
    required this.newId,
    required this.updatedBy,
    required this.onSubmit,
  });

  @override
  State<DailyWorkForm> createState() => _DailyWorkFormState();
}

class _DailyWorkFormState extends State<DailyWorkForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  late String? _stageId = (widget.project.currentStage ?? widget.project.stages.last).id;
  final Set<String> _present = {};
  DateTime _date = DateTime.now();
  bool _showWorkerError = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();
    setState(() => _showWorkerError = _present.isEmpty);
    if (!valid || _present.isEmpty) return;
    widget.onSubmit(
      DailyWork(
        id: widget.newId,
        date: _date,
        stageId: _stageId!,
        description: _descriptionController.text.trim(),
        workerIds: _present.toList(),
        updatedBy: widget.updatedBy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workers = widget.project.workers;
    final cost = _present.fold<double>(0, (sum, id) => sum + (widget.project.workerById(id)?.dailyWage ?? 0));

    return AppFormShell(
      formKey: _formKey,
      icon: Icons.today_rounded,
      title: 'Daily Work Update',
      subtitle: 'What was done today and who worked',
      submitLabel: 'Save Update',
      submitKey: const ValueKey('daily-submit'),
      onSubmit: _submit,
      children: [
        AppDateField(label: 'Work on', value: _date, onChanged: (d) => setState(() => _date = d)),
        AppDropdown<String>(
          key: const ValueKey('daily-stage'),
          label: 'Stage',
          value: _stageId,
          prefixIcon: const Icon(Icons.timeline_rounded),
          items: [
            for (final s in widget.project.stages) AppDropdownOption(value: s.id, title: s.name, subtitle: s.status.label),
          ],
          onChanged: (id) => setState(() => _stageId = id),
          validator: (id) => id == null ? 'Please select a stage.' : null,
        ),
        AppTextField(
          key: const ValueKey('daily-description'),
          controller: _descriptionController,
          label: 'Work Done',
          hintText: 'e.g. First floor slab shuttering',
          prefixIcon: const Icon(Icons.construction_rounded),
          maxLines: 2,
          validator: (v) => _requiredText(v, 'Please describe the work done.'),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Workers Present (${_present.length})',
                style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
              ),
            ),
            if (workers.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  _present.length == workers.length ? _present.clear() : _present.addAll(workers.map((w) => w.id));
                }),
                child: Text(_present.length == workers.length ? 'Clear' : 'Select all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (workers.isEmpty)
          Text(
            'Add workers in the Workers tab first.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in workers)
                FilterChip(
                  key: ValueKey('daily-worker-${w.id}'),
                  label: Text('${w.name} · ${w.trade.label}'),
                  selected: _present.contains(w.id),
                  selectedColor: AppColors.mint,
                  checkmarkColor: AppColors.brandDeep,
                  onSelected: (on) => setState(() {
                    on ? _present.add(w.id) : _present.remove(w.id);
                    _showWorkerError = false;
                  }),
                ),
            ],
          ),
        if (_showWorkerError && workers.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Select the workers present.', style: AppTypography.caption.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 12),
        Text(
          "Today's wages: ${MoneyText.full(cost)}",
          style: AppTypography.bodySmall.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// WorkerForm adds a worker with their trade and daily wage.
class WorkerForm extends StatefulWidget {
  final String newId;
  final ValueChanged<Worker> onSubmit;

  const WorkerForm({super.key, required this.newId, required this.onSubmit});

  @override
  State<WorkerForm> createState() => _WorkerFormState();
}

class _WorkerFormState extends State<WorkerForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _wageController = TextEditingController();
  final _phoneController = TextEditingController();
  WorkerTrade? _trade;

  @override
  void dispose() {
    _nameController.dispose();
    _wageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      Worker(
        id: widget.newId,
        name: _nameController.text.trim(),
        trade: _trade!,
        dailyWage: MoneyText.parse(_wageController.text)!,
        phone: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      icon: Icons.person_add_alt_1_rounded,
      title: 'Add Worker',
      subtitle: 'Wages are counted from daily attendance',
      submitLabel: 'Add Worker',
      submitKey: const ValueKey('worker-submit'),
      onSubmit: _submit,
      children: [
        AppTextField(
          key: const ValueKey('worker-name'),
          controller: _nameController,
          label: 'Worker Name',
          hintText: 'Full name',
          prefixIcon: const Icon(Icons.badge_outlined),
          validator: (v) => _requiredText(v, 'Please enter a name.'),
        ),
        AppDropdown<WorkerTrade>(
          key: const ValueKey('worker-trade'),
          label: 'Trade',
          hint: 'Select trade',
          value: _trade,
          prefixIcon: const Icon(Icons.handyman_outlined),
          items: [for (final t in WorkerTrade.values) AppDropdownOption(value: t, title: t.label)],
          onChanged: (t) => setState(() => _trade = t),
          validator: (t) => t == null ? 'Please select a trade.' : null,
        ),
        AppTextField(
          key: const ValueKey('worker-wage'),
          controller: _wageController,
          label: 'Daily Wage (₹)',
          hintText: 'e.g. 900',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.currency_rupee_rounded),
          validator: (v) => _positiveAmount(v, 'Enter the daily wage.'),
        ),
        AppTextField(
          key: const ValueKey('worker-phone'),
          controller: _phoneController,
          label: 'Phone (optional)',
          hintText: 'Mobile number',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.phone_outlined),
          onFieldSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

/// MaterialForm records material received at site, or edits [material].
class MaterialForm extends StatefulWidget {
  final String newId;
  final MaterialEntry? material;

  /// The least the amount can come to, e.g. what is already paid on it.
  final double minAmount;

  /// Off for an item of a bill, where the bill holds these for all its items.
  final bool askSupplierAndDate;
  final ValueChanged<MaterialEntry> onSubmit;

  const MaterialForm({
    super.key,
    required this.newId,
    this.material,
    this.minAmount = 0,
    this.askSupplierAndDate = true,
    required this.onSubmit,
  });

  @override
  State<MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends State<MaterialForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.material?.name);
  late final _quantityController = TextEditingController(text: _amountText(widget.material?.quantity));
  late final _rateController = TextEditingController(text: _amountText(widget.material?.rate));
  late final _supplierController = TextEditingController(text: widget.material?.supplier);
  late String _unit = widget.material?.unit ?? MaterialEntry.units.first;
  late DateTime _date = widget.material?.date ?? DateTime.now();

  bool get _editing => widget.material != null;

  /// Scanned items can have no quantity or rate yet: those start empty.
  static String _amountText(double? value) => value == null || value <= 0 ? '' : MoneyText.plain(value);

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      MaterialEntry(
        id: widget.newId,
        date: _date,
        name: _nameController.text.trim(),
        quantity: MoneyText.parse(_quantityController.text)!,
        unit: _unit,
        rate: MoneyText.parse(_rateController.text)!,
        supplier: _supplierController.text.trim(),
        billId: widget.material?.billId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = (MoneyText.parse(_quantityController.text) ?? 0) * (MoneyText.parse(_rateController.text) ?? 0);

    return AppFormShell(
      formKey: _formKey,
      icon: Icons.inventory_2_rounded,
      title: _editing ? 'Edit Material' : 'Add Material',
      subtitle: 'Material received at site',
      submitLabel: _editing ? 'Save Changes' : 'Add Material',
      submitKey: const ValueKey('material-submit'),
      onSubmit: _submit,
      children: [
        AppTextField(
          key: const ValueKey('material-name'),
          controller: _nameController,
          label: 'Material',
          hintText: 'e.g. Cement (OPC 53)',
          prefixIcon: const Icon(Icons.category_outlined),
          validator: (v) => _requiredText(v, 'Please enter the material.'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                key: const ValueKey('material-quantity'),
                controller: _quantityController,
                label: 'Quantity',
                hintText: 'e.g. 200',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) => _positiveAmount(v, 'Enter quantity.'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppDropdown<String>(
                key: const ValueKey('material-unit'),
                label: 'Unit',
                value: _unit,
                items: [for (final u in MaterialEntry.units) AppDropdownOption(value: u, title: u)],
                onChanged: (u) => setState(() => _unit = u ?? _unit),
              ),
            ),
          ],
        ),
        AppTextField(
          key: const ValueKey('material-rate'),
          controller: _rateController,
          label: 'Rate per $_unit (₹)',
          hintText: 'e.g. 380',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: const Icon(Icons.currency_rupee_rounded),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final missing = _positiveAmount(v, 'Enter the rate.');
            if (missing != null) return missing;
            return amount < widget.minAmount
                ? '${MoneyText.exact(widget.minAmount)} is already paid on this material.'
                : null;
          },
        ),
        if (widget.askSupplierAndDate) ...[
          AppTextField(
            key: const ValueKey('material-supplier'),
            controller: _supplierController,
            label: 'Supplier (optional)',
            hintText: 'e.g. Sri Sai Traders',
            prefixIcon: const Icon(Icons.storefront_outlined),
          ),
          AppDateField(label: 'Received on', value: _date, onChanged: (d) => setState(() => _date = d)),
        ],
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Amount',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                MoneyText.full(amount),
                style: AppTypography.titleMedium.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ExpensePaymentForm pays a worker's wages or a material bill, up to
/// what is due.
class ExpensePaymentForm extends StatefulWidget {
  final ExpenseKind kind;
  final String targetId;
  final String targetName;
  final double due;
  final String newId;
  final ValueChanged<ExpensePayment> onSubmit;

  const ExpensePaymentForm({
    super.key,
    required this.kind,
    required this.targetId,
    required this.targetName,
    required this.due,
    required this.newId,
    required this.onSubmit,
  });

  @override
  State<ExpensePaymentForm> createState() => _ExpensePaymentFormState();
}

class _ExpensePaymentFormState extends State<ExpensePaymentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController =
      TextEditingController(text: widget.due > 0 ? MoneyText.plain(widget.due) : '');
  final _referenceController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      ExpensePayment(
        id: widget.newId,
        kind: widget.kind,
        targetId: widget.targetId,
        amount: MoneyText.parse(_amountController.text)!,
        date: _date,
        method: _method,
        reference: _referenceController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      icon: widget.kind.icon,
      title: widget.kind.label,
      subtitle: '${widget.targetName} · due ${MoneyText.full(widget.due)}',
      submitLabel: 'Save Payment',
      submitKey: const ValueKey('expense-submit'),
      onSubmit: _submit,
      children: [
        AppTextField(
          key: const ValueKey('expense-amount'),
          controller: _amountController,
          label: 'Amount Paid (₹)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: const Icon(Icons.currency_rupee_rounded),
          validator: (v) {
            final amount = MoneyText.parse(v);
            if (amount == null || amount <= 0) return 'Enter the amount paid.';
            if (amount > widget.due) return 'More than the ${MoneyText.full(widget.due)} due.';
            return null;
          },
        ),
        AppDropdown<PaymentMethod>(
          key: const ValueKey('expense-method'),
          label: 'Payment Method',
          value: _method,
          prefixIcon: const Icon(Icons.swap_horiz_rounded),
          items: [
            for (final m in PaymentMethod.values)
              if (m != PaymentMethod.loanDisbursement) AppDropdownOption(value: m, title: m.label),
          ],
          onChanged: (m) => setState(() => _method = m ?? _method),
        ),
        AppDateField(label: 'Paid on', value: _date, onChanged: (d) => setState(() => _date = d)),
        AppTextField(
          key: const ValueKey('expense-reference'),
          controller: _referenceController,
          label: 'Reference / Note (optional)',
          hintText: 'Bill no., UTR, cheque no.',
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.receipt_long_outlined),
          onFieldSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}
