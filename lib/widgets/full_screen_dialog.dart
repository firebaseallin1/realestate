import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';

/// Opens a detail page as a full-screen dialog: it slides up and fades in
/// over the current page, which stays dimmed behind it on wide screens.
/// Pair the page with [FullScreenDialogFrame] and [AppBackButton].
Future<T?> pushFullScreenDialog<T>(BuildContext context, WidgetBuilder builder, {String label = 'Details'}) {
  return Navigator.of(context).push(
    PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierLabel: label,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// On wide screens, shows [child] as a large rounded panel with a shadow,
/// inset from the edges. On phones it fills the screen.
class FullScreenDialogFrame extends StatelessWidget {
  final Widget child;

  const FullScreenDialogFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < Responsive.webBreakpoint) return child;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
        ),
      ),
    );
  }
}

/// Round, tinted back button that fills with the brand colour on hover.
class AppBackButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: widget.onPressed ?? () => Navigator.of(context).maybePop(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: _hover ? AppColors.brandGradient : null,
                color: _hover ? null : AppColors.mint.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _hover ? Colors.transparent : AppColors.sageSoft),
                boxShadow: _hover
                    ? [BoxShadow(color: AppColors.primaryGlow, blurRadius: 12, offset: Offset(0, 4))]
                    : null,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _hover ? AppColors.pureWhite : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
