import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/api/api_client.dart';
import 'core/controllers/app_data.dart';
import 'core/controllers/theme_controller.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_text_options.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system status bar to blend seamlessly with the white UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.pureWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // A sign-in that has ended (user removed, password changed) returns to login.
  ApiClient.instance.onSessionExpired = () {
    AppData.clear();
    AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  };

  // Opens in the colour theme an Admin picked.
  ThemeController.instance.load();

  runApp(const RealEstateApp());
}

class RealEstateApp extends StatefulWidget {
  const RealEstateApp({super.key});

  @override
  State<RealEstateApp> createState() => _RealEstateAppState();
}

class _RealEstateAppState extends State<RealEstateApp> {
  final _themeController = ThemeController.instance;
  late var _look = _lookNow;

  (AppPalette, AppFont, AppTextSize) get _lookNow =>
      (_themeController.palette, _themeController.font, _themeController.textSize);

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
    if (_look == _lookNow) return;
    _look = _lookNow;
    // Colours and fonts are read when widgets build, so a new look redraws
    // every screen, including widgets that would otherwise be kept as-is.
    void redraw(Element element) {
      element.markNeedsBuild();
      element.visitChildren(redraw);
    }

    (context as Element).visitChildren(redraw);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaira Properties',
      navigatorKey: AppRoutes.navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeController.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      // Text size from Settings > Text, on top of the device's own setting.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = _themeController.textSize.scale;
        if (scale == 1.0) return child!;
        return MediaQuery(
          data: media.copyWith(textScaler: _ScaledText(media.textScaler, scale)),
          child: child!,
        );
      },
    );
  }
}

/// The device's text scaling times the size chosen in Settings > Text.
class _ScaledText extends TextScaler {
  const _ScaledText(this.device, this.factor);

  final TextScaler device;
  final double factor;

  @override
  double scale(double fontSize) => device.scale(fontSize) * factor;

  @override
  double get textScaleFactor => device.scale(14) / 14 * factor;

  @override
  bool operator ==(Object other) => other is _ScaledText && other.device == device && other.factor == factor;

  @override
  int get hashCode => Object.hash(device, factor);
}
