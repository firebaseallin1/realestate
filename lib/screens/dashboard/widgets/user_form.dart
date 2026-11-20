import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_user.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';

/// UserForm adds a team member with a role and sign-in details, or edits
/// one ([user]). Shown in a bottom sheet on mobile and a dialog on web, like
/// the other forms. The callbacks save and return an error to show, or null
/// on success.
class UserForm extends StatefulWidget {
  final bool Function(String username) isUsernameTaken;
  final Future<String?> Function(NewUser user) onSubmit;

  /// The account being edited; null adds a new one.
  final AppUser? user;
  final Future<String?> Function(UserChanges changes)? onUpdate;

  /// Your own role cannot be changed (you would lose the Users page).
  final bool roleLocked;

  const UserForm({
    super.key,
    required this.isUsernameTaken,
    required this.onSubmit,
    this.user,
    this.onUpdate,
    this.roleLocked = false,
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
  bool _saving = false;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user != null) {
      _nameController.text = user.name;
      _usernameController.text = user.username;
      _phoneController.text = user.phone;
      _role = user.role;
    }
  }

  /// Shown in the form: a snackbar would sit hidden behind the dialog or sheet.
  String? _error;

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

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = _editing
        ? await widget.onUpdate!(
            UserChanges(
              name: _nameController.text.trim(),
              role: _role!,
              phone: _phoneController.text.trim(),
              password: _passwordController.text,
            ),
          )
        : await widget.onSubmit(
            NewUser(
              name: _nameController.text.trim(),
              username: _usernameController.text.trim(),
              password: _passwordController.text,
              role: _role!,
              phone: _phoneController.text.trim(),
            ),
          );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
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
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  _editing ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded,
                  color: AppColors.pureWhite,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editing ? 'Edit User' : 'Add User',
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      _editing ? 'Update their details, role or password' : 'Their role decides the menu they see',
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
            enabled: !widget.roleLocked,
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
            enabled: !_editing,
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            validator: _editing ? null : _validateUsername,
          ),
          AppTextField(
            key: const ValueKey('user-password'),
            controller: _passwordController,
            label: _editing ? 'New Password (optional)' : 'Password',
            hintText: _editing ? 'Leave blank to keep the current one' : 'At least 8 characters',
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            validator: (v) {
              final password = v ?? '';
              if (_editing && password.isEmpty) return null;
              return password.length < 8 ? 'Password must be at least 8 characters.' : null;
            },
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
          if (_error != null)
            Padding(
              key: const ValueKey('user-form-error'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ),
          const SizedBox(height: 6),

          // Actions
          Row(
            children: [
              Expanded(
                child: AppButton.outline(text: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  key: const ValueKey('user-submit'),
                  text: _editing ? 'Save Changes' : 'Add User',
                  isLoading: _saving,
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
