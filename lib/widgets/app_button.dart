import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

enum AppButtonType {
  primary,
  secondary,
  outline,
  ghost,
}

/// AppButton is a versatile, accessible button widget for primary, secondary,
/// outline, and ghost button styles with built-in loading indicator support.
///
/// Buttons react to the pointer: they lift on hover (web / desktop) and
/// press in when tapped. The primary button adds a glossy top shine, a
/// sage-tinted glow and a frosted badge around its icon.
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;
  final bool iconTrailing;
  final double? width;
  final double height;
  final double borderRadius;
  final LinearGradient? gradient;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconTrailing = false,
    this.width = double.infinity,
    this.height = 46,
    this.borderRadius = 14,
    this.gradient,
  });

  /// Factory for Primary Gradient Button
  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconTrailing = false,
    this.width = double.infinity,
    this.height = 46,
    this.borderRadius = 14,
    this.gradient,
  }) : type = AppButtonType.primary;

  /// Factory for Secondary Soft Surface Button
  const AppButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconTrailing = false,
    this.width = double.infinity,
    this.height = 46,
    this.borderRadius = 14,
    this.gradient,
  }) : type = AppButtonType.secondary;

  /// Factory for Outline Button
  const AppButton.outline({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconTrailing = false,
    this.width = double.infinity,
    this.height = 46,
    this.borderRadius = 14,
    this.gradient,
  }) : type = AppButtonType.outline;

  /// Factory for Ghost / Text Button
  const AppButton.ghost({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.iconTrailing = false,
    this.width,
    this.height = 40,
    this.borderRadius = 12,
    this.gradient,
  }) : type = AppButtonType.ghost;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  static const _animDuration = Duration(milliseconds: 180);

  bool _hovered = false;
  bool _pressed = false;

  bool get _isInteractive =>
      !widget.isLoading && !widget.isDisabled && widget.onPressed != null;

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A button that turns busy or disabled mid-press should not stay pressed.
    if (!_isInteractive && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInteractive = _isInteractive;
    // Loading keeps the active look so the spinner stays visible on its fill.
    final isActiveStyle = widget.isLoading || isInteractive;
    final radius = BorderRadius.circular(widget.borderRadius);

    final Widget button;
    switch (widget.type) {
      case AppButtonType.primary:
        button = _buildPrimary(isActiveStyle, isDark, radius);
        break;
      case AppButtonType.secondary:
        button = _buildSecondary(isActiveStyle, isDark, radius);
        break;
      case AppButtonType.outline:
        button = _buildOutline(isActiveStyle, isDark, radius);
        break;
      case AppButtonType.ghost:
        button = SizedBox(
          width: widget.width,
          height: widget.height,
          child: _inkLayer(radius, _buildContent(isDark), horizontalPadding: 14),
        );
        break;
    }

    // Hover lifts the button, pressing sinks it slightly.
    final lift = _pressed ? 0.0 : (_hovered ? -2.0 : 0.0);
    final scale = _pressed ? 0.97 : 1.0;

    return Opacity(
      opacity: widget.isDisabled ? 0.5 : 1.0,
      child: AnimatedSlide(
        duration: _animDuration,
        curve: Curves.easeOut,
        offset: Offset(0, lift / widget.height),
        child: AnimatedScale(
          duration: _animDuration,
          curve: Curves.easeOut,
          scale: scale,
          child: button,
        ),
      ),
    );
  }

  Widget _buildPrimary(bool isActiveStyle, bool isDark, BorderRadius radius) {
    final glowAlpha = !isActiveStyle ? 0.0 : (_pressed ? 0.2 : (_hovered ? 0.45 : 0.32));
    final glowBlur = _pressed ? 8.0 : (_hovered ? 26.0 : 18.0);
    final glowOffset = _pressed ? 3.0 : (_hovered ? 12.0 : 8.0);

    return AnimatedContainer(
      duration: _animDuration,
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: isActiveStyle ? (widget.gradient ?? AppColors.brandGradient) : null,
        color: isActiveStyle
            ? null
            : (isDark ? AppColors.darkBorder : AppColors.textMutedLight),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: isActiveStyle ? 0.14 : 0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: glowAlpha),
            blurRadius: glowBlur,
            offset: Offset(0, glowOffset),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Content first and unpositioned, so it sizes the stack even
            // when the button has no fixed width.
            _inkLayer(radius, _buildContent(isDark)),

            // Glossy shine across the top half
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.white.withValues(alpha: _hovered ? 0.24 : 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondary(bool isActiveStyle, bool isDark, BorderRadius radius) {
    final bgColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AnimatedContainer(
      duration: _animDuration,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isActiveStyle ? bgColor : bgColor.withValues(alpha: 0.5),
        borderRadius: radius,
        border: Border.all(
          color: _hovered ? AppColors.primaryBright : borderColor,
          width: 1,
        ),
      ),
      child: _inkLayer(radius, _buildContent(isDark)),
    );
  }

  Widget _buildOutline(bool isActiveStyle, bool isDark, BorderRadius radius) {
    final idleBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final activeBorder = isDark ? AppColors.primaryLight : AppColors.primary;

    return AnimatedContainer(
      duration: _animDuration,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        // Soft sage wash on hover
        color: _hovered
            ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.07)
            : Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: isActiveStyle ? activeBorder : idleBorder,
          width: 1.5,
        ),
      ),
      child: _inkLayer(radius, _buildContent(isDark)),
    );
  }

  /// Ripple + hover / press tracking shared by every button type.
  Widget _inkLayer(BorderRadius radius, Widget content, {double horizontalPadding = 16}) {
    final isInteractive = _isInteractive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isInteractive ? widget.onPressed : null,
        onHover: isInteractive ? (value) => setState(() => _hovered = value) : null,
        onHighlightChanged: isInteractive ? (value) => setState(() => _pressed = value) : null,
        borderRadius: radius,
        splashColor: Colors.white.withValues(alpha: 0.18),
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Center(child: content),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final type = widget.type;

    if (widget.isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            type == AppButtonType.outline || type == AppButtonType.ghost
                ? AppColors.primary
                : Colors.white,
          ),
        ),
      );
    }

    final icon = widget.icon == null ? null : _decorateIcon(widget.icon!);

    return Row(
      mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null && !widget.iconTrailing) ...[
          icon,
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _getTextStyle(isDark),
          ),
        ),
        if (icon != null && widget.iconTrailing) ...[
          const SizedBox(width: 10),
          // Trailing arrows nudge forward on hover.
          AnimatedSlide(
            duration: _animDuration,
            offset: Offset(_hovered ? 0.15 : 0, 0),
            child: icon,
          ),
        ],
      ],
    );
  }

  /// Primary icons sit in a frosted circle; other types show them plain.
  Widget _decorateIcon(Widget icon) {
    if (widget.type != AppButtonType.primary) return icon;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Center(
        child: IconTheme.merge(
          data: const IconThemeData(size: 18),
          child: icon,
        ),
      ),
    );
  }

  TextStyle _getTextStyle(bool isDark) {
    switch (widget.type) {
      case AppButtonType.primary:
        return AppTypography.buttonLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        );
      case AppButtonType.secondary:
        return AppTypography.buttonLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        );
      case AppButtonType.outline:
        return AppTypography.buttonLarge.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
        );
      case AppButtonType.ghost:
        return AppTypography.buttonMedium.copyWith(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
        );
    }
  }
}

/// AppSocialButton provides styled third-party authentication buttons
class AppSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  const AppSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  factory AppSocialButton.google({
    Key? key,
    required VoidCallback? onPressed,
  }) {
    return AppSocialButton(
      key: key,
      label: 'Google',
      icon: const _SocialIconBadge(
        text: 'G',
        textColor: Color(0xFFEA4335),
      ),
      onPressed: onPressed,
    );
  }

  factory AppSocialButton.apple({
    Key? key,
    required VoidCallback? onPressed,
  }) {
    return AppSocialButton(
      key: key,
      label: 'Apple',
      icon: const Icon(Icons.apple, size: 22, color: Colors.white),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialIconBadge extends StatelessWidget {
  final String text;
  final Color textColor;

  const _SocialIconBadge({
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

