import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/controllers/site_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/money_text.dart';
import '../../core/utils/responsive.dart';
import '../../models/site.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_file_field.dart';
import '../../widgets/list_table_switcher.dart';
import '../dashboard/widgets/dashboard_panel.dart';
import '../dashboard/widgets/report_table.dart';
import 'widgets/plot_canvas.dart';
import 'widgets/plot_form.dart';

/// SiteLayoutScreen is the mapped view of one site: its plots drawn over
/// the site map (or graph paper), a toolbar to draw plots and attach the
/// map, and a list of plots. Changes save straight to the site, and the
/// site's unit counts follow the plots.
class SiteLayoutScreen extends StatefulWidget {
  final String siteId;
  final SiteController controller;

  const SiteLayoutScreen({
    super.key,
    required this.siteId,
    required this.controller,
  });

  @override
  State<SiteLayoutScreen> createState() => _SiteLayoutScreenState();
}

class _SiteLayoutScreenState extends State<SiteLayoutScreen> {
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Site? get _site => widget.controller.siteById(widget.siteId);

  void _savePlots(Site site, List<Plot> plots) {
    widget.controller.updateSite(site.withPlots(plots));
  }

  /// Next free plot number: one more than the highest numeric one.
  String _suggestNumber(Site site) {
    final numbers = site.plots.map((p) => int.tryParse(p.number)).whereType<int>();
    return '${numbers.isEmpty ? 1 : numbers.reduce(math.max) + 1}';
  }

  Future<void> _onDrawn(Site site, Rect rect) async {
    await _showSheet(
      PlotForm(
        rect: rect,
        takenNumbers: site.plots.map((p) => p.number).toList(),
        suggestedNumber: _suggestNumber(site),
        onSubmit: (plot) {
          Navigator.of(context).pop();
          _savePlots(site, [...site.plots, plot]);
        },
      ),
    );
  }

  Future<void> _editPlot(Site site, Plot plot) async {
    await _showSheet(
      PlotForm(
        plot: plot,
        rect: plot.rect,
        takenNumbers: site.plots.map((p) => p.number).toList(),
        suggestedNumber: plot.number,
        onSubmit: (updated) {
          Navigator.of(context).pop();
          _savePlots(site, [for (final p in site.plots) p.id == updated.id ? updated : p]);
        },
        onDelete: () {
          Navigator.of(context).pop();
          _savePlots(site, site.plots.where((p) => p.id != plot.id).toList());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plot ${plot.number} deleted.')),
          );
        },
      ),
    );
  }

  Future<void> _uploadMap(Site site) async {
    try {
      final file = await AppFileField.pick(SiteFile.imageExtensions);
      if (file != null) widget.controller.updateSite(site.copyWith(siteMap: file));
    } catch (error, stack) {
      debugPrint('Site map pick failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppFileField.describeError(error))),
        );
      }
    }
  }

  /// Dialog on web, bottom sheet on phones — same as the dashboard forms.
  Future<void> _showSheet(Widget form) async {
    if (Responsive.isWeb(context)) {
      await showDialog<void>(
        context: context,
        builder: (context) => Theme(
          data: AppTheme.lightTheme,
          child: Dialog(
            backgroundColor: AppColors.pureWhite,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: form,
              ),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.pureWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => Theme(
          data: AppTheme.lightTheme,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: form,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = _site;

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: SafeArea(
          child: site == null
              ? const Center(child: Text('This site no longer exists.'))
              : Column(
                  children: [
                    _buildHeader(site),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= Responsive.webBreakpoint;
                          return SingleChildScrollView(
                            // The page holds still while drawing, so a drag
                            // draws a plot instead of scrolling.
                            physics: _drawing ? const NeverScrollableScrollPhysics() : null,
                            padding: EdgeInsets.all(wide ? 20 : 12),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1400),
                                child: _buildBody(site, wide),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(Site site) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimaryLight),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLOT LAYOUT',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  site.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${site.location} • ${site.type.label}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Site site, bool wide) {
    final canvasCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _drawing ? AppColors.primary : AppColors.lightBorder, width: _drawing ? 2 : 1),
      ),
      child: PlotCanvas(
        site: site,
        drawing: _drawing,
        onDrawn: (rect) => _onDrawn(site, rect),
        onPlotTap: (plot) => _editPlot(site, plot),
      ),
    );
    final list = _PlotList(site: site, onTap: (plot) => _editPlot(site, plot));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(site),
        const SizedBox(height: 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: canvasCard),
              const SizedBox(width: 14),
              SizedBox(width: 360, child: list),
            ],
          )
        else ...[
          canvasCard,
          const SizedBox(height: 12),
          list,
        ],
      ],
    );
  }

  Widget _buildToolbar(Site site) {
    int count(PlotStatus s) => site.plots.where((p) => p.status == s).length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _drawing
            ? AppButton.outline(
                key: const ValueKey('toggle-draw'),
                text: 'Done Drawing',
                width: null,
                height: 46,
                icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
                onPressed: () => setState(() => _drawing = false),
              )
            : AppButton.primary(
                key: const ValueKey('toggle-draw'),
                text: 'Draw Plot',
                width: null,
                height: 46,
                icon: const Icon(Icons.draw_rounded, color: Colors.white, size: 16),
                onPressed: () => setState(() => _drawing = true),
              ),
        AppButton.outline(
          text: site.siteMap == null ? 'Upload Site Map' : 'Replace Site Map',
          width: null,
          height: 46,
          icon: const Icon(Icons.map_outlined, color: AppColors.primary, size: 18),
          onPressed: () => _uploadMap(site),
        ),
        if (_drawing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Drag on the layout to draw a plot',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final status in PlotStatus.values)
          _LegendChip(
            color: plotStatusColor(status),
            label: '${status.label} ${count(status)}',
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every plot with its size, area, facing and status; tap to edit.
class _PlotList extends StatelessWidget {
  final Site site;
  final ValueChanged<Plot> onTap;

  const _PlotList({required this.site, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final plots = [...site.plots]..sort((a, b) {
        final na = int.tryParse(a.number);
        final nb = int.tryParse(b.number);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.number.compareTo(b.number);
      });
    final totalSqYd = plots.fold<double>(0, (sum, p) => sum + p.areaSqYd);

    return DashboardPanel(
      title: 'Plots',
      subtitle: plots.isEmpty
          ? 'Nothing drawn yet'
          : '${plots.length} plots • ${totalSqYd.toStringAsFixed(0)} sq yd in total',
      child: plots.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Tap "Draw Plot", then drag on the layout to mark each plot. '
                'Its size, facing and status are asked next.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
              ),
            )
          : ListTableSwitcher(
              id: 'plots',
              list: (_) => Column(
                children: [
                  for (var i = 0; i < plots.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.lightBorder),
                    InkWell(
                      onTap: () => onTap(plots[i]),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: _PlotRow(plot: plots[i]),
                      ),
                    ),
                  ],
                ],
              ),
              table: (_) => ReportTable(
                minWidth: 680,
                columns: const [
                  ReportColumn('Plot', flex: 0.7),
                  ReportColumn('Size', flex: 1.2),
                  ReportColumn('Area (sq yd)', flex: 1, numeric: true),
                  ReportColumn('Facing', flex: 1),
                  ReportColumn('Price', flex: 1, numeric: true),
                  ReportColumn('Status', flex: 1),
                ],
                rowKeys: [for (final p in plots) ValueKey('plot-row-${p.number}')],
                onRowTap: (i) => onTap(plots[i]),
                rows: [
                  for (final p in plots)
                    [
                      ReportTable.text(p.number, bold: true),
                      ReportTable.text(p.sizeLabel),
                      ReportTable.text(p.areaSqYd.toStringAsFixed(1)),
                      ReportTable.text(p.facing.label),
                      ReportTable.text(p.price == null ? ReportTable.blank : MoneyText.full(p.price!)),
                      ReportTable.pill(p.status.label, plotStatusColor(p.status)),
                    ],
                ],
              ),
            ),
    );
  }
}

class _PlotRow extends StatelessWidget {
  final Plot plot;

  const _PlotRow({required this.plot});

  @override
  Widget build(BuildContext context) {
    final color = plotStatusColor(plot.status);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            plot.number,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plot.sizeLabel} • ${plot.areaSqYd.toStringAsFixed(1)} sq yd',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
              ),
              Row(
                children: [
                  Transform.rotate(
                    angle: plot.facing.degrees * math.pi / 180,
                    child: const Icon(Icons.navigation_rounded, size: 12, color: AppColors.textMutedLight),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${plot.facing.label} facing'
                      '${plot.price == null ? '' : ' • ₹${plot.price!.toStringAsFixed(0)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            plot.status.label,
            style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
