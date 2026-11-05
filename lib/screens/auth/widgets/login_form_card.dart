import 'package:flutter/material.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';

/// LoginFormCard is the single login form shared by the mobile and web
/// layouts: a sage accent strip, welcome header, error banner, username,
/// password, the login button and a secure sign-in note.
/// Change the form here and both layouts update.
class LoginFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final AuthController authController;
  final VoidCallback onSubmit;

  const LoginFormCard({
    super.key,
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.authController,
    required this.onSubmit,
  });

  /// Width cap for the card (and the brand above it on mobile), kept
  /// narrow so the form reads tall and slim rather than wide.
  static const double maxWidth = 360;

  /// Taller inputs for the login screen, on a soft mint-white fill.
  static const _fieldPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 20);
  static const _fieldGap = EdgeInsets.only(bottom: 22);
  static const _fieldFill = AppColors.offWhite;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.14),
            blurRadius: 60,
            offset: const Offset(0, 28),
          ),
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sage accent strip
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brandDeep, AppColors.sage, AppColors.sageMid, AppColors.mint],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),

                  // Error Banner if present
                  if (authController.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authController.errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Username
                  AppTextField(
                    controller: usernameController,
                    label: 'Username',
                    hintText: 'Enter your username',
                    keyboardType: TextInputType.text,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    contentPadding: _fieldPadding,
                    fillColor: _fieldFill,
                    margin: _fieldGap,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username.';
                      }
                      return null;
                    },
                  ),

                  // Password
                  AppTextField(
                    controller: passwordController,
                    label: 'Password',
                    hintText: 'Enter your password',
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    textInputAction: TextInputAction.done,
                    contentPadding: _fieldPadding,
                    fillColor: _fieldFill,
                    margin: _fieldGap,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password.';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => onSubmit(),
                  ),
                  const SizedBox(height: 8),

                  // Login Button
                  AppButton.primary(
                    text: 'Login',
                    height: 58,
                    gradient: AppColors.brandGradient,
                    isLoading: authController.isLoading,
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    iconTrailing: true,
                    onPressed: onSubmit,
                  ),
                  const SizedBox(height: 20),

                  // Secure sign-in note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Secure sign-in for Kaira team members',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandDark.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.lock_person_rounded, color: AppColors.pureWhite, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sign in to manage your properties',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
