import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';

/// LocationForm adds a new location (city or area). Shown in a bottom
/// sheet on mobile and a dialog on web, like the site form.
class LocationForm extends StatefulWidget {
  final List<String> existingLocations;
  final ValueChanged<String> onSubmit;

  const LocationForm({
    super.key,
    required this.existingLocations,
    required this.onSubmit,
  });

  @override
  State<LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Please enter a location name.';
    final exists = widget.existingLocations.any((l) => l.toLowerCase() == name.toLowerCase());
    if (exists) return '$name is already a location.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(_nameController.text.trim());
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
                child: const Icon(Icons.add_location_alt_rounded, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Location',
                      style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                    ),
                    Text(
                      'A new city or area to manage sites in',
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
            controller: _nameController,
            label: 'Location Name',
            hintText: 'e.g. Pune',
            prefixIcon: const Icon(Icons.location_city_rounded),
            textInputAction: TextInputAction.done,
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),

          // Existing locations, for reference
          if (widget.existingLocations.isNotEmpty) ...[
            Text(
              'Existing locations',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final location in widget.existingLocations)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Text(
                      location,
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

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
                  text: 'Add Location',
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
