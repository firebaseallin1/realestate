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
import '../../widgets/app_form_sheet.dart';
import '../../widgets/full_screen_dialog.dart';
import '../../widgets/list_table_switcher.dart';
import '../booking/widgets/booking_widgets.dart';
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

  /// Opens the layout as a full-screen dialog: it slides up over the
  /// dashboard, which stays dimmed behind it on wide screens.
  static Future<void> open(BuildContext context, {required String siteId, required SiteController controller}) =>
      pushFullScreenDialog(
        context,
        (_) => SiteLayoutScreen(siteId: siteId, controller: controller),
        label: 'Plot layout',
      );

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

  Future<bool> _savePlots(Site site, List<Plot> plots) =>
      runSave(context, () => widget.controller.savePlots(site, plots));

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
        onDelete: () async {
          Navigator.of(context).pop();
          final saved = await _savePlots(site, site.plots.where((p) => p.id != plot.id).toList());
          if (saved && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Plot ${plot.number} deleted.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _uploadMap(Site site) async {
    try {
      final file = await AppFileField.pick(SiteFile.imageExtensions);
      if (file != null && mounted) {
        await runSave(context, () => widget.controller.updateSite(site.copyWith(siteMap: file)));
      }
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

    final page = Theme(
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
                                constraints: const BoxConstraints(maxWidth: 1300),
                                child: _buildBody(site, wide),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildActions(site),
                  ],
                ),
        ),
      ),
    );

    return FullScreenDialogFrame(child: page);
  }

  /// Same header as the Booking and Construction pages: back, title,
  /// one line of detail, and a summary chip on the right.
  Widget _buildHeader(Site site) {
    final plots = site.plots.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'Plot layout · ${site.location} · ${site.type.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BookingChip(
            label: '$plots ${plots == 1 ? 'plot' : 'plots'}',
            icon: Icons.grid_view_rounded,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Site site, bool wide) {
    final list = _PlotList(site: site, onTap: (plot) => _editPlot(site, plot));

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildLayoutCard(site)),
          const SizedBox(width: 16),
          SizedBox(width: 360, child: list),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLayoutCard(site),
        const SizedBox(height: 14),
        list,
      ],
    );
  }

  /// The drawing in a titled card, with the status key above it.
  Widget _buildLayoutCard(Site site) {
    int count(PlotStatus s) => site.plots.where((p) => p.status == s).length;

    return DashboardPanel(
      title: 'Layout',
      subtitle: site.siteMap == null ? 'Drawn on graph paper' : 'Drawn over the site map',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in PlotStatus.values)
                _LegendChip(
                  color: plotStatusColor(status),
                  label: '${status.label} ${count(status)}',
                ),
            ],
          ),
          if (_drawing) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drag on the layout to draw a plot',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _drawing ? AppColors.primary : AppColors.lightBorder,
                width: _drawing ? 2 : 1,
              ),
            ),
            child: PlotCanvas(
              site: site,
              drawing: _drawing,
              onDrawn: (rect) => _onDrawn(site, rect),
              onPlotTap: (plot) => _editPlot(site, plot),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom bar, as on the Booking page: buttons on the right on web,
  /// sharing the width on phones.
  Widget _buildActions(Site site) {
    final wide = Responsive.isWeb(context);
    final buttons = <Widget>[
      AppButton.outline(
        key: const ValueKey('site-map-button'),
        text: site.siteMap == null ? 'Upload Site Map' : 'Replace Site Map',
        width: wide ? 210 : double.infinity,
        icon: Icon(Icons.map_outlined, color: AppColors.primary, size: 18),
        onPressed: () => _uploadMap(site),
      ),
      _drawing
          ? AppButton.primary(
              key: const ValueKey('toggle-draw'),
              text: 'Done Drawing',
              width: wide ? 190 : double.infinity,
              gradient: AppColors.brandGradient,
              icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              onPressed: () => setState(() => _drawing = false),
            )
          : AppButton.primary(
              key: const ValueKey('toggle-draw'),
              text: 'Draw Plot',
              width: wide ? 190 : double.infinity,
              gradient: AppColors.brandGradient,
              icon: const Icon(Icons.draw_rounded, color: Colors.white, size: 16),
              onPressed: () => setState(() => _drawing = true),
            ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, wide ? 32 : 16, 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(top: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            wide ? buttons[i] : Expanded(child: buttons[i]),
          ],
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightSurfaceVariant,
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
                    if (i > 0) Divider(height: 1, color: AppColors.lightBorder),
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
                    child: Icon(Icons.navigation_rounded, size: 12, color: AppColors.textMutedLight),
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
