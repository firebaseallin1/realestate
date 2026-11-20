import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/controllers/construction_controller.dart';
import '../../core/services/material_bill_reader.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/material_bill_parser.dart';
import '../../core/utils/money_text.dart';
import '../../core/utils/responsive.dart';
import '../../models/construction.dart';
import '../../models/site.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_file_field.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/full_screen_dialog.dart';
import '../../widgets/list_table_switcher.dart';
import '../booking/widgets/booking_widgets.dart';
import '../dashboard/widgets/dashboard_panel.dart';
import '../dashboard/widgets/dashboard_stats.dart';
import '../dashboard/widgets/report_table.dart';
import 'widgets/construction_forms.dart';
import 'widgets/material_bill_form.dart';

/// The project page's tabs, in order.
enum ConstructionTab {
  stages('Stages', Icons.timeline_rounded),
  dailyWork('Daily Work', Icons.today_rounded),
  workers('Workers', Icons.engineering_rounded),
  materials('Materials', Icons.inventory_2_rounded),
  expenses('Expenses', Icons.account_balance_wallet_rounded);

  const ConstructionTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// ConstructionScreen is one house under construction: progress against
/// the stages, daily work updates with attendance, workers and their
/// wages, materials received, and the payments made for both.
class ConstructionScreen extends StatefulWidget {
  final String projectId;
  final ConstructionController controller;
  final String userName;
  final ConstructionTab initialTab;

  const ConstructionScreen({
    super.key,
    required this.projectId,
    required this.controller,
    required this.userName,
    this.initialTab = ConstructionTab.stages,
  });

  @override
  State<ConstructionScreen> createState() => _ConstructionScreenState();
}

class _ConstructionScreenState extends State<ConstructionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ConstructionTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  )..addListener(_onUpdate);

  ConstructionController get _controller => widget.controller;

  /// A bill is being read.
  bool _readingBill = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _tabs.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  // Actions

  Future<void> _editStage(ConstructionProject project, ConstructionStage stage) {
    return showAppForm(
      context,
      StageForm(
        stage: stage,
        onSubmit: (status, progress, note) async {
          final saved = await runSave(
            context,
            () => _controller.updateStage(project.id, stage.id, status: status, progress: progress, note: note),
          );
          if (!saved || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${stage.name} updated.');
        },
      ),
    );
  }

  Future<void> _addDailyWork(ConstructionProject project) {
    return showAppForm(
      context,
      DailyWorkForm(
        project: project,
        newId: _controller.newId('d'),
        updatedBy: widget.userName,
        onSubmit: (work) async {
          if (!await runSave(context, () => _controller.addDailyWork(project.id, work)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, 'Work update saved for ${DateText.shortDate(work.date)}.');
        },
      ),
    );
  }

  Future<void> _addWorker(ConstructionProject project) {
    return showAppForm(
      context,
      WorkerForm(
        newId: _controller.newId('w'),
        onSubmit: (worker) async {
          if (!await runSave(context, () => _controller.addWorker(project.id, worker)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${worker.name} added as ${worker.trade.label}.');
        },
      ),
    );
  }

  Future<void> _addMaterial(ConstructionProject project) {
    return showAppForm(
      context,
      MaterialForm(
        newId: _controller.newId('m'),
        onSubmit: (material) async {
          if (!await runSave(context, () => _controller.addMaterial(project.id, material)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${material.name} added.');
        },
      ),
    );
  }

  Future<void> _editMaterial(ConstructionProject project, MaterialEntry material) {
    return showAppForm(
      context,
      MaterialForm(
        newId: material.id,
        material: material,
        minAmount: project.materialPaid(material.id),
        onSubmit: (edited) async {
          if (!await runSave(context, () => _controller.updateMaterial(project.id, edited)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${edited.name} updated.');
        },
      ),
    );
  }

  /// Gets a bill from the camera or a file and opens what was read for
  /// review. A bill that cannot be read still opens, to enter it by hand.
  Future<void> _scanBill(ConstructionProject project, {required bool camera}) async {
    final SiteFile? file;
    try {
      file = camera
          ? await MaterialBillReader.capture()
          : await AppFileField.pick(
              _controller.readsBillsOnServer ? MaterialBillReader.serverExtensions : MaterialBillReader.extensions,
            );
    } catch (error, stack) {
      debugPrint('Bill pick failed: $error\n$stack');
      if (mounted) {
        showAppMessage(
          context,
          camera ? 'Could not open the camera. Please check its permission.' : AppFileField.describeError(error),
        );
      }
      return;
    }
    if (file == null || !mounted) return;

    // The same file was scanned before: ask before reading it again.
    var allowDuplicate = false;
    if (project.earlierBill(file: file) case final earlier?) {
      final number = earlier.billNumber.isEmpty ? '' : ' (Bill ${earlier.billNumber})';
      final message = 'This bill was already scanned on ${DateText.shortDate(earlier.scannedOn)}$number.';
      if (!await _confirmDuplicate(message) || !mounted) return;
      allowDuplicate = true;
    }

    setState(() => _readingBill = true);
    var bill = file;
    var parsed = const ParsedBill();
    String? notice;
    var read = false;
    // The server reads scans and handwriting with AI. When it can't, the
    // device reads what it can: text PDFs, and printed photos on phones.
    String? serverProblem;
    if (_controller.readsBillsOnServer) {
      try {
        final (uploaded, result, notes) = await _controller.readBill(file);
        bill = uploaded;
        parsed = result;
        notice = notes.isEmpty ? null : notes;
        read = true;
      } on ApiException catch (error) {
        if (error.code == 'SESSION_ENDED') return;
        if (error.code != 'AI_READING_OFF') serverProblem = error.message;
      }
    }
    if (!read) {
      try {
        parsed = await MaterialBillReader.read(file);
      } on BillReadException catch (error) {
        notice = serverProblem ?? error.message;
      }
    }
    if (parsed.lines.isEmpty && notice == null) {
      notice = serverProblem ?? 'No items could be picked out of this bill. Add them by hand.';
    }
    if (!mounted) return;
    setState(() => _readingBill = false);

    await showBillCompare(
      context,
      file: bill,
      details: MaterialBillForm(
        file: bill,
        parsed: parsed,
        notice: notice,
        newId: _controller.newId,
        onSubmit: (bill, items) async {
          // The server also knows the bill by its number and supplier.
          ApiException? duplicate;
          Future<void> save() async {
            try {
              await _controller.addMaterialBill(project.id, bill, items, allowDuplicate: allowDuplicate);
            } on ApiException catch (error) {
              if (error.code != 'DUPLICATE_BILL') rethrow;
              duplicate = error;
            }
          }

          if (!await runSave(context, save) || !mounted) return;
          if (duplicate case final found?) {
            if (!await _confirmDuplicate(found.message) || !mounted) return;
            allowDuplicate = true;
            duplicate = null;
            if (!await runSave(context, save) || !mounted) return;
          }
          if (!mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${items.length} ${items.length == 1 ? 'item' : 'items'} added from the bill.');
        },
      ),
    );
  }

  Future<void> _viewBill(ConstructionProject project, MaterialBill bill) {
    return showBillCompare(
      context,
      file: bill.file,
      details: MaterialBillView(
        listenable: _controller,
        project: project,
        bill: bill,
        onEdit: (material) => _editMaterial(project, material),
      ),
    );
  }

  /// Every delivery of [material]: when, how much and at what price.
  Future<void> _showHistory(ConstructionProject project, MaterialEntry material) {
    return showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: Dialog(
          key: const ValueKey('material-history'),
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: _MaterialHistory(
              listenable: _controller,
              project: project,
              materialId: material.id,
              onViewBill: (bill) => _viewBill(project, bill),
            ),
          ),
        ),
      ),
    );
  }

  /// Asks before saving a bill that was scanned before; true to save it again.
  Future<bool> _confirmDuplicate(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          key: const ValueKey('duplicate-bill'),
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.warning_amber_rounded, color: AppColors.accentGold, size: 32),
          title: Text(
            'Bill Already Scanned',
            style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryLight),
          ),
          content: Text(
            '$message\n\nAdd it again? Its items will be added to the material quantities again.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
          ),
          actions: [
            TextButton(
              key: const ValueKey('duplicate-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('duplicate-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Add Again'),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  /// The add button for [tab], if it has one.
  (String, IconData, VoidCallback)? _actionFor(ConstructionProject project, ConstructionTab tab) {
    switch (tab) {
      case ConstructionTab.dailyWork:
        return ('Add Work Update', Icons.add_task_rounded, () => _addDailyWork(project));
      case ConstructionTab.workers:
        return ('Add Worker', Icons.person_add_alt_1_rounded, () => _addWorker(project));
      case ConstructionTab.materials:
        return ('Add Material', Icons.add_box_rounded, () => _addMaterial(project));
      case ConstructionTab.stages:
      case ConstructionTab.expenses:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => FullScreenDialogFrame(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final project = _controller.projectById(widget.projectId);
    final wide = Responsive.isWeb(context);

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: SafeArea(
          child: project == null
              ? const Center(child: Text('This project is no longer under construction.'))
              : Column(
                  children: [
                    _buildHeader(project, wide),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          for (final tab in ConstructionTab.values)
                            SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(wide ? 20 : 12, 14, wide ? 20 : 12, 24),
                              child: _buildTab(project, tab, wide),
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

  /// The buttons at the top of [tab], beside its List / Table toggle.
  Widget? _toolsFor(ConstructionProject project, ConstructionTab tab) {
    final action = _actionFor(project, tab);
    final bills = tab == ConstructionTab.materials;
    if (action == null && !bills) return null;

    // Buttons fit their labels rather than stretching across the row.
    Widget fit(Widget button) => IntrinsicWidth(child: button);

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (action case (final label, final icon, final onPressed))
            fit(
              AppButton.primary(
                key: const ValueKey('construction-action'),
                text: label,
                width: null,
                height: 40,
                icon: Icon(icon, color: AppColors.pureWhite, size: 18),
                onPressed: onPressed,
              ),
            ),
          if (bills) ...[
            // Items read from a bill are listed to check before saving.
            fit(
              AppButton.outline(
                key: const ValueKey('bill-upload'),
                text: MaterialBillReader.canCapture || _controller.readsBillsOnServer
                    ? 'Scan Bill (PDF / Photo)'
                    : 'Scan Bill (PDF)',
                width: null,
                height: 40,
                icon: Icon(Icons.document_scanner_outlined, color: AppColors.primary, size: 18),
                onPressed: _readingBill ? null : () => _scanBill(project, camera: false),
              ),
            ),
            if (MaterialBillReader.canCapture)
              fit(
                AppButton.outline(
                  key: const ValueKey('bill-camera'),
                  text: 'Photograph Bill',
                  width: null,
                  height: 40,
                  icon: Icon(Icons.photo_camera_outlined, color: AppColors.primary, size: 18),
                  onPressed: _readingBill ? null : () => _scanBill(project, camera: true),
                ),
              ),
            if (_readingBill)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('Reading the bill…', style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight)),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ConstructionProject project, bool wide) {
    final booking = project.booking;
    final stage = project.currentStage;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${booking.customer.name}'s House",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Plot ${booking.plotNumber} · ${booking.siteName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ProgressRing(progress: project.progress),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 70 : 16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BookingChip(
                    label: stage == null ? 'All stages done' : 'Now: ${stage.name}',
                    icon: Icons.timeline_rounded,
                    color: AppColors.primary,
                  ),
                  BookingChip(
                    label: 'Spent ${MoneyText.short(project.totalPaid)} of ${MoneyText.short(project.budget)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.accentGold,
                  ),
                ],
              ),
            ),
          ),
          // A segmented control: the open tab is a filled brand pill.
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 20 : 12, 2, wide ? 20 : 12, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sageSoft),
              ),
              child: TabBar(
                controller: _tabs,
                isScrollable: !wide,
                tabAlignment: wide ? TabAlignment.fill : TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 10, offset: Offset(0, 3))],
                ),
                splashBorderRadius: BorderRadius.circular(12),
                overlayColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.06)),
                labelColor: AppColors.pureWhite,
                unselectedLabelColor: AppColors.textSecondaryLight,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                labelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                tabs: [
                  for (final tab in ConstructionTab.values)
                    Tab(
                      key: ValueKey('tab-${tab.name}'),
                      height: 40,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(tab.icon, size: 18), const SizedBox(width: 6), Text(tab.label)],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(ConstructionProject project, ConstructionTab tab, bool wide) {
    final tools = _toolsFor(project, tab);
    switch (tab) {
      case ConstructionTab.stages:
        return _StagesTab(project: project, onEdit: (stage) => _editStage(project, stage));
      case ConstructionTab.dailyWork:
        return _DailyWorkTab(project: project, tools: tools);
      case ConstructionTab.workers:
        return _WorkersTab(project: project, tools: tools);
      case ConstructionTab.materials:
        return _MaterialsTab(
          project: project,
          tools: tools,
          onViewBill: (bill) => _viewBill(project, bill),
          onHistory: (m) => _showHistory(project, m),
          onEdit: (m) => _editMaterial(project, m),
        );
      case ConstructionTab.expenses:
        return _ExpensesTab(project: project, wide: wide);
    }
  }
}

class _ProgressRing extends StatelessWidget {
  final int progress;

  const _ProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress / 100,
              strokeWidth: 5,
              backgroundColor: AppColors.mint.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          Text(
            '$progress%',
            key: const ValueKey('project-progress'),
            style: AppTypography.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// White rounded card used for every row in the tabs.
class _RowCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _RowCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small "label / value" figure used in worker and material cards.
class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Figure(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, style: AppTypography.caption.copyWith(color: AppColors.textMutedLight)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: color ?? AppColors.textPrimaryLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StagesTab extends StatelessWidget {
  final ConstructionProject project;
  final ValueChanged<ConstructionStage> onEdit;

  const _StagesTab({required this.project, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final stages = project.stages;

    return ListTableSwitcher(
      id: 'stages',
      list: (_) => _buildCards(stages),
      table: (_) => ReportTable(
        minWidth: 720,
        columns: const [
          ReportColumn('Stage', flex: 2),
          ReportColumn('Status', flex: 1.2),
          ReportColumn('Progress', flex: 0.9, numeric: true),
          ReportColumn('Note', flex: 2.4),
        ],
        rowKeys: [for (var i = 0; i < stages.length; i++) ValueKey('stage-$i')],
        onRowTap: (i) => onEdit(stages[i]),
        rows: [
          for (var i = 0; i < stages.length; i++)
            [
              ReportTable.text(stages[i].name, bold: true),
              ReportTable.pill(stages[i].status.label, stages[i].status.color),
              ReportTable.percent(stages[i].progress / 100),
              ReportTable.text(stages[i].note.isEmpty ? ReportTable.blank : stages[i].note),
            ],
        ],
      ),
    );
  }

  Widget _buildCards(List<ConstructionStage> stages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stages.length; i++)
          _RowCard(
            key: ValueKey('stage-$i'),
            onTap: () => onEdit(stages[i]),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: stages[i].status.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: stages[i].status == StageStatus.completed
                      ? Icon(Icons.check_rounded, size: 18, color: stages[i].status.color)
                      : Text(
                          '${i + 1}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: stages[i].status.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stages[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.textPrimaryLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: BookingChip(
                              label: stages[i].status == StageStatus.inProgress
                                  ? '${stages[i].progress}%'
                                  : stages[i].status.label,
                              icon: stages[i].status.icon,
                              color: stages[i].status.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: stages[i].progress / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.mint.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation(stages[i].status.color),
                        ),
                      ),
                      if (stages[i].note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          stages[i].note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 18, color: AppColors.textMutedLight),
              ],
            ),
          ),
      ],
    );
  }
}

class _DailyWorkTab extends StatelessWidget {
  final ConstructionProject project;
  final Widget? tools;

  const _DailyWorkTab({required this.project, required this.tools});

  @override
  Widget build(BuildContext context) {
    final days = [...project.dailyWork]..sort((a, b) => b.date.compareTo(a.date));

    return ListTableSwitcher(
      id: 'daily-work',
      leading: tools,
      empty: days.isEmpty
          ? const EmptyNote(icon: Icons.today_outlined, text: 'No work updates yet. Add today\'s update.')
          : null,
      list: (_) => _buildCards(days),
      table: (_) => ReportTable(
        minWidth: 900,
        columns: const [
          ReportColumn('Date', flex: 0.9),
          ReportColumn('Stage', flex: 1.3),
          ReportColumn('Work Done', flex: 2.4),
          ReportColumn('Workers', flex: 1.8),
          ReportColumn('Labour Cost', flex: 0.9, numeric: true),
          ReportColumn('Updated By', flex: 1.1),
        ],
        rowKeys: [for (final day in days) ValueKey('daily-row-${day.id}')],
        rows: [
          for (final day in days)
            [
              ReportTable.text(DateText.shortDate(day.date)),
              ReportTable.text(project.stageById(day.stageId)?.name ?? ReportTable.blank),
              ReportTable.text(day.description, bold: true),
              ReportTable.text(day.workerIds.map((id) => project.workerById(id)?.name ?? '?').join(', ')),
              ReportTable.text(MoneyText.full(project.labourCostOf(day))),
              ReportTable.text(day.updatedBy),
            ],
        ],
      ),
    );
  }

  Widget _buildCards(List<DailyWork> days) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days)
          _RowCard(
            key: ValueKey('daily-${day.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      DateText.shortDate(day.date),
                      style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        project.stageById(day.stageId)?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                      ),
                    ),
                    Text(
                      MoneyText.full(project.labourCostOf(day)),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  day.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${day.workerIds.length} workers: '
                  '${day.workerIds.map((id) => project.workerById(id)?.name ?? '?').join(', ')}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                ),
                Text(
                  'Updated by ${day.updatedBy}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkersTab extends StatelessWidget {
  final ConstructionProject project;
  final Widget? tools;

  const _WorkersTab({required this.project, required this.tools});

  @override
  Widget build(BuildContext context) {
    return ListTableSwitcher(
      id: 'workers',
      leading: tools,
      empty: project.workers.isEmpty
          ? const EmptyNote(icon: Icons.engineering_outlined, text: 'No workers yet. Add the workers on this site.')
          : null,
      list: (_) => _buildCards(),
      table: (_) => ReportTable(
        minWidth: 960,
        columns: const [
          ReportColumn('Worker', flex: 1.4),
          ReportColumn('Trade', flex: 1.1),
          ReportColumn('Phone', flex: 1.2),
          ReportColumn('Wage / Day', flex: 0.9, numeric: true),
          ReportColumn('Days', flex: 0.6, numeric: true),
          ReportColumn('Earned', flex: 0.9, numeric: true),
          ReportColumn('Paid', flex: 0.9, numeric: true),
          ReportColumn('Due', flex: 0.9, numeric: true),
        ],
        rowKeys: [for (final w in project.workers) ValueKey('worker-row-${w.id}')],
        rows: [
          for (final w in project.workers)
            [
              ReportTable.text(w.name, bold: true),
              ReportTable.text(w.trade.label),
              ReportTable.text(w.phone.isEmpty ? ReportTable.blank : w.phone),
              ReportTable.text(MoneyText.full(w.dailyWage)),
              ReportTable.text('${project.daysWorked(w.id)}'),
              ReportTable.text(MoneyText.full(project.wagesEarned(w.id))),
              ReportTable.text(MoneyText.full(project.paidTo(w.id)), color: AppColors.success),
              ReportTable.text(MoneyText.full(project.wagesDue(w.id)), color: AppColors.error),
            ],
        ],
      ),
    );
  }

  Widget _buildCards() {
    return CardWrap(
      minCardWidth: 320,
      gap: 12,
      children: [
        for (final w in project.workers)
          _RowCard(
            key: ValueKey('worker-${w.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.mint,
                      child: Text(
                        w.name.isEmpty ? '?' : w.name[0].toUpperCase(),
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.brandDeep,
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
                            w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              w.trade.label,
                              '${MoneyText.full(w.dailyWage)}/day',
                              if (w.phone.isNotEmpty) w.phone,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Figure('Days', '${project.daysWorked(w.id)}'),
                    _Figure('Earned', MoneyText.full(project.wagesEarned(w.id))),
                    _Figure('Paid', MoneyText.full(project.paidTo(w.id)), color: AppColors.success),
                    _Figure('Due', MoneyText.full(project.wagesDue(w.id)), color: AppColors.error),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MaterialsTab extends StatelessWidget {
  final ConstructionProject project;
  final Widget? tools;
  final ValueChanged<MaterialBill> onViewBill;
  final ValueChanged<MaterialEntry> onHistory;
  final ValueChanged<MaterialEntry> onEdit;

  const _MaterialsTab({
    required this.project,
    required this.tools,
    required this.onViewBill,
    required this.onHistory,
    required this.onEdit,
  });

  static String received(MaterialEntry m) {
    final times = m.receipts.length;
    return times == 1 ? 'Received once' : 'Received $times times';
  }

  @override
  Widget build(BuildContext context) {
    final materials = [...project.materials]..sort((a, b) => b.date.compareTo(a.date));
    return ListTableSwitcher(
      id: 'materials',
      leading: tools,
      empty: materials.isEmpty
          ? const EmptyNote(
              icon: Icons.inventory_2_outlined,
              text: 'No materials yet. Add material received at site, or scan a bill.',
            )
          : null,
      list: (_) => _buildCards(materials),
      table: (_) => _buildTable(materials),
    );
  }

  Widget _buildTable(List<MaterialEntry> materials) {
    return ReportTable(
      minWidth: 1100,
      columns: const [
        ReportColumn('Material', flex: 2),
        ReportColumn('Quantity', flex: 1),
        ReportColumn('Last Rate', flex: 0.9, numeric: true),
        ReportColumn('Last Received', flex: 1),
        ReportColumn('Supplier', flex: 1.6),
        ReportColumn('Times', flex: 0.6, numeric: true),
        ReportColumn('Amount', flex: 1, numeric: true),
        ReportColumn('', flex: 1.3, numeric: true),
      ],
      rowKeys: [for (final m in materials) ValueKey('material-row-${m.id}')],
      rows: [
        for (final m in materials)
          [
            ReportTable.text(m.name, bold: true),
            ReportTable.text('${MoneyText.plain(m.quantity)} ${m.unit}'),
            ReportTable.text(MoneyText.exact(m.rate)),
            ReportTable.text(DateText.shortDate(m.date)),
            ReportTable.text(m.supplier.isEmpty ? ReportTable.blank : m.supplier),
            ReportTable.text('${m.receipts.length}'),
            ReportTable.text(MoneyText.exact(m.amount), bold: true),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (project.billById(m.billId ?? '') case final bill?)
                    IconButton(
                      key: ValueKey('view-bill-${m.id}'),
                      tooltip: 'View Bill',
                      onPressed: () => onViewBill(bill),
                      icon: Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                    ),
                  IconButton(
                    key: ValueKey('material-history-${m.id}'),
                    tooltip: 'History',
                    onPressed: () => onHistory(m),
                    icon: Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                  ),
                  IconButton(
                    key: ValueKey('edit-material-${m.id}'),
                    tooltip: 'Edit',
                    onPressed: () => onEdit(m),
                    icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildCards(List<MaterialEntry> materials) {
    return CardWrap(
      minCardWidth: 320,
      gap: 12,
      children: [
        for (final m in materials)
          _RowCard(
            key: ValueKey('material-${m.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.accentGold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              'Last received ${DateText.shortDate(m.date)}',
                              if (m.supplier.isNotEmpty) m.supplier,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Figure('Quantity', '${MoneyText.plain(m.quantity)} ${m.unit}'),
                    _Figure('Last Rate', MoneyText.exact(m.rate)),
                    _Figure('Amount', MoneyText.full(m.amount)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        received(m),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMutedLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (project.billById(m.billId ?? '') case final bill?)
                      IconButton(
                        key: ValueKey('view-bill-${m.id}'),
                        tooltip: 'View Bill',
                        onPressed: () => onViewBill(bill),
                        icon: Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
                      ),
                    IconButton(
                      key: ValueKey('material-history-${m.id}'),
                      tooltip: 'History',
                      onPressed: () => onHistory(m),
                      icon: Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                    ),
                    IconButton(
                      key: ValueKey('edit-material-${m.id}'),
                      tooltip: 'Edit',
                      onPressed: () => onEdit(m),
                      icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// _MaterialHistory lists every delivery of one material, newest first:
/// the quantity and price on each bill, and when it was scanned.
class _MaterialHistory extends StatelessWidget {
  final Listenable listenable;
  final ConstructionProject project;
  final String materialId;
  final ValueChanged<MaterialBill> onViewBill;

  const _MaterialHistory({
    required this.listenable,
    required this.project,
    required this.materialId,
    required this.onViewBill,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final material = project.materialById(materialId);
        if (material == null) return const SizedBox.shrink();
        final receipts = material.receipts.reversed.toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.name,
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_MaterialsTab.received(material)} · '
                          '${MoneyText.plain(material.quantity)} ${material.unit} in all',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.lightBorder),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: receipts.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.lightBorder),
                itemBuilder: (context, i) => _ReceiptRow(
                  key: ValueKey('history-row-$i'),
                  receipt: receipts[i],
                  unit: material.unit,
                  bill: project.billById(receipts[i].billId ?? ''),
                  onViewBill: onViewBill,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One delivery: quantity at its price, the bill it came on and when it
/// was scanned.
class _ReceiptRow extends StatelessWidget {
  final MaterialReceipt receipt;
  final String unit;
  final MaterialBill? bill;
  final ValueChanged<MaterialBill> onViewBill;

  const _ReceiptRow({
    super.key,
    required this.receipt,
    required this.unit,
    required this.bill,
    required this.onViewBill,
  });

  @override
  Widget build(BuildContext context) {
    final scanned = receipt.billId != null;
    final details = [
      'Received ${DateText.shortDate(receipt.date)}',
      if (receipt.supplier.isNotEmpty) receipt.supplier,
      if (receipt.billNumber.isNotEmpty) 'Bill ${receipt.billNumber}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              scanned ? Icons.document_scanner_outlined : Icons.edit_note_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${MoneyText.plain(receipt.quantity)} $unit at ${MoneyText.exact(receipt.rate)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(details, style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight)),
                Text(
                  '${scanned ? 'Scanned' : 'Added'} on ${DateText.shortDate(receipt.addedAt)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyText.full(receipt.amount),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
              ),
              if (bill case final bill?)
                TextButton(
                  onPressed: () => onViewBill(bill),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('View Bill'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  final ConstructionProject project;
  final bool wide;

  const _ExpensesTab({required this.project, required this.wide});

  @override
  Widget build(BuildContext context) {
    final payments = [...project.payments]..sort((a, b) => b.date.compareTo(a.date));

    Widget line(String label, double cost, double paid) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                MoneyText.full(cost),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PaidProgress(paid: paid, total: cost),
        ],
      ),
    );

    final breakdown = DashboardPanel(
      title: 'Cost Breakdown',
      subtitle: 'Wages earned and materials received, against what is paid',
      child: Column(
        children: [
          line('Labour (worker wages)', project.labourCost, project.labourPaid),
          line('Materials', project.materialCost, project.materialPaidTotal),
        ],
      ),
    );

    final history = DashboardPanel(
      title: 'Payment History',
      subtitle: 'Worker and material payments',
      child: payments.isEmpty
          ? const EmptyNote(icon: Icons.receipt_long_outlined, text: 'No payments yet.')
          : ListTableSwitcher(
              id: 'expenses',
              list: (_) => Column(
                children: [for (final p in payments) _ExpenseRow(project: project, payment: p)],
              ),
              table: (_) => ReportTable(
                minWidth: 720,
                columns: const [
                  ReportColumn('Paid To', flex: 1.6),
                  ReportColumn('Type', flex: 1.3),
                  ReportColumn('Date', flex: 0.9),
                  ReportColumn('Method', flex: 1.1),
                  ReportColumn('Reference', flex: 1.1),
                  ReportColumn('Amount', flex: 1, numeric: true),
                ],
                rows: [
                  for (final p in payments)
                    [
                      ReportTable.text(
                        (p.kind == ExpenseKind.worker
                                ? project.workerById(p.targetId)?.name
                                : project.materialById(p.targetId)?.name) ??
                            ReportTable.blank,
                        bold: true,
                      ),
                      ReportTable.text(p.kind.label),
                      ReportTable.text(DateText.shortDate(p.date)),
                      ReportTable.text(p.method.label),
                      ReportTable.text(p.reference.isEmpty ? ReportTable.blank : p.reference),
                      ReportTable.text(MoneyText.full(p.amount), bold: true, color: AppColors.error),
                    ],
                ],
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardGrid(
          columns: wide ? 4 : 2,
          cards: [
            StatCard(
              icon: Icons.home_work_outlined,
              color: AppColors.primary,
              label: 'Construction Value',
              value: MoneyText.short(project.budget),
              caption: 'From the booking',
            ),
            StatCard(
              icon: Icons.north_east_rounded,
              color: AppColors.success,
              label: 'Total Paid',
              value: MoneyText.short(project.totalPaid),
              caption: 'Wages + materials',
            ),
            StatCard(
              icon: Icons.pending_actions_rounded,
              color: AppColors.error,
              label: 'Payments Due',
              value: MoneyText.short(project.totalDue),
              caption: 'Unpaid wages and bills',
            ),
            StatCard(
              icon: Icons.savings_outlined,
              color: AppColors.accentGold,
              label: 'Budget Left',
              value: MoneyText.short(project.budget - project.totalCost),
              caption: 'Value minus costs so far',
            ),
          ],
        ),
        SizedBox(height: wide ? 16 : 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: breakdown),
              const SizedBox(width: 16),
              Expanded(child: history),
            ],
          )
        else ...[
          breakdown,
          const SizedBox(height: 12),
          history,
        ],
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final ConstructionProject project;
  final ExpensePayment payment;

  const _ExpenseRow({required this.project, required this.payment});

  @override
  Widget build(BuildContext context) {
    final name = payment.kind == ExpenseKind.worker
        ? project.workerById(payment.targetId)?.name
        : project.materialById(payment.targetId)?.name;
    final details = [
      payment.kind.label,
      DateText.shortDate(payment.date),
      payment.method.label,
      if (payment.reference.isNotEmpty) payment.reference,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(payment.kind.icon, size: 18, color: AppColors.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            MoneyText.full(payment.amount),
            style: AppTypography.titleSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
