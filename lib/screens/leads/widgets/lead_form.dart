import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../models/lead.dart';
import '../../../models/site.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_form_shell.dart';
import '../../../widgets/app_text_field.dart';

/// LeadForm adds a lead with their basic details, or edits one ([lead]).
/// A new lead can have its first follow-up date set right away.
class LeadForm extends StatefulWidget {
  final Lead? lead;
  final List<Site> sites;
  final String newId;
  final String ownerName;
  final void Function(Lead lead) onSubmit;

  const LeadForm({
    super.key,
    this.lead,
    required this.sites,
    required this.newId,
    required this.ownerName,
    required this.onSubmit,
  });

  @override
  State<LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<LeadForm> {
  final _formKey = GlobalKey<FormState>();
  late final Lead? _editing = widget.lead;
  late final _name = TextEditingController(text: _editing?.name);
  late final _mobile = TextEditingController(text: _editing?.mobile);
  late final _email = TextEditingController(text: _editing?.email);
  late final _area = TextEditingController(text: _editing?.area);
  late final _budget = TextEditingController(text: _editing?.budget == null ? '' : MoneyText.plain(_editing!.budget!));
  late final _notes = TextEditingController(text: _editing?.notes);
  late LeadSource? _source = _editing?.source;

  /// '' while no site is chosen.
  late String _siteId = _editing?.siteId ?? '';
  late BookingType? _interest = _editing?.interest;
  late bool _schedule = _editing == null || _editing.nextFollowUp != null;
  late DateTime _nextFollowUp = _editing?.nextFollowUp ?? _today.add(const Duration(days: 1));

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _closed => _editing?.status.isClosed ?? false;

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _area, _budget, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final site = widget.sites.where((s) => s.id == _siteId).firstOrNull;
    widget.onSubmit(
      Lead(
        id: _editing?.id ?? widget.newId,
        name: _name.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim(),
        area: _area.text.trim(),
        source: _source!,
        siteId: site?.id,
        siteName: site?.name ?? '',
        interest: _interest,
        budget: MoneyText.parse(_budget.text),
        notes: _notes.text.trim(),
        status: _editing?.status ?? LeadStatus.newLead,
        nextFollowUp: _schedule && !_closed ? _nextFollowUp : null,
        ownerName: _editing?.ownerName ?? widget.ownerName,
        createdAt: _editing?.createdAt ?? DateTime.now(),
        followUps: _editing?.followUps ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing != null;

    return AppFormShell(
      formKey: _formKey,
      icon: editing ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
      title: editing ? 'Edit Lead' : 'New Lead',
      subtitle: editing ? 'Update their details' : 'Someone enquiring about a plot',
      submitLabel: editing ? 'Save Changes' : 'Add Lead',
      submitKey: const ValueKey('lead-submit'),
      onSubmit: _submit,
      children: [
        AppTextField(
          key: const ValueKey('lead-name'),
          controller: _name,
          label: 'Name',
          hintText: 'e.g. Suresh Babu',
          prefixIcon: const Icon(Icons.person_outline_rounded),
          validator: (v) => (v?.trim() ?? '').isEmpty ? "Please enter the person's name." : null,
        ),
        AppTextField(
          key: const ValueKey('lead-mobile'),
          controller: _mobile,
          label: 'Mobile',
          hintText: 'e.g. 98480 12345',
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(Icons.phone_iphone_rounded),
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            final ok = digits.length == 10 || (digits.length == 12 && digits.startsWith('91'));
            return ok ? null : 'Enter a 10-digit mobile number.';
          },
        ),
        AppTextField(
          key: const ValueKey('lead-email'),
          controller: _email,
          label: 'Email (optional)',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.mail_outline_rounded),
          validator: (v) {
            final email = v?.trim() ?? '';
            return email.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                ? null
                : 'Enter a valid email, or leave it empty.';
          },
        ),
        AppTextField(
          key: const ValueKey('lead-area'),
          controller: _area,
          label: 'Area / City (optional)',
          prefixIcon: const Icon(Icons.location_on_outlined),
        ),
        AppDropdown<LeadSource>(
          key: const ValueKey('lead-source'),
          label: 'Source',
          hint: 'How did they hear of us?',
          value: _source,
          prefixIcon: const Icon(Icons.campaign_outlined),
          items: [
            for (final source in LeadSource.values)
              AppDropdownOption(
                value: source,
                title: source.label,
                icon: Icon(source.icon, size: 20, color: AppColors.primary),
              ),
          ],
          onChanged: (source) => setState(() => _source = source),
          validator: (source) => source == null ? 'Please choose the source.' : null,
        ),
        AppDropdown<String>(
          key: const ValueKey('lead-site'),
          label: 'Interested Site (optional)',
          value: _siteId,
          prefixIcon: const Icon(Icons.domain_outlined),
          items: [
            const AppDropdownOption(value: '', title: 'Not decided yet'),
            for (final site in widget.sites)
              AppDropdownOption(value: site.id, title: site.name, subtitle: site.location),
          ],
          onChanged: (id) => setState(() => _siteId = id ?? ''),
        ),
        _Label('Looking for'),
        _Choices<BookingType?>(
          keyPrefix: 'lead-interest',
          selected: _interest,
          options: const [
            (null, 'Not sure yet'),
            (BookingType.withoutConstruction, 'Plot only'),
            (BookingType.withConstruction, 'Plot + House'),
          ],
          onSelected: (value) => setState(() => _interest = value),
        ),
        AppTextField(
          key: const ValueKey('lead-budget'),
          controller: _budget,
          label: 'Budget in ₹ (optional)',
          hintText: 'e.g. 25,00,000',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.currency_rupee_rounded),
          validator: (v) => (v?.trim() ?? '').isEmpty || MoneyText.parse(v) != null ? null : 'Enter an amount.',
        ),
        AppTextField(
          key: const ValueKey('lead-notes'),
          controller: _notes,
          label: 'Notes (optional)',
          hintText: 'Preferences, family size, timing…',
          maxLines: 3,
          prefixIcon: const Icon(Icons.sticky_note_2_outlined),
        ),
        if (!_closed) ...[
          SwitchListTile.adaptive(
            key: const ValueKey('lead-schedule'),
            contentPadding: EdgeInsets.zero,
            value: _schedule,
            onChanged: (value) => setState(() => _schedule = value),
            title: Text(
              'Schedule a follow-up',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
            ),
          ),
          if (_schedule)
            AppDateField(
              key: const ValueKey('lead-next'),
              label: 'Follow up on',
              value: _nextFollowUp,
              onChanged: (date) => setState(() => _nextFollowUp = date),
            ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
    ),
  );
}

/// A row of choice chips; one is always chosen.
class _Choices<T> extends StatelessWidget {
  final String keyPrefix;
  final T selected;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  const _Choices({required this.keyPrefix, required this.selected, required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, label) in options)
            ChoiceChip(
              key: ValueKey('$keyPrefix-${value is Enum ? value.name : 'none'}'),
              label: Text(label),
              selected: value == selected,
              onSelected: (_) => onSelected(value),
              selectedColor: AppColors.mint,
              labelStyle: AppTypography.bodySmall.copyWith(
                color: value == selected ? AppColors.brandDeep : AppColors.textSecondaryLight,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(color: value == selected ? AppColors.primary : AppColors.lightBorder),
              showCheckmark: false,
            ),
        ],
      ),
    );
  }
}
