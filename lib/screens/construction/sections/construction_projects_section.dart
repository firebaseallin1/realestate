import 'package:flutter/material.dart';
import '../../../core/controllers/construction_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/app_user.dart';
import '../../../models/construction.dart';
import '../../../widgets/app_dropdown.dart';
import '../../../widgets/band_card.dart';
import '../../../widgets/list_table_switcher.dart';
import '../../booking/widgets/booking_widgets.dart';
import '../../dashboard/widgets/dashboard_section.dart';
import '../../dashboard/widgets/dashboard_stats.dart';
import '../../dashboard/widgets/report_table.dart';
import '../construction_screen.dart';

/// ConstructionProjectsSection lists the houses under construction for the
/// Construction and Site Work pages. Each page opens a project at its own
/// tab (Daily Construction → Daily Work, Labour → Workers, ...). Site
/// Assignment also picks each project's Site Incharge, and Progress
/// Monitoring adds totals across projects.
class ConstructionProjectsSection extends StatelessWidget {
  final ConstructionController controller;
  final AppUser user;
  final DashboardSection section;
  final List<AppUser> incharges;
  final bool wide;
  final void Function(ConstructionProject project, ConstructionTab tab) onOpenProject;
  final void Function(ConstructionProject project, String? inchargeId) onAssign;

  const ConstructionProjectsSection({
    super.key,
    required this.controller,
    required this.user,
    required this.section,
    required this.incharges,
    required this.wide,
    required this.onOpenProject,
    required this.onAssign,
  });

  /// The project tab each page opens.
  static ConstructionTab tabFor(DashboardSection section) => switch (section) {
        DashboardSection.dailyConstruction => ConstructionTab.dailyWork,
        DashboardSection.labor => ConstructionTab.workers,
        DashboardSection.materials => ConstructionTab.materials,
        DashboardSection.progressMonitoring => ConstructionTab.expenses,
        _ => ConstructionTab.stages,
      };

  String? _inchargeName(String? id) {
    for (final u in incharges) {
      if (u.id == id) return u.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final projects = controller.projectsFor(user);

    if (projects.isEmpty) {
      return EmptyNote(
        icon: Icons.home_work_outlined,
        text: user.role == UserRole.siteIncharge
            ? 'No houses are assigned to you yet. Your Site Manager assigns them.'
            : 'No construction yet. A project starts when a With Construction booking is approved.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section == DashboardSection.progressMonitoring) ...[
          _totals(projects),
          SizedBox(height: wide ? 16 : 12),
        ],
        ListTableSwitcher(
          id: 'projects',
          list: (_) => CardWrap(
            minCardWidth: 340,
            children: [
              for (final project in projects) _projectCard(project),
            ],
          ),
          table: (_) => _projectTable(projects),
        ),
      ],
    );
  }

  bool get _canAssign => section == DashboardSection.siteAssignment && user.role != UserRole.siteIncharge;

  /// The projects one row each; on Site Assignment the last column picks
  /// the incharge. Tapping a row opens the project, like its card.
  Widget _projectTable(List<ConstructionProject> projects) {
    return ReportTable(
      minWidth: 1120,
      columns: const [
        ReportColumn('House', flex: 1.7),
        ReportColumn('Site', flex: 1.7),
        ReportColumn('Plot', flex: 0.6),
        ReportColumn('Stage', flex: 1.5),
        ReportColumn('Progress', flex: 0.9, numeric: true),
        ReportColumn('Spent', flex: 0.9, numeric: true),
        ReportColumn('Budget', flex: 0.9, numeric: true),
        ReportColumn('Due', flex: 0.9, numeric: true),
        ReportColumn('Site Incharge', flex: 1.9),
      ],
      rowKeys: [for (final p in projects) ValueKey('project-${p.id}')],
      onRowTap: (i) => onOpenProject(projects[i], tabFor(section)),
      rows: [
        for (final project in projects)
          [
            ReportTable.text("${project.booking.customer.name}'s House", bold: true),
            ReportTable.text(project.booking.siteName),
            ReportTable.text(project.booking.plotNumber),
            ReportTable.text(project.currentStage?.name ?? 'All stages done'),
            ReportTable.percent(project.progress / 100),
            ReportTable.text(MoneyText.short(project.totalPaid)),
            ReportTable.text(MoneyText.short(project.budget)),
            ReportTable.text(
              MoneyText.short(project.totalDue),
              color: project.totalDue > 0 ? AppColors.error : AppColors.success,
            ),
            if (_canAssign)
              _inchargePicker(project, withLabel: false)
            else
              ReportTable.text(
                _inchargeName(project.inchargeId) ?? 'Not assigned',
                color: project.inchargeId == null ? AppColors.error : null,
              ),
          ],
      ],
    );
  }

  Widget _inchargePicker(ConstructionProject project, {bool withLabel = true}) {
    return AppDropdown<String>(
      key: ValueKey('assign-${project.id}'),
      label: withLabel ? 'Site Incharge' : null,
      hint: 'Not assigned',
      value: project.inchargeId,
      margin: EdgeInsets.zero,
      prefixIcon: withLabel ? const Icon(Icons.assignment_ind_outlined) : null,
      items: [
        for (final u in incharges) AppDropdownOption(value: u.id, title: u.name, subtitle: u.phone),
      ],
      onChanged: (id) => onAssign(project, id),
    );
  }

  Widget _totals(List<ConstructionProject> projects) {
    final avg = (projects.fold<int>(0, (sum, p) => sum + p.progress) / projects.length).round();
    final paid = projects.fold<double>(0, (sum, p) => sum + p.totalPaid);
    final due = projects.fold<double>(0, (sum, p) => sum + p.totalDue);
    final unassigned = projects.where((p) => p.inchargeId == null).length;

    return StatCardGrid(
      columns: wide ? 4 : 2,
      cards: [
        StatCard(
          icon: Icons.home_work_outlined,
          color: AppColors.primary,
          label: 'Houses',
          value: '${projects.length}',
          caption: unassigned == 0 ? 'All assigned' : '$unassigned not assigned',
        ),
        StatCard(
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
          label: 'Avg. Progress',
          value: '$avg%',
          caption: 'Across all stages',
        ),
        StatCard(
          icon: Icons.north_east_rounded,
          color: AppColors.accentGold,
          label: 'Spent',
          value: MoneyText.short(paid),
          caption: 'Wages + materials paid',
        ),
        StatCard(
          icon: Icons.pending_actions_rounded,
          color: AppColors.error,
          label: 'Payments Due',
          value: MoneyText.short(due),
          caption: 'Unpaid wages and bills',
        ),
      ],
    );
  }

  /// A teal [BandCard]: current stage and progress on the band, then the
  /// house, its progress bar, spending and Site Incharge (or, on Site
  /// Assignment, the incharge picker).
  Widget _projectCard(ConstructionProject project) {
    const color = Color(0xFF2E8B83);
    final booking = project.booking;
    final stage = project.currentStage;
    final incharge = _inchargeName(project.inchargeId);

    return BandCard(
      key: ValueKey('project-${project.id}'),
      color: color,
      onTap: () => onOpenProject(project, tabFor(section)),
      avatar: BandCard.avatarCircle(color, const Icon(Icons.home_work_rounded, color: AppColors.pureWhite, size: 24)),
      badges: [
        BandBadge(
          icon: stage == null ? Icons.task_alt_rounded : Icons.timeline_rounded,
          label: stage == null ? 'All stages done' : stage.name,
        ),
      ],
      trailing: Text(
        '${project.progress}%',
        style: AppTypography.titleLarge.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
      ),
      children: [
        BandTitle(
          title: "${booking.customer.name}'s House",
          subtitle: 'Plot ${booking.plotNumber} · ${booking.siteName}',
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: project.progress / 100,
            minHeight: 7,
            backgroundColor: AppColors.mint.withValues(alpha: 0.5),
            valueColor: const AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 10),
        BandInfoBox(
          children: [
            BandInfoLine(
              icon: Icons.account_balance_wallet_outlined,
              text: 'Spent ${MoneyText.short(project.totalPaid)} of ${MoneyText.short(project.budget)}',
              color: AppColors.accentGold,
            ),
            BandInfoLine(
              icon: Icons.pending_actions_rounded,
              text: project.totalDue > 0 ? '${MoneyText.short(project.totalDue)} payments due' : 'No payments due',
              color: project.totalDue > 0 ? AppColors.error : AppColors.success,
            ),
            if (!_canAssign)
              BandInfoLine(
                icon: Icons.assignment_ind_outlined,
                text: incharge == null ? 'No Site Incharge assigned' : 'Site Incharge: $incharge',
                color: incharge == null ? AppColors.error : null,
              ),
          ],
        ),
        if (_canAssign) ...[
          const SizedBox(height: 12),
          _inchargePicker(project),
        ],
      ],
    );
  }
}
