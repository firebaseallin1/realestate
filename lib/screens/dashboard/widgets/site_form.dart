import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/site.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_file_field.dart';
import '../../../widgets/app_search_dropdown.dart';
import '../../../widgets/app_text_field.dart';

/// SiteForm adds a new site or edits an existing one, in two steps: the
/// owner and land areas, then Next to the site's details. The same form is
/// shown in a bottom sheet on mobile and a dialog on web.
class SiteForm extends StatefulWidget {
  final Site? site;
  final List<String> existingLocations;
  final ValueChanged<Site> onSubmit;

  const SiteForm({
    super.key,
    this.site,
    required this.existingLocations,
    required this.onSubmit,
  });

  @override
  State<SiteForm> createState() => _SiteFormState();
}

class _SiteFormState extends State<SiteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ownerController;
  late final TextEditingController _totalAreaController;
  late final TextEditingController _salesAreaController;
  late final TextEditingController _roadAreaController;
  late final TextEditingController _gardenAreaController;
  late final TextEditingController _otherAreaController;
  late final TextEditingController _nameController;
  String? _location;
  late final TextEditingController _totalController;
  late final TextEditingController _soldController;
  late final TextEditingController _bookedController;
  late SiteType _type;
  late SiteStatus _status;
  SiteFile? _siteMap;
  SiteFile? _brochure;

  /// False on the first step (owner and land), true on the site's details.
  bool _onDetailsStep = false;

  bool get _isEdit => widget.site != null;

  /// A site with a drawn layout takes its unit counts from the plots.
  bool get _unitsFromLayout => widget.site?.hasLayout ?? false;

  /// Older sites have no owner or areas; editing them should not force it.
  bool get _landDetailsRequired => !_isEdit || widget.site!.hasLandDetails;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _ownerController = TextEditingController(text: site?.ownerName ?? '');
    _totalAreaController = TextEditingController(text: _areaText(site?.totalArea));
    _salesAreaController = TextEditingController(text: _areaText(site?.salesArea));
    _roadAreaController = TextEditingController(text: _areaText(site?.roadArea));
    _gardenAreaController = TextEditingController(text: _areaText(site?.gardenArea));
    _otherAreaController = TextEditingController(text: _areaText(site?.otherArea));
    _nameController = TextEditingController(text: site?.name ?? '');
    _location = site?.location;
    _totalController = TextEditingController(text: site != null ? '${site.totalUnits}' : '');
    _soldController = TextEditingController(text: '${site?.soldUnits ?? 0}');
    _bookedController = TextEditingController(text: '${site?.bookedUnits ?? 0}');
    _type = site?.type ?? SiteType.plots;
    _status = site?.status ?? SiteStatus.upcoming;
    _siteMap = site?.siteMap;
    _brochure = site?.brochure;
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _totalAreaController.dispose();
    _salesAreaController.dispose();
    _roadAreaController.dispose();
    _gardenAreaController.dispose();
    _otherAreaController.dispose();
    _nameController.dispose();
    _totalController.dispose();
    _soldController.dispose();
    _bookedController.dispose();
    super.dispose();
  }

  static String _areaText(double? area) => area == null || area <= 0 ? '' : MoneyText.plain(area);

  double _area(TextEditingController c) => MoneyText.parse(c.text) ?? 0;

  /// What the areas below the total add up to.
  double get _allocatedArea =>
      _area(_salesAreaController) +
      _area(_roadAreaController) +
      _area(_gardenAreaController) +
      _area(_otherAreaController);

  /// Part of the total not given to sales, roads, garden or other yet.
  double get _balanceArea => _area(_totalAreaController) - _allocatedArea;

  /// More allocated than the total, allowing for rounding of decimals.
  bool get _overAllocated => _balanceArea < -0.005;

  String? _areaValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final area = MoneyText.parse(value);
    return area == null || area < 0 ? 'Enter a number' : null;
  }

  String? _totalAreaValidator(String? value) {
    if ((value ?? '').trim().isNotEmpty) {
      final error = _areaValidator(value);
      if (error != null) return error;
    }
    final total = MoneyText.parse(value) ?? 0;
    if (total <= 0 && _landDetailsRequired) return 'Please enter the total area.';
    if (_overAllocated) return 'Less than the areas below';
    return null;
  }

  /// Validates only this step: the other step's fields are not on screen.
  void _goToDetails() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _onDetailsStep = true);
    Scrollable.maybeOf(context)?.position.jumpTo(0);
  }

  void _backToLand() {
    FocusScope.of(context).unfocus();
    setState(() => _onDetailsStep = false);
    Scrollable.maybeOf(context)?.position.jumpTo(0);
  }

  int _parse(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  String? _unitValidator(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null || n < 0) return 'Enter a number';
    return null;
  }

  /// Reuses the existing spelling of a location typed in another case,
  /// so "hyderabad" and "Hyderabad" stay one location.
  String _normalizedLocation() {
    final typed = (_location ?? '').trim();
    for (final existing in widget.existingLocations) {
      if (existing.toLowerCase() == typed.toLowerCase()) return existing;
    }
    return typed;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final site = Site(
      id: widget.site?.id ?? SiteController.newId(),
      name: _nameController.text.trim(),
      location: _normalizedLocation(),
      type: _type,
      status: _status,
      totalUnits: _parse(_totalController),
      soldUnits: _parse(_soldController),
      bookedUnits: _parse(_bookedController),
      siteMap: _siteMap,
      brochure: _brochure,
      ownerName: _ownerController.text.trim(),
      totalArea: _area(_totalAreaController),
      salesArea: _area(_salesAreaController),
      roadArea: _area(_roadAreaController),
      gardenArea: _area(_gardenAreaController),
      otherArea: _area(_otherAreaController),
    );
    // Keep the drawn layout (and its unit counts) when editing.
    final plots = widget.site?.plots ?? const <Plot>[];
    widget.onSubmit(plots.isEmpty ? site : site.withPlots(plots));
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
              Expanded(
                child: Text(
                  _isEdit ? 'Edit Site' : 'Add New Site',
                  style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _StepIndicator(onDetailsStep: _onDetailsStep),
          const SizedBox(height: 16),

          if (_onDetailsStep) ..._buildDetailsStep() else ..._buildLandStep(),
          const SizedBox(height: 6),

          // Actions
          Row(
            children: [
              Expanded(
                child: _onDetailsStep
                    ? AppButton.outline(
                        key: const ValueKey('site-back'),
                        text: 'Back',
                        onPressed: _backToLand,
                      )
                    : AppButton.outline(
                        text: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _onDetailsStep
                    ? AppButton.primary(
                        text: _isEdit ? 'Save Changes' : 'Add Site',
                        gradient: AppColors.brandGradient,
                        onPressed: _submit,
                      )
                    : AppButton.primary(
                        key: const ValueKey('site-next'),
                        text: 'Next',
                        gradient: AppColors.brandGradient,
                        onPressed: _goToDetails,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLandStep() {
    return [
      AppTextField(
        key: const ValueKey('site-owner'),
        controller: _ownerController,
        label: 'Site Owner Name',
        hintText: 'e.g. Ramesh Kumar',
        prefixIcon: const Icon(Icons.person_outline_rounded),
        validator: (value) => (value ?? '').trim().isEmpty && _landDetailsRequired
            ? 'Please enter the owner\'s name.'
            : null,
      ),
      _areaField(
        key: 'site-total-area',
        controller: _totalAreaController,
        label: 'Total Area (sq yd)',
        hint: 'e.g. 1,20,000',
        icon: Icons.landscape_outlined,
        validator: _totalAreaValidator,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _areaField(
              key: 'site-sales-area',
              controller: _salesAreaController,
              label: 'Sales Area (sq yd)',
              hint: '0',
              icon: Icons.sell_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _areaField(
              key: 'site-road-area',
              controller: _roadAreaController,
              label: 'Road Area (sq yd)',
              hint: '0',
              icon: Icons.add_road_rounded,
            ),
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _areaField(
              key: 'site-garden-area',
              controller: _gardenAreaController,
              label: 'Garden Area (sq yd)',
              hint: '0',
              icon: Icons.park_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _areaField(
              key: 'site-other-area',
              controller: _otherAreaController,
              label: 'Other Area (sq yd)',
              hint: 'Amenities etc.',
              icon: Icons.category_outlined,
            ),
          ),
        ],
      ),
      _buildBalance(),
    ];
  }

  Widget _areaField({
    required String key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return AppTextField(
      key: ValueKey(key),
      controller: controller,
      label: label,
      hintText: hint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: Icon(icon),
      onChanged: (_) => setState(() {}),
      validator: validator ?? _areaValidator,
    );
  }

  /// The land left to allocate, turning red once the parts exceed the total.
  Widget _buildBalance() {
    final color = _overAllocated ? AppColors.error : AppColors.brandDeep;

    return Container(
      key: const ValueKey('site-area-balance'),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _overAllocated ? AppColors.error.withValues(alpha: 0.08) : AppColors.mint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _overAllocated ? 'Over total area by' : 'Balance Area',
              style: AppTypography.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${MoneyText.grouped(_balanceArea.abs())} sq yd',
            style: AppTypography.titleSmall.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailsStep() {
    return [
      AppTextField(
        controller: _nameController,
        label: 'Site Name',
        hintText: 'e.g. Kaira Green Meadows',
        prefixIcon: const Icon(Icons.domain_rounded),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Please enter a site name.' : null,
      ),

      // Location: searchable dropdown; a new city can be added from the search.
      AppSearchDropdown(
        key: const ValueKey('site-location'),
        label: 'Location',
        hintText: 'Select a location',
        searchHint: 'Search locations',
        prefixIcon: const Icon(Icons.location_on_outlined),
        items: widget.existingLocations,
        value: _location,
        allowCustom: true,
        customLabel: (query) => 'Add "$query" as new location',
        onChanged: (value) => setState(() => _location = value),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Please select a location.' : null,
      ),

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppDropdown<SiteType>(
              label: 'Type',
              value: _type,
              items: [
                for (final type in SiteType.values)
                  AppDropdownOption(
                    value: type,
                    title: type.label,
                    icon: Icon(type.icon, size: 18, color: AppColors.primary),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppDropdown<SiteStatus>(
              label: 'Status',
              value: _status,
              items: [
                for (final status in SiteStatus.values)
                  AppDropdownOption(value: status, title: status.label),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
          ),
        ],
      ),

      // Unit inventory
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              controller: _totalController,
              label: 'Total Units',
              hintText: '0',
              keyboardType: TextInputType.number,
              readOnly: _unitsFromLayout,
              validator: (value) {
                final error = _unitValidator(value);
                if (error != null) return error;
                if (_parse(_soldController) + _parse(_bookedController) > _parse(_totalController)) {
                  return 'Too few units';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppTextField(
              controller: _soldController,
              label: 'Sold',
              hintText: '0',
              keyboardType: TextInputType.number,
              readOnly: _unitsFromLayout,
              validator: _unitValidator,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppTextField(
              controller: _bookedController,
              label: 'Booked',
              hintText: '0',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: _unitValidator,
              readOnly: _unitsFromLayout,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      if (_unitsFromLayout)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unit counts come from the ${widget.site!.plots.length} plots in the layout.',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),

      // Attachments
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(
              'ATTACHMENTS',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: AppColors.lightBorder)),
          ],
        ),
      ),
      AppFileField(
        key: const ValueKey('site-map-file'),
        label: 'Site Map',
        hint: 'Upload site map',
        icon: Icons.map_outlined,
        allowedExtensions: SiteFile.imageExtensions,
        file: _siteMap,
        onChanged: (file) => setState(() => _siteMap = file),
      ),
      AppFileField(
        key: const ValueKey('brochure-file'),
        label: 'Brochure',
        hint: 'Upload brochure',
        icon: Icons.menu_book_outlined,
        allowedExtensions: const ['pdf', ...SiteFile.imageExtensions],
        file: _brochure,
        onChanged: (file) => setState(() => _brochure = file),
      ),
    ];
  }
}

/// "Step 1 of 2" with the step's name and a two-part progress bar.
class _StepIndicator extends StatelessWidget {
  final bool onDetailsStep;

  const _StepIndicator({required this.onDetailsStep});

  @override
  Widget build(BuildContext context) {
    Widget bar(bool done) => Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: done ? AppColors.primary : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          onDetailsStep ? 'Step 2 of 2 · Site Details' : 'Step 1 of 2 · Owner & Land',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            bar(true),
            const SizedBox(width: 6),
            bar(onDetailsStep),
          ],
        ),
      ],
    );
  }
}
