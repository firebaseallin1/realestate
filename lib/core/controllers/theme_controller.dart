import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_options.dart';

/// ThemeController manages the application's look: the light/dark mode, and
/// the colour theme ([AppPalette]), font ([AppFont]) and text size
/// ([AppTextSize]) an Admin picks for everyone.
///
/// The app's [instance] reads the colour theme from the server and keeps a
/// copy on the device, so the next start (and the sign-in screen) opens in
/// it straight away. [ThemeController.local] keeps it in memory, for tests.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() => instance;

  ThemeController._internal() : _server = true;

  /// Not saved anywhere: for tests and previews.
  ThemeController.local() : _server = false;

  final bool _server;
  static const _storageKey = 'app_theme';
  static const _storage = FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  /// The colour theme on screen.
  AppPalette get palette => AppPalette.current;

  /// The font and text size on screen.
  AppFont get font => AppFont.current;
  AppTextSize get textSize => AppTextSize.current;

  void _apply({AppPalette? palette, AppFont? font, AppTextSize? textSize}) {
    final next = (palette ?? AppPalette.current, font ?? AppFont.current, textSize ?? AppTextSize.current);
    if (next == (AppPalette.current, AppFont.current, AppTextSize.current)) return;
    AppPalette.current = next.$1;
    AppFont.current = next.$2;
    AppTextSize.current = next.$3;
    notifyListeners();
  }

  /// Opens in the look saved on this device, then checks the server for the
  /// one an Admin picked. Failures keep the current look.
  Future<void> load() async {
    if (!_server) return;
    try {
      // Saved as "theme font size", e.g. "ocean poppins large".
      final saved = (await _storage.read(key: _storageKey))?.split(' ') ?? const [];
      _apply(
        palette: AppPalette.byName(saved.elementAtOrNull(0)),
        font: AppFont.byName(saved.elementAtOrNull(1)),
        textSize: AppTextSize.byName(saved.elementAtOrNull(2)),
      );
    } catch (error) {
      debugPrint('Could not read the saved theme: $error');
    }
    try {
      await _remember(await ApiClient.instance.get('/settings/theme', authenticated: false));
    } catch (error) {
      debugPrint('Could not load the theme: $error');
    }
  }

  /// Admins: changes the colour theme for everyone.
  Future<void> setPalette(AppPalette palette) => setAppearance(palette: palette);

  /// Admins: changes the parts given, for everyone.
  Future<void> setAppearance({AppPalette? palette, AppFont? font, AppTextSize? textSize}) async {
    final changes = {'theme': ?palette?.name, 'font': ?font?.name, 'textSize': ?textSize?.name};
    if (changes.isEmpty) return;
    if (_server) {
      await _remember(await ApiClient.instance.put('/settings/theme', body: changes));
    } else {
      _apply(palette: palette, font: font, textSize: textSize);
    }
  }

  Future<void> _remember(Map<String, dynamic>? json) async {
    if (json == null) return;
    _apply(
      palette: AppPalette.byName(json['theme'] as String?),
      font: AppFont.byName(json['font'] as String?),
      textSize: AppTextSize.byName(json['textSize'] as String?),
    );
    try {
      await _storage.write(key: _storageKey, value: '${palette.name} ${font.name} ${textSize.name}');
    } catch (error) {
      debugPrint('Could not save the theme: $error');
    }
  }
}
