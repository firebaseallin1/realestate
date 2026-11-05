import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/controllers/theme_controller.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_colors.dart';
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

  runApp(const RealEstateApp());
}

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder ensures any theme mode change from ThemeController
    // triggers a reactive rebuild of the MaterialApp theme instantly.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final themeController = ThemeController.instance;

        return MaterialApp(
          title: 'Kaira Properties',
          debugShowCheckedModeBanner: false,
          themeMode: themeController.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
