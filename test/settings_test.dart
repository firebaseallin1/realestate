import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/settings_controller.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/controllers/theme_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/core/theme/app_colors.dart';
import 'package:real_estate/core/theme/app_palette.dart';
import 'package:real_estate/core/theme/app_text_options.dart';
import 'package:real_estate/core/theme/app_typography.dart';
import 'package:real_estate/models/app_settings.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';

const _desktop = Size(1440, 1000);
const _phone = Size(390, 844);

Future<SettingsController> _pump(WidgetTester tester, Size size, String username, {ThemeController? theme}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final users = UserController.test();
  final settings = SettingsController()
    ..preview(
      const FileStorageStatus(
        database: StorageUse(files: 12, bytes: 4508876),
        folder: StorageUse(files: 3, bytes: 1153434),
      ),
    );
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settingsRoute) => MaterialPageRoute(
        settings: RouteSettings(arguments: users.findByUsername(username)),
        builder: (_) =>
            DashboardScreen(
          controller: SiteController.test(),
          userController: users,
          settingsController: settings,
          themeController: theme ?? ThemeController.local(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  final item = find.byKey(const ValueKey('menu-appSettings'));
  final group = find.byKey(const ValueKey('menu-group-settings'));
  if (item.evaluate().isEmpty) {
    final drawer = find.byKey(const ValueKey('open-menu'));
    await tester.tap(drawer.evaluate().isNotEmpty ? drawer : group);
    await tester.pumpAndSettle();
  }
  if (item.evaluate().isEmpty) await _tap(tester, group);
  await _tap(tester, item.last);
}

void main() {
  testWidgets('Admin chooses where uploads are stored and moves old files', (tester) async {
    for (final size in [_desktop, _phone]) {
      final settings = await _pump(tester, size, 'admin');
      await _openSettings(tester);
      expect(find.text('File Storage'), findsNWidgets(2)); // In the list and as the title.
      expect(find.text('Holds 12 files · 4.3 MB'), findsOneWidget);
      expect(find.text('Holds 3 files · 1.1 MB'), findsOneWidget);

      // Saving only once something changed.
      expect(find.byKey(const ValueKey('storage-move')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('storage-folder')));
      expect(find.textContaining('Only new uploads go to the server folder'), findsOneWidget);
      expect(find.byKey(const ValueKey('storage-move')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('storage-save')));
      expect(settings.fileStorage.storage, FileStorage.folder);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Back to the database, then move the folder's files in.
      await _tap(tester, find.byKey(const ValueKey('storage-database')));
      await _tap(tester, find.byKey(const ValueKey('storage-save')));
      expect(settings.fileStorage.storage, FileStorage.database);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('storage-move')));
      expect(find.text('Move 3 files?'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('storage-move-go')));
      expect(settings.fileStorage.folder.files, 0);
      expect(settings.fileStorage.database.files, 15);
      expect(find.text('3 files moved.'), findsOneWidget);
      expect(find.byKey(const ValueKey('storage-move')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Settings lists its pages on the left and the Admin picks a colour theme', (tester) async {
    addTearDown(() => AppPalette.current = AppPalette.sage);
    for (final size in [_desktop, _phone]) {
      AppPalette.current = AppPalette.sage;
      final theme = ThemeController.local();
      await _pump(tester, size, 'admin', theme: theme);
      await _openSettings(tester);
      expect(find.byKey(const ValueKey('settings-nav-storage')), findsOneWidget);
      expect(find.text('File Storage'), findsWidgets);

      await _tap(tester, find.byKey(const ValueKey('settings-nav-theme')));
      expect(find.text('Holds 12 files · 4.3 MB'), findsNothing);
      for (final palette in AppPalette.values) {
        expect(find.byKey(ValueKey('theme-${palette.name}')), findsOneWidget);
      }
      expect(find.text('In use'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('theme-ocean')));
      expect(find.textContaining('Everyone sees the Ocean theme after you save'), findsOneWidget);
      expect(AppColors.primary, AppPalette.sage.primary);
      await _tap(tester, find.byKey(const ValueKey('theme-save')));
      expect(theme.palette, AppPalette.ocean);
      expect(AppColors.primary, AppPalette.ocean.primary);
      expect(find.text('Everyone now sees the Ocean theme.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('The Admin picks a font and text size for everyone', (tester) async {
    addTearDown(() {
      AppFont.current = AppFont.josefin;
      AppTextSize.current = AppTextSize.normal;
    });
    for (final size in [_desktop, _phone]) {
      AppFont.current = AppFont.josefin;
      AppTextSize.current = AppTextSize.normal;
      final theme = ThemeController.local();
      await _pump(tester, size, 'admin', theme: theme);
      await _openSettings(tester);
      await _tap(tester, find.byKey(const ValueKey('settings-nav-text')));
      for (final font in AppFont.values) {
        expect(find.byKey(ValueKey('font-${font.name}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('text-preview')), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('font-poppins')));
      await _tap(tester, find.byKey(const ValueKey('text-size-large')));
      expect(AppTypography.fontFamily, 'JosefinSans'); // Not until saved.
      await _tap(tester, find.byKey(const ValueKey('text-save')));
      expect(theme.font, AppFont.poppins);
      expect(theme.textSize, AppTextSize.large);
      expect(AppTypography.fontFamily, 'Poppins');
      expect(find.text('Everyone now sees the new text settings.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Only Admins have Settings, at the end of the menu', (tester) async {
    await _pump(tester, _desktop, 'sales');
    expect(find.byKey(const ValueKey('menu-group-settings')), findsNothing);
    expect(find.byKey(const ValueKey('menu-appSettings')), findsNothing);
  });
}
