import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/location_map.dart';

/// LocationForm adds a new location (city or area). Shown in a bottom
/// sheet on mobile and a dialog on web, like the site form. A spot can be
/// chosen on the map; the device's position is captured to start with.
class LocationForm extends StatefulWidget {
  final List<String> existingLocations;
  final void Function(String name, MapPoint? point) onSubmit;

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
  MapPoint? _point;

  /// The city last filled in from the map, so moving the pin can update it.
  String? _mapCity;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Please enter a city name.';
    final exists = widget.existingLocations.any((l) => l.toLowerCase() == name.toLowerCase());
    if (exists) return '$name is already a location.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(_nameController.text.trim(), _point);
  }

  Future<void> _chooseOnMap() async {
    final typed = _nameController.text.trim();
    final picked = await pickMapPoint(
      context,
      initial: _point,
      title: typed.isEmpty ? 'Choose on map' : typed,
    );
    if (picked == null || !mounted) return;
    setState(() => _point = picked.point);
    // Fill in the city from the map, unless the user typed their own.
    final city = picked.placeName;
    final current = _nameController.text.trim();
    if (city != null && (current.isEmpty || current == _mapCity)) {
      _nameController.text = city;
      _mapCity = city;
    }
  }

  Widget _mapSection() {
    final point = _point;
    if (point == null) {
      return OutlinedButton.icon(
        onPressed: _chooseOnMap,
        icon: const Icon(Icons.map_outlined),
        label: const Text('Choose on map (optional)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocationMapPreview(point: point, height: 140, onTap: _chooseOnMap),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                point.label,
                style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
              ),
            ),
            TextButton(onPressed: _chooseOnMap, child: const Text('Change')),
            TextButton(
              onPressed: () => setState(() => _point = null),
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
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
                      'A new city to manage sites in',
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
            controller: _nameController,
            label: 'City',
            hintText: 'e.g. Pune',
            prefixIcon: const Icon(Icons.location_city_rounded),
            textInputAction: TextInputAction.done,
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),

          _mapSection(),
          const SizedBox(height: 14),

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
