import 'package:flutter/material.dart';

/// The colour themes an Admin can pick in Settings > Theme. Each one keeps
/// the same calm, light look and swaps the brand colour family.
enum AppPalette {
  sage(
    'Sage',
    'Calm green and white. The original Kaira look.',
    primary: Color(0xFF5C7057),
    mid: Color(0xFF89A482),
    soft: Color(0xFFACC5A6),
    pale: Color(0xFFD1EDD3),
    offWhite: Color(0xFFF5F9F4),
    border: Color(0xFFE0EADD),
    deep: Color(0xFF4A5C46),
    surface: Color(0xFF677D62),
    card: Color(0xFF738B6D),
    text: Color(0xFF2E3A2B),
    textSecondary: Color(0xFF52604E),
    textMuted: Color(0xFF8A9786),
  ),
  ocean(
    'Ocean',
    'Deep sea blue. Clear and professional.',
    primary: Color(0xFF2F6690),
    mid: Color(0xFF5B8DB8),
    soft: Color(0xFF9CC3E0),
    pale: Color(0xFFD9EAF7),
    offWhite: Color(0xFFF4F8FB),
    border: Color(0xFFDCE6EF),
    deep: Color(0xFF234E6E),
    surface: Color(0xFF3E7AA5),
    card: Color(0xFF4F88B0),
    text: Color(0xFF1F2D3A),
    textSecondary: Color(0xFF4A5B6B),
    textMuted: Color(0xFF83919E),
  ),
  indigo(
    'Royal Indigo',
    'Rich indigo with a premium feel.',
    primary: Color(0xFF4C4F9E),
    mid: Color(0xFF7477C2),
    soft: Color(0xFFAEB0E0),
    pale: Color(0xFFE1E2F7),
    offWhite: Color(0xFFF6F6FC),
    border: Color(0xFFE0E1F0),
    deep: Color(0xFF3A3C7D),
    surface: Color(0xFF5B5EAD),
    card: Color(0xFF6A6DB8),
    text: Color(0xFF262842),
    textSecondary: Color(0xFF4F5170),
    textMuted: Color(0xFF8A8CA6),
  ),
  terracotta(
    'Terracotta',
    'Warm brick and clay, like fresh construction.',
    primary: Color(0xFFA0522D),
    mid: Color(0xFFC97B52),
    soft: Color(0xFFE3AE8F),
    pale: Color(0xFFF8E3D6),
    offWhite: Color(0xFFFCF7F3),
    border: Color(0xFFF0E0D6),
    deep: Color(0xFF7F3F21),
    surface: Color(0xFFAD6340),
    card: Color(0xFFB8714E),
    text: Color(0xFF3A2A22),
    textSecondary: Color(0xFF65493B),
    textMuted: Color(0xFFA08B80),
  ),
  graphite(
    'Graphite',
    'Neutral slate grey. Quiet and modern.',
    primary: Color(0xFF3F4A56),
    mid: Color(0xFF6B7785),
    soft: Color(0xFFA9B3BE),
    pale: Color(0xFFE2E7EC),
    offWhite: Color(0xFFF6F7F9),
    border: Color(0xFFE1E5EA),
    deep: Color(0xFF2D353E),
    surface: Color(0xFF525E6B),
    card: Color(0xFF606C7A),
    text: Color(0xFF22282F),
    textSecondary: Color(0xFF4B5560),
    textMuted: Color(0xFF8A939D),
  ),
  plum(
    'Plum',
    'Soft berry tones. Friendly and elegant.',
    primary: Color(0xFF8E4162),
    mid: Color(0xFFB46C8B),
    soft: Color(0xFFD6A5BA),
    pale: Color(0xFFF5DFE8),
    offWhite: Color(0xFFFCF6F8),
    border: Color(0xFFF0DFE6),
    deep: Color(0xFF6E3049),
    surface: Color(0xFF9C5373),
    card: Color(0xFFA86280),
    text: Color(0xFF3A2430),
    textSecondary: Color(0xFF654656),
    textMuted: Color(0xFFA28A96),
  );

  const AppPalette(
    this.label,
    this.description, {
    required this.primary,
    required this.mid,
    required this.soft,
    required this.pale,
    required this.offWhite,
    required this.border,
    required this.deep,
    required this.surface,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
  });

  final String label;
  final String description;

  /// Main brand colour, readable on white.
  final Color primary;
  final Color mid;
  final Color soft;

  /// Palest tint, for selected rows and soft fills.
  final Color pale;
  final Color offWhite;
  final Color border;
  final Color deep;
  final Color surface;
  final Color card;
  final Color text;
  final Color textSecondary;
  final Color textMuted;

  /// The theme on screen now. Change it through ThemeController so the app
  /// redraws.
  static AppPalette current = AppPalette.sage;

  static AppPalette byName(String? name) =>
      AppPalette.values.firstWhere((palette) => palette.name == name, orElse: () => AppPalette.sage);
}
