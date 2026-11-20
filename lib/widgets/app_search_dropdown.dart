import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive.dart';

/// AppSearchDropdown is a dropdown whose list has a search box. It looks
/// like [AppTextField] and works inside a [Form] (validator included).
///
/// On wide screens the list opens as a panel anchored under the field; on
/// phones it opens as a bottom sheet so the keyboard never hides it.
/// With [allowCustom], a search with no exact match offers to use the
/// typed text as a new value.
class AppSearchDropdown extends StatefulWidget {
  final String? label;
  final String hintText;
  final String searchHint;
  final Widget? prefixIcon;
  final List<String> items;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final bool allowCustom;
  final String Function(String query)? customLabel;
  final EdgeInsetsGeometry? margin;

  const AppSearchDropdown({
    super.key,
    this.label,
    this.hintText = 'Select',
    this.searchHint = 'Search',
    this.prefixIcon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.allowCustom = false,
    this.customLabel,
    this.margin,
  });

  @override
  State<AppSearchDropdown> createState() => _AppSearchDropdownState();
}

class _AppSearchDropdownState extends State<AppSearchDropdown> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  double _fieldWidth = 0;

  bool get _isOpen => _portal.isShowing;

  @override
  void didUpdateWidget(covariant AppSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the form field in step when the parent changes the value.
    if (widget.value != oldWidget.value && _fieldKey.currentState?.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fieldKey.currentState?.didChange(widget.value);
      });
    }
  }

  void _pick(String value) {
    _close();
    final field = _fieldKey.currentState;
    field?.didChange(value);
    // A pick fixes a "please select" error at once, without resubmitting.
    if (field != null && field.hasError) field.validate();
    widget.onChanged(value);
  }

  void _close() {
    if (_isOpen) setState(_portal.hide);
  }

  Future<void> _open() async {
    FocusScope.of(context).unfocus();

    if (Responsive.isWeb(context)) {
      setState(_portal.show);
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: _SearchPanel(
            key: const ValueKey('search-dropdown-panel'),
            title: widget.label,
            items: widget.items,
            selected: widget.value,
            searchHint: widget.searchHint,
            allowCustom: widget.allowCustom,
            customLabel: widget.customLabel,
            onPick: (value) => Navigator.of(sheetContext).pop(value),
          ),
        ),
      ),
    );
    if (picked != null) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin ?? const EdgeInsets.only(bottom: 14),
      child: FormField<String>(
        key: _fieldKey,
        initialValue: widget.value,
        validator: widget.validator,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                _fieldWidth = constraints.maxWidth;
                return CompositedTransformTarget(
                  link: _link,
                  child: OverlayPortal(
                    controller: _portal,
                    overlayChildBuilder: _buildOverlay,
                    child: _buildField(state),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(FormFieldState<String> state) {
    final value = state.value;
    final hasError = state.hasError;
    final borderColor = hasError
        ? AppColors.error
        : (_isOpen ? AppColors.lightBorderFocused : AppColors.lightBorder);

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value == null,
        isFocused: _isOpen,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMutedLight),
          errorText: state.errorText,
          filled: true,
          fillColor: AppColors.lightSurface,
          prefixIcon: widget.prefixIcon == null
              ? null
              : IconTheme(
                  data: IconThemeData(color: AppColors.textSecondaryLight, size: 20),
                  child: widget.prefixIcon!,
                ),
          suffixIcon: AnimatedRotation(
            turns: _isOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondaryLight),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor, width: _isOpen ? 1.8 : 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.lightBorderFocused, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error, width: 1.4),
          ),
        ),
        child: value == null
            ? const SizedBox.shrink()
            : Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimaryLight),
              ),
      ),
    );
  }

  /// Web panel anchored below the field; tapping outside closes it.
  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _fieldWidth,
              height: 330,
              child: Material(
                color: AppColors.pureWhite,
                elevation: 12,
                shadowColor: AppColors.brandDark.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: _SearchPanel(
                    key: const ValueKey('search-dropdown-panel'),
                    items: widget.items,
                    selected: _fieldKey.currentState?.value ?? widget.value,
                    searchHint: widget.searchHint,
                    allowCustom: widget.allowCustom,
                    customLabel: widget.customLabel,
                    onPick: _pick,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Search box plus the filtered list, shared by the web panel and the
/// mobile bottom sheet.
class _SearchPanel extends StatefulWidget {
  final String? title;
  final List<String> items;
  final String? selected;
  final String searchHint;
  final bool allowCustom;
  final String Function(String query)? customLabel;
  final ValueChanged<String> onPick;

  const _SearchPanel({
    super.key,
    this.title,
    required this.items,
    required this.selected,
    required this.searchHint,
    required this.allowCustom,
    required this.customLabel,
    required this.onPick,
  });

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final lower = query.toLowerCase();
    final matches = widget.items.where((i) => i.toLowerCase().contains(lower)).toList();
    final exact = widget.items.any((i) => i.toLowerCase() == lower);
    final showCustom = widget.allowCustom && query.isNotEmpty && !exact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              widget.title!,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (matches.length == 1) {
                widget.onPick(matches.first);
              } else if (showCustom && matches.isEmpty) {
                widget.onPick(query);
              }
            },
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMutedLight),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textMutedLight),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMutedLight),
                      onPressed: () => setState(_search.clear),
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.offWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Divider(height: 1, color: AppColors.lightBorder),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              if (showCustom)
                _OptionTile(
                  icon: Icons.add_location_alt_rounded,
                  label: widget.customLabel?.call(query) ?? 'Use "$query"',
                  highlight: true,
                  onTap: () => widget.onPick(query),
                ),
              for (final item in matches)
                _OptionTile(
                  icon: Icons.location_on_outlined,
                  label: item,
                  selected: item == widget.selected,
                  onTap: () => widget.onPick(item),
                ),
              if (matches.isEmpty && !showCustom)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No matches',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.selected = false,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight || selected ? AppColors.primary : AppColors.textPrimaryLight;

    return Material(
      color: selected ? AppColors.mint.withValues(alpha: 0.45) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.mint.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: highlight || selected ? AppColors.primary : AppColors.textMutedLight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: color,
                    fontWeight: highlight || selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
