import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_user.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';

/// UserForm adds a team member with a role and sign-in details. Shown in
/// a bottom sheet on mobile and a dialog on web, like the other forms.
class UserForm extends StatefulWidget {
  final String newId;
  final bool Function(String username) isUsernameTaken;
  final ValueChanged<AppUser> onSubmit;

  const UserForm({
    super.key,
    required this.newId,
    required this.isUsernameTaken,
    required this.onSubmit,
  });

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole? _role;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Please enter a username.';
    if (username.contains(' ')) return 'Usernames cannot contain spaces.';
    if (widget.isUsernameTaken(username)) return '$username is already taken.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      AppUser(
        id: widget.newId,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _role!,
        phone: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add User',
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      'Their role decides the menu they see',
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

          AppTextField(
            key: const ValueKey('user-name'),
            controller: _nameController,
            label: 'Full Name',
            hintText: 'e.g. Anil Kumar',
            prefixIcon: const Icon(Icons.badge_outlined),
            validator: (v) => (v?.trim() ?? '').isEmpty ? 'Please enter a name.' : null,
          ),
          AppDropdown<UserRole>(
            key: const ValueKey('user-role'),
            label: 'Role',
            hint: 'Select a role',
            value: _role,
            prefixIcon: const Icon(Icons.verified_user_outlined),
            items: [
              for (final role in UserRole.values)
                AppDropdownOption(
                  value: role,
                  title: role.label,
                  subtitle: role.description,
                  icon: Icon(role.icon, size: 20, color: role.color),
                ),
            ],
            onChanged: (role) => setState(() => _role = role),
            validator: (role) => role == null ? 'Please select a role.' : null,
          ),
          AppTextField(
            key: const ValueKey('user-username'),
            controller: _usernameController,
            label: 'Username',
            hintText: 'Used to sign in',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            validator: _validateUsername,
          ),
          AppTextField(
            key: const ValueKey('user-password'),
            controller: _passwordController,
            label: 'Password',
            hintText: 'At least 6 characters',
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            validator: (v) => (v ?? '').length < 6 ? 'Password must be at least 6 characters.' : null,
          ),
          AppTextField(
            key: const ValueKey('user-phone'),
            controller: _phoneController,
            label: 'Phone (optional)',
            hintText: 'e.g. 98480 12345',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.phone_outlined),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 6),

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
                  key: const ValueKey('user-submit'),
                  text: 'Add User',
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
