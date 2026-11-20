import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/lead.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_form_shell.dart';
import '../../../widgets/app_text_field.dart';

/// FollowUpForm records a contact with a lead: when and how, what was
/// discussed, where the lead stands now and when to follow up next.
class FollowUpForm extends StatefulWidget {
  final Lead lead;
  final String newId;
  final String byName;
  final void Function(FollowUp followUp) onSubmit;

  const FollowUpForm({
    super.key,
    required this.lead,
    required this.newId,
    required this.byName,
    required this.onSubmit,
  });

  @override
  State<FollowUpForm> createState() => _FollowUpFormState();
}

class _FollowUpFormState extends State<FollowUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  DateTime _date = _today;
  FollowUpMode _mode = FollowUpMode.call;

  /// A new lead becomes Contacted once someone talks to them.
  late LeadStatus _status = widget.lead.status == LeadStatus.newLead ? LeadStatus.contacted : widget.lead.status;
  bool _schedule = true;
  DateTime _nextDate = _today.add(const Duration(days: 2));
  String? _error;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final next = _schedule && !_status.isClosed ? _nextDate : null;
    String? error;
    if (_date.isAfter(_today)) {
      error = 'A follow-up cannot be dated in the future.';
    } else if (next != null && next.isBefore(_date)) {
      error = 'The next follow-up must be on or after this one.';
    }
    setState(() => _error = error);
    if (error != null) return;

    widget.onSubmit(
      FollowUp(
        id: widget.newId,
        date: _date,
        mode: _mode,
        note: _note.text.trim(),
        status: _status,
        nextDate: next,
        by: widget.byName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      icon: Icons.add_comment_outlined,
      title: 'Add Follow-up',
      subtitle: 'With ${widget.lead.name}',
      submitLabel: 'Save Follow-up',
      submitKey: const ValueKey('follow-up-submit'),
      onSubmit: _submit,
      children: [
        AppDateField(
          key: const ValueKey('follow-up-date'),
          label: 'Contacted on',
          value: _date,
          onChanged: (date) => setState(() => _date = date),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in FollowUpMode.values)
                ChoiceChip(
                  key: ValueKey('follow-up-mode-${mode.name}'),
                  avatar: Icon(
                    mode.icon,
                    size: 16,
                    color: mode == _mode ? AppColors.brandDeep : AppColors.textMutedLight,
                  ),
                  label: Text(mode.label),
                  selected: mode == _mode,
                  onSelected: (_) => setState(() => _mode = mode),
                  selectedColor: AppColors.mint,
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: mode == _mode ? AppColors.brandDeep : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(color: mode == _mode ? AppColors.primary : AppColors.lightBorder),
                  showCheckmark: false,
                ),
            ],
          ),
        ),
        AppTextField(
          key: const ValueKey('follow-up-note'),
          controller: _note,
          label: 'What was discussed',
          hintText: 'e.g. Wants an east facing plot; will visit Sunday',
          maxLines: 3,
          prefixIcon: const Icon(Icons.notes_rounded),
          validator: (v) => (v?.trim() ?? '').isEmpty ? 'Please note what was discussed.' : null,
        ),
        AppDropdown<LeadStatus>(
          key: const ValueKey('follow-up-status'),
          label: 'Lead status now',
          value: _status,
          prefixIcon: const Icon(Icons.flag_outlined),
          items: [
            for (final status in LeadStatus.values)
              AppDropdownOption(
                value: status,
                title: status.label,
                icon: Icon(status.icon, size: 20, color: status.color),
              ),
          ],
          onChanged: (status) => setState(() => _status = status ?? _status),
        ),
        if (_status.isClosed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              _status == LeadStatus.won
                  ? 'Marked Won: no more follow-ups are scheduled.'
                  : 'Marked Lost: no more follow-ups are scheduled.',
              style: AppTypography.caption.copyWith(color: _status.color, fontWeight: FontWeight.w600),
            ),
          )
        else ...[
          SwitchListTile.adaptive(
            key: const ValueKey('follow-up-schedule'),
            contentPadding: EdgeInsets.zero,
            value: _schedule,
            onChanged: (value) => setState(() => _schedule = value),
            title: Text(
              'Schedule the next follow-up',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
            ),
          ),
          if (_schedule)
            AppDateField(
              key: const ValueKey('follow-up-next'),
              label: 'Next follow-up',
              value: _nextDate,
              onChanged: (date) => setState(() => _nextDate = date),
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              key: const ValueKey('follow-up-error'),
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
