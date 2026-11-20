import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/app_text_field.dart';

/// PlotForm sets a plot's details after it is drawn, or edits / deletes
/// an existing plot: number, width × length (area shown live), facing,
/// status and an optional price.
class PlotForm extends StatefulWidget {
  final Plot? plot;
  final Rect rect;
  final List<String> takenNumbers;
  final String suggestedNumber;
  final ValueChanged<Plot> onSubmit;
  final VoidCallback? onDelete;

  const PlotForm({
    super.key,
    this.plot,
    required this.rect,
    required this.takenNumbers,
    required this.suggestedNumber,
    required this.onSubmit,
    this.onDelete,
  });

  @override
  State<PlotForm> createState() => _PlotFormState();
}

class _PlotFormState extends State<PlotForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _width;
  late final TextEditingController _length;
  late final TextEditingController _price;
  late PlotFacing _facing;
  late PlotStatus _status;

  bool get _isEdit => widget.plot != null;

  @override
  void initState() {
    super.initState();
    final plot = widget.plot;
    _number = TextEditingController(text: plot?.number ?? widget.suggestedNumber);
    _width = TextEditingController(text: plot == null ? '30' : _fmt(plot.widthFt));
    _length = TextEditingController(text: plot == null ? '40' : _fmt(plot.lengthFt));
    _price = TextEditingController(text: plot?.price == null ? '' : _fmt(plot!.price!));
    _facing = plot?.facing ?? PlotFacing.east;
    _status = plot?.status ?? PlotStatus.available;
    // Live area preview
    _width.addListener(_refresh);
    _length.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _number.dispose();
    _width.dispose();
    _length.dispose();
    _price.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

  String? _sizeValidator(String? value) {
    final n = double.tryParse(value?.trim() ?? '');
    if (n == null || n <= 0) return 'Enter feet';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final priceText = _price.text.trim();

    widget.onSubmit(
      Plot(
        id: widget.plot?.id ?? SiteController.newId(),
        number: _number.text.trim(),
        widthFt: _parse(_width)!,
        lengthFt: _parse(_length)!,
        facing: _facing,
        status: _status,
        price: priceText.isEmpty ? null : double.tryParse(priceText),
        rect: widget.plot?.rect ?? widget.rect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _parse(_width) ?? 0;
    final l = _parse(_length) ?? 0;
    final sqFt = w * l;

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
                child: const Icon(Icons.crop_square_rounded, color: AppColors.pureWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEdit ? 'Edit Plot ${widget.plot!.number}' : 'New Plot',
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
          const SizedBox(height: 14),

          AppTextField(
            controller: _number,
            label: 'Plot Number',
            hintText: 'e.g. 12 or A-12',
            prefixIcon: const Icon(Icons.tag_rounded),
            validator: (value) {
              final number = value?.trim() ?? '';
              if (number.isEmpty) return 'Please enter a plot number.';
              final taken = widget.takenNumbers.any(
                (n) => n.toLowerCase() == number.toLowerCase() && n != widget.plot?.number,
              );
              if (taken) return 'Plot $number already exists.';
              return null;
            },
          ),

          // Size
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _width,
                  label: 'Width (ft)',
                  hintText: '30',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _sizeValidator,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 40, left: 10, right: 10),
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMutedLight),
              ),
              Expanded(
                child: AppTextField(
                  controller: _length,
                  label: 'Length (ft)',
                  hintText: '40',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _sizeValidator,
                ),
              ),
            ],
          ),

          // Area preview
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.square_foot_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Area',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_fmt(sqFt.roundToDouble())} sq ft  •  ${(sqFt / 9).toStringAsFixed(1)} sq yd',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
                  ),
                ),
              ],
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppDropdown<PlotFacing>(
                  label: 'Facing',
                  value: _facing,
                  items: [
                    for (final facing in PlotFacing.values)
                      AppDropdownOption(
                        value: facing,
                        title: facing.label,
                        icon: Transform.rotate(
                          angle: facing.degrees * math.pi / 180,
                          child: Icon(Icons.navigation_rounded, size: 18, color: AppColors.primary),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _facing = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdown<PlotStatus>(
                  label: 'Status',
                  value: _status,
                  items: [
                    for (final status in PlotStatus.values)
                      AppDropdownOption(value: status, title: status.label),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
              ),
            ],
          ),

          AppTextField(
            controller: _price,
            label: 'Price (optional)',
            hintText: 'e.g. 2500000',
            prefixIcon: const Icon(Icons.currency_rupee_rounded),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              final n = double.tryParse(text);
              return n == null || n < 0 ? 'Enter a valid amount' : null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 6),

          // Actions
          Row(
            children: [
              if (widget.onDelete != null) ...[
                IconButton(
                  tooltip: 'Delete plot',
                  onPressed: widget.onDelete,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.errorBg,
                    fixedSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: AppButton.outline(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  text: _isEdit ? 'Save Plot' : 'Add Plot',
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
