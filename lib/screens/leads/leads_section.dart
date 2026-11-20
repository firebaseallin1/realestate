import 'package:flutter/material.dart';

import '../../core/controllers/lead_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/money_text.dart';
import '../../core/utils/responsive.dart';
import '../../models/lead.dart';
import '../../widgets/band_card.dart';
import '../../widgets/list_table_switcher.dart';
import '../booking/widgets/booking_widgets.dart';
import '../dashboard/widgets/dashboard_stats.dart';
import '../dashboard/widgets/report_table.dart';
import 'widgets/lead_widgets.dart';

/// Which follow-ups to show.
enum LeadDue {
  dueToday('Due Today'),
  overdue('Overdue'),
  upcoming('Upcoming');

  const LeadDue(this.label);

  final String label;
}

/// LeadsSection (Sales and Admin): every enquiry with where it stands and
/// when to follow up, filtered by status or by follow-up date. Tapping a
/// lead opens it. Admins also see who looks after each lead.
class LeadsSection extends StatefulWidget {
  final LeadController controller;
  final bool showOwner;
  final ValueChanged<Lead> onOpenLead;

  const LeadsSection({super.key, required this.controller, required this.onOpenLead, this.showOwner = false});

  @override
  State<LeadsSection> createState() => _LeadsSectionState();
}

class _LeadsSectionState extends State<LeadsSection> {
  LeadStatus? _status;
  LeadDue? _due;

  static bool _matchesDue(LeadDue? due, Lead lead, DateTime today) {
    switch (due) {
      case null:
        return true;
      case LeadDue.dueToday:
        return lead.isDueOn(today);
      case LeadDue.overdue:
        return lead.isOverdue(today);
      case LeadDue.upcoming:
        return !lead.status.isClosed && lead.nextFollowUp != null && lead.nextFollowUp!.isAfter(today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = leadToday();
    final all = widget.controller.leads;
    final wide = Responsive.isWeb(context);

    if (all.isEmpty) {
      return const EmptyNote(
        icon: Icons.contact_phone_outlined,
        text: 'No leads yet. Add one with New Lead when someone enquires.',
      );
    }

    final dueToday = all.where((l) => l.isDueOn(today)).length;
    final overdue = all.where((l) => l.isOverdue(today)).length;
    final won = all.where((l) => l.status == LeadStatus.won).length;
    final open = all.where((l) => !l.status.isClosed).length;
    final closed = all.where((l) => l.status.isClosed).length;

    final ofStatus = _status == null ? all : all.where((l) => l.status == _status).toList();
    // Most urgent first: overdue, then today, then by date; none last.
    final shown = ofStatus.where((l) => _matchesDue(_due, l, today)).toList()
      ..sort((a, b) {
        final x = a.status.isClosed ? null : a.nextFollowUp;
        final y = b.status.isClosed ? null : b.nextFollowUp;
        if (x == null && y == null) return b.createdAt.compareTo(a.createdAt);
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardGrid(
          columns: wide ? 4 : 2,
          cards: [
            StatCard(
              icon: Icons.contact_phone_outlined,
              color: AppColors.primary,
              label: 'Open Leads',
              value: '$open',
              caption: '${all.length} in all',
            ),
            StatCard(
              icon: Icons.today_outlined,
              color: AppColors.accentGold,
              label: 'Due Today',
              value: '$dueToday',
              caption: 'Follow-ups to make',
            ),
            StatCard(
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              label: 'Overdue',
              value: '$overdue',
              caption: 'Missed follow-ups',
            ),
            StatCard(
              icon: Icons.emoji_events_outlined,
              color: AppColors.success,
              label: 'Won',
              value: '$won',
              caption: closed == 0 ? 'None closed yet' : '${(won * 100 / closed).round()}% of closed leads',
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilterChips<LeadDue>(
          keyPrefix: 'lead-due',
          selected: _due,
          onSelected: (due) => setState(() => _due = due),
          options: [
            (null, 'Any date', ofStatus.length),
            for (final due in LeadDue.values)
              (due, due.label, ofStatus.where((l) => _matchesDue(due, l, today)).length),
          ],
        ),
        const SizedBox(height: 8),
        FilterChips<LeadStatus>(
          keyPrefix: 'lead-status',
          selected: _status,
          onSelected: (status) => setState(() => _status = status),
          options: [
            (null, 'All', all.length),
            for (final status in LeadStatus.values) (status, status.label, all.where((l) => l.status == status).length),
          ],
        ),
        const SizedBox(height: 12),
        ListTableSwitcher(
          id: 'leads',
          empty: shown.isEmpty
              ? const EmptyNote(icon: Icons.filter_alt_off_outlined, text: 'No leads match these filters.')
              : null,
          list: (_) => CardWrap(
            children: [
              for (final lead in shown)
                _LeadCard(lead: lead, today: today, showOwner: widget.showOwner, onTap: () => widget.onOpenLead(lead)),
            ],
          ),
          table: (_) => _buildTable(shown, today),
        ),
      ],
    );
  }

  Widget _buildTable(List<Lead> leads, DateTime today) {
    return ReportTable(
      minWidth: widget.showOwner ? 1180 : 1040,
      columns: [
        const ReportColumn('Name', flex: 1.4),
        const ReportColumn('Mobile', flex: 1.1),
        const ReportColumn('Source', flex: 1),
        const ReportColumn('Interested In', flex: 1.6),
        const ReportColumn('Budget', flex: 0.9, numeric: true),
        const ReportColumn('Status', flex: 1.1),
        const ReportColumn('Next Follow-up', flex: 1.2),
        const ReportColumn('Contacts', flex: 0.7, numeric: true),
        if (widget.showOwner) const ReportColumn('Sales Executive', flex: 1.2),
      ],
      rowKeys: [for (final lead in leads) ValueKey('lead-row-${lead.id}')],
      onRowTap: (i) => widget.onOpenLead(leads[i]),
      rows: [
        for (final lead in leads)
          [
            ReportTable.text(lead.name, bold: true),
            ReportTable.text(lead.mobile),
            ReportTable.text(lead.source.label),
            ReportTable.text(lead.siteName.isEmpty ? ReportTable.blank : lead.siteName),
            ReportTable.text(lead.budget == null ? ReportTable.blank : MoneyText.short(lead.budget!)),
            ReportTable.pill(lead.status.label, lead.status.color),
            ReportTable.text(
              nextFollowUpText(lead, today) ?? ReportTable.blank,
              bold: lead.isOverdue(today) || lead.isDueOn(today),
              color: nextFollowUpColor(lead, today),
            ),
            ReportTable.text('${lead.followUps.length}'),
            if (widget.showOwner) ReportTable.text(lead.ownerName),
          ],
      ],
    );
  }
}

/// _LeadCard: a [BandCard] in the status colour with the source and next
/// follow-up on the band, then contact details and the last follow-up.
class _LeadCard extends StatelessWidget {
  final Lead lead;
  final DateTime today;
  final bool showOwner;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.today, required this.showOwner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final next = nextFollowUpText(lead, today);
    final last = lead.lastFollowUp;

    return BandCard(
      key: ValueKey('lead-${lead.id}'),
      color: lead.status.color,
      onTap: onTap,
      avatar: BandCard.avatarCircle(lead.status.color, BandCard.initial(lead.name)),
      badges: [
        BandBadge(icon: lead.status.icon, label: lead.status.label),
        BandBadge(icon: lead.source.icon, label: lead.source.label),
        if (lead.isConverted) const BandBadge(icon: Icons.how_to_reg_rounded, label: 'Customer'),
      ],
      trailing: next == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: lead.isOverdue(today) ? AppColors.error : Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                next,
                style: AppTypography.caption.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
              ),
            ),
      children: [
        BandTitle(title: lead.name, subtitle: lead.mobile),
        const SizedBox(height: 12),
        BandInfoBox(
          children: [
            BandInfoLine(
              icon: Icons.domain_outlined,
              text: [
                lead.siteName.isEmpty ? 'Site not decided' : lead.siteName,
                if (lead.interest != null) lead.interest!.description,
              ].join(' · '),
              muted: lead.siteName.isEmpty,
            ),
            BandInfoLine(
              icon: Icons.currency_rupee_rounded,
              text: lead.budget == null ? 'Budget not given' : 'Budget ${MoneyText.short(lead.budget!)}',
              muted: lead.budget == null,
            ),
            BandInfoLine(
              icon: Icons.forum_outlined,
              text: last == null
                  ? 'No follow-ups yet'
                  : '${DateText.shortDate(last.date)} · ${last.mode.label}: ${last.note}',
              muted: last == null,
            ),
            if (showOwner) BandInfoLine(icon: Icons.badge_outlined, text: lead.ownerName),
          ],
        ),
      ],
    );
  }
}
