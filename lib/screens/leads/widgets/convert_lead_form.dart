import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/customer.dart';
import '../../../models/lead.dart';
import '../../../widgets/app_form_shell.dart';
import '../../../widgets/app_text_field.dart';

/// ConvertLeadForm makes a lead a customer: their details come from the
/// lead and are completed here (address is needed for a customer).
class ConvertLeadForm extends StatefulWidget {
  final Lead lead;
  final String ownerName;
  final void Function(CustomerProfile details) onSubmit;

  const ConvertLeadForm({super.key, required this.lead, required this.ownerName, required this.onSubmit});

  @override
  State<ConvertLeadForm> createState() => _ConvertLeadFormState();
}

class _ConvertLeadFormState extends State<ConvertLeadForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.lead.name);
  late final _mobile = TextEditingController(text: widget.lead.mobile);
  final _alternate = TextEditingController();
  late final _email = TextEditingController(text: widget.lead.email);
  late final _address = TextEditingController(text: widget.lead.area);
  final _occupation = TextEditingController();
  late final _notes = TextEditingController(text: widget.lead.notes);

  @override
  void dispose() {
    for (final c in [_name, _mobile, _alternate, _email, _address, _occupation, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _mobileError(String? value, {bool optional = false}) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (optional && digits.isEmpty) return null;
    final ok = digits.length == 10 || (digits.length == 12 && digits.startsWith('91'));
    return ok ? null : (optional ? 'Enter a 10-digit number, or leave it empty.' : 'Enter a 10-digit mobile number.');
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      CustomerProfile(
        id: '',
        name: _name.text.trim(),
        mobile: _mobile.text.trim(),
        alternateMobile: _alternate.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        occupation: _occupation.text.trim(),
        notes: _notes.text.trim(),
        leadId: widget.lead.id,
        source: widget.lead.source,
        ownerName: widget.ownerName,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFormShell(
      formKey: _formKey,
      icon: Icons.how_to_reg_rounded,
      title: 'Convert to Customer',
      subtitle: 'Check and complete ${widget.lead.name}\'s details',
      submitLabel: 'Convert to Customer',
      submitKey: const ValueKey('convert-submit'),
      onSubmit: _submit,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'They move to Customers, and this lead is marked Won.',
            style: AppTypography.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600),
          ),
        ),
        AppTextField(
          key: const ValueKey('convert-name'),
          controller: _name,
          label: 'Full Name',
          prefixIcon: const Icon(Icons.person_outline_rounded),
          validator: (v) => (v?.trim() ?? '').isEmpty ? "Please enter the customer's name." : null,
        ),
        AppTextField(
          key: const ValueKey('convert-mobile'),
          controller: _mobile,
          label: 'Mobile',
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(Icons.phone_iphone_rounded),
          validator: _mobileError,
        ),
        AppTextField(
          key: const ValueKey('convert-alternate'),
          controller: _alternate,
          label: 'Alternate Mobile (optional)',
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(Icons.phone_rounded),
          validator: (v) => _mobileError(v, optional: true),
        ),
        AppTextField(
          key: const ValueKey('convert-email'),
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
          key: const ValueKey('convert-address'),
          controller: _address,
          label: 'Address',
          hintText: 'House no., street, area, city',
          maxLines: 2,
          prefixIcon: const Icon(Icons.home_outlined),
          validator: (v) => (v?.trim() ?? '').isEmpty ? "Please enter the customer's address." : null,
        ),
        AppTextField(
          key: const ValueKey('convert-occupation'),
          controller: _occupation,
          label: 'Occupation (optional)',
          prefixIcon: const Icon(Icons.work_outline_rounded),
        ),
        AppTextField(
          key: const ValueKey('convert-notes'),
          controller: _notes,
          label: 'Notes (optional)',
          maxLines: 3,
          prefixIcon: const Icon(Icons.sticky_note_2_outlined),
        ),
      ],
    );
  }
}
