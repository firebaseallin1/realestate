import 'package:flutter/material.dart';
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
import '../../widgets/app_file_field.dart';
import '../../widgets/app_form_sheet.dart';
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

  ConstructionTab get _tab => ConstructionTab.values[_tabs.index];

  // Actions

  Future<void> _editStage(ConstructionProject project, ConstructionStage stage) {
    return showAppForm(
      context,
      StageForm(
        stage: stage,
        onSubmit: (status, progress, note) {
          Navigator.of(context).pop();
          _controller.updateStage(project.id, stage.id, status: status, progress: progress, note: note);
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
        onSubmit: (work) {
          Navigator.of(context).pop();
          _controller.addDailyWork(project.id, work);
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
        onSubmit: (worker) {
          Navigator.of(context).pop();
          _controller.addWorker(project.id, worker);
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
        onSubmit: (material) {
          Navigator.of(context).pop();
          _controller.addMaterial(project.id, material);
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
        onSubmit: (edited) {
          Navigator.of(context).pop();
          _controller.updateMaterial(project.id, edited);
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
      file = camera ? await MaterialBillReader.capture() : await AppFileField.pick(MaterialBillReader.extensions);
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

    setState(() => _readingBill = true);
    var parsed = const ParsedBill();
    String? notice;
    try {
      parsed = await MaterialBillReader.read(file);
      if (parsed.lines.isEmpty) {
        notice = 'No items could be picked out of this bill. Add them by hand.';
      }
    } on BillReadException catch (error) {
      notice = error.message;
    }
    if (!mounted) return;
    setState(() => _readingBill = false);

    await showBillCompare(
      context,
      file: file,
      details: MaterialBillForm(
        file: file,
        parsed: parsed,
        notice: notice,
        newId: _controller.newId,
        onSubmit: (bill, items) {
          Navigator.of(context).pop();
          _controller.addMaterialBill(project.id, bill, items);
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

  Future<void> _pay(ConstructionProject project, ExpenseKind kind, String targetId, String name, double due) {
    return showAppForm(
      context,
      ExpensePaymentForm(
        kind: kind,
        targetId: targetId,
        targetName: name,
        due: due,
        newId: _controller.newId('e'),
        onSubmit: (payment) {
          Navigator.of(context).pop();
          _controller.addPayment(project.id, payment);
          showAppMessage(context, '${MoneyText.full(payment.amount)} paid to $name.');
        },
      ),
    );
  }

  /// The add button for the open tab, if it has one.
  (String, IconData, VoidCallback)? _actionFor(ConstructionProject project) {
    switch (_tab) {
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
  Widget build(BuildContext context) {
    final project = _controller.projectById(widget.projectId);
    final wide = Responsive.isWeb(context);

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        floatingActionButton: project == null ? null : _buildAction(project),
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
                              padding: EdgeInsets.fromLTRB(wide ? 20 : 12, 14, wide ? 20 : 12, 88),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1100),
                                  child: _buildTab(project, tab, wide),
                                ),
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

  Widget? _buildAction(ConstructionProject project) {
    final action = _actionFor(project);
    if (action == null) return null;
    final (label, icon, onPressed) = action;
    return FloatingActionButton.extended(
      key: const ValueKey('construction-action'),
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.pureWhite,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildHeader(ConstructionProject project, bool wide) {
    final booking = project.booking;
    final stage = project.currentStage;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimaryLight),
                ),
                const SizedBox(width: 4),
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
            padding: EdgeInsets.fromLTRB(wide ? 64 : 16, 0, 16, 8),
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
          TabBar(
            controller: _tabs,
            isScrollable: !wide,
            tabAlignment: wide ? TabAlignment.fill : TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
            labelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            tabs: [
              for (final tab in ConstructionTab.values)
                Tab(
                  key: ValueKey('tab-${tab.name}'),
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 18),
                      const SizedBox(width: 6),
                      Text(tab.label),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(ConstructionProject project, ConstructionTab tab, bool wide) {
    switch (tab) {
      case ConstructionTab.stages:
        return _StagesTab(project: project, onEdit: (stage) => _editStage(project, stage));
      case ConstructionTab.dailyWork:
        return _DailyWorkTab(project: project);
      case ConstructionTab.workers:
        return _WorkersTab(
          project: project,
          onPay: (w) => _pay(project, ExpenseKind.worker, w.id, w.name, project.wagesDue(w.id)),
        );
      case ConstructionTab.materials:
        return _MaterialsTab(
          project: project,
          readingBill: _readingBill,
          onUploadBill: () => _scanBill(project, camera: false),
          onPhotographBill: MaterialBillReader.canCapture ? () => _scanBill(project, camera: true) : null,
          onViewBill: (bill) => _viewBill(project, bill),
          onEdit: (m) => _editMaterial(project, m),
          onPay: (m) => _pay(project, ExpenseKind.material, m.id, m.name, project.materialDue(m.id)),
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
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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
          ReportColumn('#', flex: 0.4),
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
              ReportTable.text('${i + 1}'),
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
                const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMutedLight),
              ],
            ),
          ),
      ],
    );
  }
}

class _DailyWorkTab extends StatelessWidget {
  final ConstructionProject project;

  const _DailyWorkTab({required this.project});

  @override
  Widget build(BuildContext context) {
    final days = [...project.dailyWork]..sort((a, b) => b.date.compareTo(a.date));
    if (days.isEmpty) {
      return const EmptyNote(icon: Icons.today_outlined, text: 'No work updates yet. Add today\'s update.');
    }

    return ListTableSwitcher(
      id: 'daily-work',
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
                    const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
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
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  day.description,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
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
  final ValueChanged<Worker> onPay;

  const _WorkersTab({required this.project, required this.onPay});

  @override
  Widget build(BuildContext context) {
    if (project.workers.isEmpty) {
      return const EmptyNote(icon: Icons.engineering_outlined, text: 'No workers yet. Add the workers on this site.');
    }

    return ListTableSwitcher(
      id: 'workers',
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
          ReportColumn('', flex: 1.2, numeric: true),
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
              TextButton(
                key: ValueKey('pay-worker-${w.id}'),
                onPressed: project.wagesDue(w.id) > 0 ? () => onPay(w) : null,
                child: Text(project.wagesDue(w.id) > 0 ? 'Pay Wages' : 'Paid up'),
              ),
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
                        style: AppTypography.titleMedium.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
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
                            style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [w.trade.label, '${MoneyText.full(w.dailyWage)}/day', if (w.phone.isNotEmpty) w.phone].join(' · '),
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('pay-worker-${w.id}'),
                    onPressed: project.wagesDue(w.id) > 0 ? () => onPay(w) : null,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(project.wagesDue(w.id) > 0 ? 'Pay Wages' : 'Paid up'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Starts reading a bill: upload a file, or photograph it where the device
/// can read photos.
class _BillScanCard extends StatelessWidget {
  final bool reading;
  final VoidCallback onUpload;
  final VoidCallback? onPhotograph;

  const _BillScanCard({required this.reading, required this.onUpload, required this.onPhotograph});

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: reading
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading ? 'Reading the bill…' : 'Scan a Material Bill',
                      style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Items are listed for you to check and edit before saving',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton.icon(
                key: const ValueKey('bill-upload'),
                onPressed: reading ? null : onUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(onPhotograph == null ? 'Upload PDF' : 'Upload PDF / Photo'),
              ),
              if (onPhotograph != null)
                TextButton.icon(
                  key: const ValueKey('bill-camera'),
                  onPressed: reading ? null : onPhotograph,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Take Photo'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialsTab extends StatelessWidget {
  final ConstructionProject project;
  final bool readingBill;
  final VoidCallback onUploadBill;
  final VoidCallback? onPhotographBill;
  final ValueChanged<MaterialBill> onViewBill;
  final ValueChanged<MaterialEntry> onEdit;
  final ValueChanged<MaterialEntry> onPay;

  const _MaterialsTab({
    required this.project,
    required this.readingBill,
    required this.onUploadBill,
    required this.onPhotographBill,
    required this.onViewBill,
    required this.onEdit,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final materials = [...project.materials]..sort((a, b) => b.date.compareTo(a.date));
    final scanCard = _BillScanCard(reading: readingBill, onUpload: onUploadBill, onPhotograph: onPhotographBill);
    if (materials.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          scanCard,
          const EmptyNote(icon: Icons.inventory_2_outlined, text: 'No materials yet. Add material received at site.'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scanCard,
        const SizedBox(height: 2),
        ListTableSwitcher(
          id: 'materials',
          list: (_) => _buildCards(materials),
          table: (_) => _buildTable(materials),
        ),
      ],
    );
  }

  Widget _buildTable(List<MaterialEntry> materials) {
    return ReportTable(
      minWidth: 1180,
      columns: const [
        ReportColumn('Material', flex: 2),
        ReportColumn('Quantity', flex: 1),
        ReportColumn('Rate', flex: 0.9, numeric: true),
        ReportColumn('Date', flex: 0.9),
        ReportColumn('Supplier', flex: 1.6),
        ReportColumn('Amount', flex: 1, numeric: true),
        ReportColumn('Paid', flex: 1, numeric: true),
        ReportColumn('Due', flex: 1, numeric: true),
        ReportColumn('', flex: 2.3, numeric: true),
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
            ReportTable.text(MoneyText.exact(m.amount)),
            ReportTable.text(MoneyText.exact(project.materialPaid(m.id)), color: AppColors.success),
            ReportTable.text(MoneyText.exact(project.materialDue(m.id)), color: AppColors.error),
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
                      icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                    ),
                  IconButton(
                    key: ValueKey('edit-material-${m.id}'),
                    tooltip: 'Edit',
                    onPressed: () => onEdit(m),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  ),
                  TextButton(
                    key: ValueKey('pay-material-${m.id}'),
                    onPressed: project.materialDue(m.id) > 0 ? () => onPay(m) : null,
                    child: Text(project.materialDue(m.id) > 0 ? 'Pay Bill' : 'Paid up'),
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
                            style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${MoneyText.plain(m.quantity)} ${m.unit} × ${MoneyText.exact(m.rate)} · ${DateText.shortDate(m.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                          ),
                          if (m.supplier.isNotEmpty)
                            Text(
                              m.supplier,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Figure('Amount', MoneyText.full(m.amount)),
                    _Figure('Paid', MoneyText.full(project.materialPaid(m.id)), color: AppColors.success),
                    _Figure('Due', MoneyText.full(project.materialDue(m.id)), color: AppColors.error),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    if (project.billById(m.billId ?? '') case final bill?)
                      TextButton.icon(
                        key: ValueKey('view-bill-${m.id}'),
                        onPressed: () => onViewBill(bill),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('View Bill'),
                      ),
                    TextButton.icon(
                      key: ValueKey('edit-material-${m.id}'),
                      onPressed: () => onEdit(m),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      key: ValueKey('pay-material-${m.id}'),
                      onPressed: project.materialDue(m.id) > 0 ? () => onPay(m) : null,
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text(project.materialDue(m.id) > 0 ? 'Pay Bill' : 'Paid up'),
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
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    MoneyText.full(cost),
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
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
                children: [
                  for (final p in payments) _ExpenseRow(project: project, payment: p),
                ],
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
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
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
