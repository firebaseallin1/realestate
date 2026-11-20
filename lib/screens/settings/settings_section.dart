import 'package:flutter/material.dart';

import '../../core/controllers/settings_controller.dart';
import '../../core/controllers/theme_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_settings.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_form_sheet.dart';
import '../dashboard/widgets/dashboard_panel.dart';

/// The pages of Settings, listed on the left.
enum SettingsPage {
  storage('File Storage', 'Where uploads are kept', Icons.cloud_upload_outlined),
  theme('Theme', 'Colours for the whole app', Icons.palette_outlined),
  text('Text', 'Font and text size', Icons.text_fields_rounded);

  const SettingsPage(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;
}

/// SettingsSection (Admin): app-wide settings. The pages are listed on the
/// left (on top on phones) and the chosen page's options show on the right.
class SettingsSection extends StatefulWidget {
  final SettingsController controller;

  /// Defaults to the app's theme.
  final ThemeController? themeController;

  const SettingsSection({super.key, required this.controller, this.themeController});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  SettingsPage _page = SettingsPage.storage;

  @override
  Widget build(BuildContext context) {
    final page = switch (_page) {
      SettingsPage.storage => _FileStoragePanel(controller: widget.controller),
      SettingsPage.theme => _ThemePanel(controller: widget.themeController ?? ThemeController.instance),
      SettingsPage.text => _TextPanel(controller: widget.themeController ?? ThemeController.instance),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final nav = _SettingsNav(selected: _page, vertical: wide, onSelect: (page) => setState(() => _page = page));
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [nav, const SizedBox(height: 12), page],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 250, child: nav),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: page),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The list of settings pages: a column on wide screens, a row of tabs on
/// phones.
class _SettingsNav extends StatelessWidget {
  final SettingsPage selected;
  final bool vertical;
  final ValueChanged<SettingsPage> onSelect;

  const _SettingsNav({required this.selected, required this.vertical, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final page in SettingsPage.values)
        _NavItem(page: page, selected: page == selected, compact: !vertical, onTap: () => onSelect(page)),
    ];
    if (!vertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [for (final item in items) Padding(padding: const EdgeInsets.only(right: 8), child: item)],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Text(
              'SETTINGS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 6), child: item),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final SettingsPage page;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _NavItem({required this.page, required this.selected, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondaryLight;
    return Material(
      color: selected ? AppColors.mint.withValues(alpha: 0.55) : (compact ? AppColors.pureWhite : Colors.transparent),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('settings-nav-${page.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : (compact ? AppColors.lightBorder : Colors.transparent),
            ),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(page.icon, size: 20, color: color),
              const SizedBox(width: 10),
              if (compact)
                Text(
                  page.label,
                  style: AppTypography.titleSmall.copyWith(color: color, fontWeight: FontWeight.w700),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.label,
                        style: AppTypography.titleSmall.copyWith(color: color, fontWeight: FontWeight.w700),
                      ),
                      Text(page.hint, style: AppTypography.caption.copyWith(color: AppColors.textMutedLight)),
                    ],
                  ),
                ),
              if (!compact && selected) Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// File Storage: where new uploads are kept, the database or a folder on the
/// server, and moving files already saved into the chosen place.
class _FileStoragePanel extends StatefulWidget {
  final SettingsController controller;

  const _FileStoragePanel({required this.controller});

  @override
  State<_FileStoragePanel> createState() => _FileStoragePanelState();
}

class _FileStoragePanelState extends State<_FileStoragePanel> {
  /// The choice on screen, before it is saved.
  FileStorage? _choice;

  SettingsController get _controller => widget.controller;

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null) return;
    if (!await runSave(context, () => _controller.setFileStorage(choice)) || !mounted) return;
    setState(() => _choice = null);
    showAppMessage(context, 'New uploads will be stored in the ${choice.label.toLowerCase()}.');
  }

  Future<void> _move() async {
    final status = _controller.fileStorage;
    final count = status.elsewhere.files;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          key: const ValueKey('storage-move-confirm'),
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Move $count ${count == 1 ? 'file' : 'files'}?',
            style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryLight),
          ),
          content: Text(
            'Each file is copied to the ${status.storage.label.toLowerCase()}, then its old copy is deleted. '
            'Files stay available while they move.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              key: const ValueKey('storage-move-go'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Move Files'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    var result = (0, 0);
    if (!await runSave(context, () async => result = await _controller.moveFiles()) || !mounted) return;
    final (moved, failed) = result;
    showAppMessage(
      context,
      failed == 0
          ? '$moved ${moved == 1 ? 'file' : 'files'} moved.'
          : '$moved moved; $failed could not be read and stayed where they were.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final status = _controller.fileStorage;
        final choice = _choice ?? status.storage;
        final changed = choice != status.storage;
        final elsewhere = status.elsewhere;

        return DashboardPanel(
          title: 'File Storage',
          subtitle: 'Where bills, site maps and brochures are kept',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final storage in FileStorage.values) ...[
                _StorageOption(
                  storage: storage,
                  use: status.useOf(storage),
                  selected: storage == choice,
                  current: storage == status.storage,
                  onTap: () => setState(() => _choice = storage == status.storage ? null : storage),
                ),
                const SizedBox(height: 10),
              ],
              if (changed)
                _Note(
                  color: AppColors.accentGold,
                  text:
                      'Only new uploads go to the ${choice.label.toLowerCase()}. '
                      'Files already saved stay where they are until you move them.',
                ),
              if (!changed && elsewhere.files > 0)
                _Note(
                  color: AppColors.primary,
                  text:
                      '${elsewhere.label} still in the '
                      '${(status.storage == FileStorage.database ? FileStorage.folder : FileStorage.database).label.toLowerCase()}. '
                      'They open as normal; move them to keep everything in one place.',
                ),
              const SizedBox(height: 4),
              _Actions(
                children: [
                  if (!changed && elsewhere.files > 0)
                    IntrinsicWidth(
                      child: AppButton.outline(
                        key: const ValueKey('storage-move'),
                        text:
                            'Move ${elsewhere.files} ${elsewhere.files == 1 ? 'File' : 'Files'} to '
                            '${status.storage.label}',
                        width: null,
                        height: 42,
                        icon: Icon(Icons.drive_file_move_outline, color: AppColors.primary, size: 18),
                        onPressed: _move,
                      ),
                    ),
                  _SaveButton(buttonKey: const ValueKey('storage-save'), enabled: changed, onPressed: _save),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Text: the font and text size everyone sees. Each font shows a sample.
class _TextPanel extends StatefulWidget {
  final ThemeController controller;

  const _TextPanel({required this.controller});

  @override
  State<_TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<_TextPanel> {
  /// The choices on screen, before they are saved.
  AppFont? _font;
  AppTextSize? _size;

  Future<void> _save() async {
    final font = _font, size = _size;
    if (!await runSave(context, () => widget.controller.setAppearance(font: font, textSize: size)) || !mounted) {
      return;
    }
    setState(() => _font = _size = null);
    showAppMessage(context, 'Everyone now sees the new text settings.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final font = _font ?? widget.controller.font;
        final size = _size ?? widget.controller.textSize;
        final changed = font != widget.controller.font || size != widget.controller.textSize;
        return DashboardPanel(
          title: 'Text',
          subtitle: 'The font and text size everyone sees, on every device',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Heading('Font'),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final columns = constraints.maxWidth >= 560 ? 2 : 1;
                  final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final option in AppFont.values)
                        SizedBox(
                          width: width,
                          child: _FontOption(
                            font: option,
                            selected: option == font,
                            current: option == widget.controller.font,
                            onTap: () => setState(() => _font = option == widget.controller.font ? null : option),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const _Heading('Text Size'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in AppTextSize.values)
                    _SizeChip(
                      size: option,
                      selected: option == size,
                      onTap: () => setState(() => _size = option == widget.controller.textSize ? null : option),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // How text will look, in the chosen font and size.
              Container(
                key: const ValueKey('text-preview'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(size.scale / widget.controller.textSize.scale)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREVIEW',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMutedLight,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Green Valley Phase 2',
                        style: AppTypography.titleLarge.copyWith(
                          fontFamily: font.family,
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plot 24 booked by Priya Sharma · ₹12,50,000 · Due on 15 Dec 2026',
                        style: AppTypography.bodyMedium.copyWith(
                          fontFamily: font.family,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (changed)
                _Note(
                  color: AppColors.primary,
                  text:
                      'Everyone sees the new text settings after you save. '
                      'Screens already open elsewhere change the next time the app starts.',
                ),
              _Actions(
                children: [_SaveButton(buttonKey: const ValueKey('text-save'), enabled: changed, onPressed: _save)],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
    ),
  );
}

/// One font to choose, with a sample written in it.
class _FontOption extends StatelessWidget {
  final AppFont font;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  const _FontOption({required this.font, required this.selected, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mint.withValues(alpha: 0.5) : AppColors.pureWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('font-${font.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.lightBorder, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.offWhite,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Aa',
                  style: TextStyle(
                    fontFamily: font.family,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.pureWhite : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            font.label,
                            style: TextStyle(
                              fontFamily: font.family,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        if (current) ...[const SizedBox(width: 8), _Tag('In use', AppColors.primary)],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      font.description,
                      style: TextStyle(fontFamily: font.family, fontSize: 12.5, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.textMutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One text size to choose; the "A" grows with the size.
class _SizeChip extends StatelessWidget {
  final AppTextSize size;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({required this.size, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.pureWhite : AppColors.textPrimaryLight;
    return Material(
      color: selected ? AppColors.primary : AppColors.pureWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('text-size-${size.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'A',
                textScaler: TextScaler.noScaling,
                style: AppTypography.titleSmall.copyWith(
                  color: color,
                  fontSize: 14 * size.scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                size.label,
                style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Theme: the colour theme everyone sees. Each choice shows a small preview.
class _ThemePanel extends StatefulWidget {
  final ThemeController controller;

  const _ThemePanel({required this.controller});

  @override
  State<_ThemePanel> createState() => _ThemePanelState();
}

class _ThemePanelState extends State<_ThemePanel> {
  /// The choice on screen, before it is saved.
  AppPalette? _choice;

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null) return;
    if (!await runSave(context, () => widget.controller.setPalette(choice)) || !mounted) return;
    setState(() => _choice = null);
    showAppMessage(context, 'Everyone now sees the ${choice.label} theme.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final current = widget.controller.palette;
        final choice = _choice ?? current;
        final changed = choice != current;
        return DashboardPanel(
          title: 'Theme',
          subtitle: 'The colours everyone sees, on every device',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final columns = constraints.maxWidth >= 620 ? 3 : (constraints.maxWidth >= 380 ? 2 : 1);
                  final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final palette in AppPalette.values)
                        SizedBox(
                          width: width,
                          child: _ThemeOption(
                            palette: palette,
                            selected: palette == choice,
                            current: palette == current,
                            onTap: () => setState(() => _choice = palette == current ? null : palette),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (changed)
                _Note(
                  color: choice.primary,
                  text:
                      'Everyone sees the ${choice.label} theme after you save. '
                      'Screens already open elsewhere change the next time the app starts.',
                ),
              _Actions(
                children: [_SaveButton(buttonKey: const ValueKey('theme-save'), enabled: changed, onPressed: _save)],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One colour theme to choose, drawn as a small preview of the app.
class _ThemeOption extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  const _ThemeOption({required this.palette, required this.selected, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Material(
      color: AppColors.pureWhite,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('theme-${p.name}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? p.primary : AppColors.lightBorder, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A small picture of the app in this theme.
              Container(
                height: 86,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [p.deep, p.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 26,
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: p.offWhite, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: 6,
                              width: 60,
                              decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(3)),
                            ),
                            Row(
                              children: [
                                Container(
                                  height: 14,
                                  width: 36,
                                  decoration: BoxDecoration(color: p.pale, borderRadius: BorderRadius.circular(7)),
                                ),
                                const Spacer(),
                                Container(
                                  height: 16,
                                  width: 44,
                                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: selected ? p.primary : AppColors.textMutedLight,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.label,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (current) _Tag('In use', p.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p.description, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final color in [p.deep, p.primary, p.mid, p.soft, p.pale])
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.lightBorder),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One storage to choose, with what it holds now.
class _StorageOption extends StatelessWidget {
  final FileStorage storage;
  final StorageUse use;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  const _StorageOption({
    required this.storage,
    required this.use,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mint.withValues(alpha: 0.5) : AppColors.pureWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('storage-${storage.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.lightBorder, width: selected ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.textMutedLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(storage.icon, size: 18, color: AppColors.primary),
                        Text(
                          storage.label,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (storage == FileStorage.database) const _Tag('Recommended', AppColors.success),
                        if (current) _Tag('In use', AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      storage.description,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Holds ${use.label}',
                      key: ValueKey('storage-use-${storage.name}'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMutedLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Buttons on the right, wrapping on narrow screens.
class _Actions extends StatelessWidget {
  final List<Widget> children;

  const _Actions({required this.children});

  @override
  Widget build(BuildContext context) =>
      Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: children);
}

class _SaveButton extends StatelessWidget {
  final Key buttonKey;
  final bool enabled;
  final VoidCallback onPressed;

  const _SaveButton({required this.buttonKey, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
    child: AppButton.primary(
      key: buttonKey,
      text: 'Save',
      width: null,
      height: 42,
      isDisabled: !enabled,
      icon: const Icon(Icons.check_rounded, color: AppColors.pureWhite, size: 18),
      onPressed: enabled ? onPressed : null,
    ),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(
      text,
      style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

class _Note extends StatelessWidget {
  final Color color;
  final String text;

  const _Note({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryLight)),
  );
}
