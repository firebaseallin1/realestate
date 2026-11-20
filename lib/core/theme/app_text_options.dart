/// The fonts an Admin can pick in Settings > Text. All but [system] are
/// bundled in assets/fonts (see pubspec.yaml).
enum AppFont {
  josefin('Josefin Sans', 'Friendly and geometric. The original Kaira look.', 'JosefinSans'),
  poppins('Poppins', 'Modern and rounded. Very easy to read.', 'Poppins'),
  serif('PT Serif', 'Classic serif, like a printed document.', 'PTSerif'),
  system('Device Font', "The phone or computer's own font.", null);

  const AppFont(this.label, this.description, this.family);

  final String label;
  final String description;

  /// The font family name; null uses the device's font.
  final String? family;

  /// The font on screen now. Change it through ThemeController so the app
  /// redraws.
  static AppFont current = AppFont.josefin;

  static AppFont byName(String? name) =>
      AppFont.values.firstWhere((font) => font.name == name, orElse: () => AppFont.josefin);
}

/// How big text is across the app, on top of the device's own setting.
enum AppTextSize {
  small('Small', 0.9),
  normal('Normal', 1.0),
  large('Large', 1.1),
  extraLarge('Extra Large', 1.2);

  const AppTextSize(this.label, this.scale);

  final String label;
  final double scale;

  static AppTextSize current = AppTextSize.normal;

  static AppTextSize byName(String? name) =>
      AppTextSize.values.firstWhere((size) => size.name == name, orElse: () => AppTextSize.normal);
}
