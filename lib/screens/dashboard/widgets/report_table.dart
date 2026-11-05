import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// ReportColumn describes one column of a [ReportTable].
class ReportColumn {
  final String label;
  final double flex;
  final bool numeric;

  const ReportColumn(this.label, {this.flex = 1, this.numeric = false});
}

/// ReportTable is the white report grid used by every report and table view:
/// a tinted header, striped rows and an optional bold totals row. On narrow
/// screens it keeps [minWidth] and scrolls sideways. [onRowTap] makes rows
/// tappable and [rowKeys] names them.
class ReportTable extends StatelessWidget {
  final List<ReportColumn> columns;
  final List<List<Widget>> rows;
  final List<Widget>? totals;
  final double minWidth;
  final ValueChanged<int>? onRowTap;
  final List<Key>? rowKeys;

  const ReportTable({
    super.key,
    required this.columns,
    required this.rows,
    this.totals,
    this.minWidth = 720,
    this.onRowTap,
    this.rowKeys,
  });

  /// Shown for a value that was not entered.
  static const String blank = '—';

  /// Plain text cell; numeric columns align right.
  static Widget text(String value, {bool bold = false, Color? color}) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyMedium.copyWith(
        color: color ?? AppColors.textPrimaryLight,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  /// Percentage with a small progress bar under it.
  static Widget percent(double ratio, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        text('${(ratio * 100).round()}%', bold: bold),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppColors.lightSurfaceVariant,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  /// Small colored pill, e.g. for a status.
  static Widget pill(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, minWidth);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _row(
                    [
                      for (final c in columns)
                        Text(
                          c.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                    background: AppColors.mint.withValues(alpha: 0.45),
                    verticalPadding: 13,
                  ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No data for this selection.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                      ),
                    ),
                  for (var i = 0; i < rows.length; i++)
                    _row(
                      rows[i],
                      key: rowKeys?[i],
                      background: i.isOdd ? AppColors.offWhite : AppColors.pureWhite,
                      onTap: onRowTap == null ? null : () => onRowTap!(i),
                    ),
                  if (totals != null)
                    _row(
                      totals!,
                      background: AppColors.mint.withValues(alpha: 0.3),
                      topBorder: true,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(
    List<Widget> cells, {
    Key? key,
    required Color background,
    double verticalPadding = 12,
    bool topBorder = false,
    VoidCallback? onTap,
  }) {
    return Material(
      key: key,
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: topBorder ? AppColors.sageSoft : AppColors.lightBorder,
                width: topBorder ? 1.5 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  flex: (columns[i].flex * 10).round(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Align(
                      alignment: columns[i].numeric ? Alignment.centerRight : Alignment.centerLeft,
                      child: i < cells.length ? cells[i] : const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
