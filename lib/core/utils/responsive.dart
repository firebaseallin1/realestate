import 'package:flutter/material.dart';

/// Responsive holds the breakpoint that decides between the mobile
/// and web layouts. Width-based, so a phone browser still gets mobile.
class Responsive {
  Responsive._();

  static const double webBreakpoint = 900;

  static bool isWeb(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= webBreakpoint;
}

/// ResponsiveLayout builds only the layout that matches the current width.
/// Screens keep their state and logic above this widget, so both layouts
/// share it and stay in sync.
class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder web;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.web,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Responsive.webBreakpoint) {
          return web(context);
        }
        return mobile(context);
      },
    );
  }
}
