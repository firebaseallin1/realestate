import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// How a screen shows its records.
enum ListViewMode {
  list('List', Icons.view_agenda_outlined),
  table('Table', Icons.table_rows_outlined);

  const ListViewMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// ListTableSwitcher shows a screen's records as a [list] or a [table], with
/// a List / Table toggle above them. The choice is remembered per [id] while
/// the app runs, so moving between screens keeps it. [empty] replaces both
/// when there is nothing to show; [leading] sits beside the toggle.
class ListTableSwitcher extends StatefulWidget {
  final String id;
  final Widget? leading;
  final Widget? empty;
  final WidgetBuilder list;
  final WidgetBuilder table;

  const ListTableSwitcher({
    super.key,
    required this.id,
    this.leading,
    this.empty,
    required this.list,
    required this.table,
  });

  static final Map<String, ListViewMode> _remembered = {};

  /// Clears the remembered choices, for tests.
  @visibleForTesting
  static void reset() => _remembered.clear();

  @override
  State<ListTableSwitcher> createState() => _ListTableSwitcherState();
}

class _ListTableSwitcherState extends State<ListTableSwitcher> {
  ListViewMode get _mode => ListTableSwitcher._remembered[widget.id] ?? ListViewMode.list;

  void _select(ListViewMode mode) => setState(() => ListTableSwitcher._remembered[widget.id] = mode);

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.empty ??
        (_mode == ListViewMode.list ? widget.list(context) : widget.table(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: widget.leading ?? const SizedBox.shrink()),
            const SizedBox(width: 8),
            _ModeToggle(id: widget.id, selected: _mode, onSelected: _select),
          ],
        ),
        const SizedBox(height: 10),
        content,
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final String id;
  final ListViewMode selected;
  final ValueChanged<ListViewMode> onSelected;

  const _ModeToggle({required this.id, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ListViewMode.values)
            Material(
              color: mode == selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                key: ValueKey('view-${mode.name}-$id'),
                onTap: () => onSelected(mode),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode.icon,
                        size: 16,
                        color: mode == selected ? AppColors.pureWhite : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        mode.label,
                        style: AppTypography.caption.copyWith(
                          color: mode == selected ? AppColors.pureWhite : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
