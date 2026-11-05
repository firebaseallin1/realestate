import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// AppDropdownOption represents a generic selectable item for AppDropdown.
class AppDropdownOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final Widget? icon;

  const AppDropdownOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });
}

/// AppDropdown provides a reusable dropdown input styled with the sage theme.
class AppDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<AppDropdownOption<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final Widget? prefixIcon;
  final EdgeInsetsGeometry? margin;
  final bool enabled;

  const AppDropdown({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.margin,
    this.enabled = true,
  });

  /// Factory constructor for simple string lists
  static AppDropdown<String> fromStrings({
    Key? key,
    String? label,
    String? hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    EdgeInsetsGeometry? margin,
    bool enabled = true,
  }) {
    return AppDropdown<String>(
      key: key,
      label: label,
      hint: hint,
      value: value,
      items: items
          .map((item) => AppDropdownOption<String>(value: item, title: item))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      prefixIcon: prefixIcon,
      margin: margin,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final hintColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final popupBgColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: AppTypography.labelMedium.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          DropdownButtonFormField<T>(
            isExpanded: true,
            initialValue: value,
            itemHeight: 52,
            selectedItemBuilder: (BuildContext context) {
              return items.map((option) {
                return Row(
                  children: [
                    if (option.icon != null) ...[
                      option.icon!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        option.title,
                        style: AppTypography.bodyLarge.copyWith(color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: items.map((option) {
              return DropdownMenuItem<T>(
                value: option.value,
                child: Row(
                  children: [
                    if (option.icon != null) ...[
                      option.icon!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.title,
                            style: AppTypography.bodyLarge.copyWith(color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (option.subtitle != null) ...[
                            Text(
                              option.subtitle!,
                              style: AppTypography.caption.copyWith(
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
            validator: validator,
            dropdownColor: popupBgColor,
            borderRadius: BorderRadius.circular(16),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: 22,
            ),
            style: AppTypography.bodyLarge.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodyMedium.copyWith(color: hintColor),
              filled: true,
              fillColor: fillColor,
              prefixIcon: prefixIcon != null
                  ? IconTheme(
                      data: IconThemeData(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        size: 20,
                      ),
                      child: prefixIcon!,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.darkBorderFocused, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

