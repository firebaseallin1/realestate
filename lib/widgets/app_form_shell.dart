import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/date_text.dart';
import 'app_button.dart';

/// AppFormShell is the frame shared by the add / update forms: a gradient
/// icon, title and subtitle with a close button, the [children] fields,
/// then Cancel and the submit button.
class AppFormShell extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String submitLabel;
  final Key? submitKey;
  final VoidCallback onSubmit;

  const AppFormShell({
    super.key,
    required this.formKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.submitLabel,
    this.submitKey,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
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
          ...children,
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
                  key: submitKey,
                  text: submitLabel,
                  gradient: AppColors.brandGradient,
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AppDateField shows a date and opens a date picker when tapped.
class AppDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightBorder, width: 1.2),
          ),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 20, color: AppColors.textSecondaryLight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$label ${DateText.shortDate(value)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimaryLight),
                ),
              ),
              Text(
                'Change',
                style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
