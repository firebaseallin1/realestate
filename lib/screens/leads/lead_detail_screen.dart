import 'package:flutter/material.dart';

import '../../core/controllers/lead_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/money_text.dart';
import '../../core/utils/responsive.dart';
import '../../models/lead.dart';
import '../../models/site.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/full_screen_dialog.dart';
import '../booking/widgets/booking_widgets.dart';
import '../dashboard/widgets/dashboard_panel.dart';
import 'widgets/convert_lead_form.dart';
import 'widgets/follow_up_form.dart';
import 'widgets/lead_form.dart';
import 'widgets/lead_widgets.dart';

/// LeadDetailScreen is one lead in full, as a full-screen dialog: their
/// details, when to follow up next, and every follow-up so far. Edit
/// Details and Add Follow-up sit at the bottom.
class LeadDetailScreen extends StatefulWidget {
  final String leadId;
  final LeadController controller;
  final List<Site> sites;

  /// Who is signed in, recorded on follow-ups made here.
  final String userName;

  /// Takes the user to Customers: after converting, or from a converted lead.
  final VoidCallback? onShowCustomers;

  const LeadDetailScreen({
    super.key,
    required this.leadId,
    required this.controller,
    required this.sites,
    required this.userName,
    this.onShowCustomers,
  });

  static Future<void> open(
    BuildContext context, {
    required String leadId,
    required LeadController controller,
    required List<Site> sites,
    required String userName,
    VoidCallback? onShowCustomers,
  }) {
    return pushFullScreenDialog<void>(
      context,
      (_) => LeadDetailScreen(
        leadId: leadId,
        controller: controller,
        sites: sites,
        userName: userName,
        onShowCustomers: onShowCustomers,
      ),
      label: 'Lead details',
    );
  }

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
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

  Future<void> _edit(Lead lead) {
    return showAppForm(
      context,
      LeadForm(
        lead: lead,
        sites: widget.sites,
        newId: lead.id,
        ownerName: lead.ownerName,
        onSubmit: (updated) async {
          if (!await runSave(context, () => widget.controller.updateLead(updated)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${updated.name} updated.');
        },
      ),
    );
  }

  /// Makes the lead a customer, then goes to Customers.
  Future<void> _convert(Lead lead) {
    return showAppForm(
      context,
      ConvertLeadForm(
        lead: lead,
        ownerName: widget.userName,
        onSubmit: (details) async {
          if (!await runSave(context, () => widget.controller.convert(lead.id, details)) || !mounted) return;
          Navigator.of(context).pop();
          showAppMessage(context, '${details.name} is now a customer.');
          widget.onShowCustomers?.call();
        },
      ),
    );
  }

  Future<void> _addFollowUp(Lead lead) {
    return showAppForm(
      context,
      FollowUpForm(
        lead: lead,
        newId: widget.controller.newId('f'),
        byName: widget.userName,
        onSubmit: (followUp) async {
          if (!await runSave(context, () => widget.controller.addFollowUp(lead.id, followUp)) || !mounted) return;
          Navigator.of(context).pop();
          final next = followUp.status.isClosed || followUp.nextDate == null
              ? ''
              : ' Next on ${DateText.shortDate(followUp.nextDate!)}.';
          showAppMessage(context, 'Follow-up saved.$next');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FullScreenDialogFrame(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final lead = widget.controller.leadById(widget.leadId);
    final wide = Responsive.isWeb(context);

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: SafeArea(
          child: lead == null
              ? const Center(child: Text('This lead no longer exists.'))
              : Column(
                  children: [
                    _buildHeader(lead),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(wide ? 20 : 12),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: _DetailsPanel(lead: lead)),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 3, child: _FollowUpsPanel(lead: lead)),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _DetailsPanel(lead: lead),
                                  const SizedBox(height: 12),
                                  _FollowUpsPanel(lead: lead),
                                ],
                              ),
                      ),
                    ),
                    _buildActions(lead, wide),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(Lead lead) {
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
                  lead.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${lead.mobile} · ${lead.source.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: LeadStatusChip(lead.status)),
        ],
      ),
    );
  }

  /// Edit Details and Add Follow-up, and Convert to Customer until the lead
  /// is converted; then View in Customers.
  Widget _buildActions(Lead lead, bool wide) {
    final edit = AppButton.outline(
      key: const ValueKey('lead-edit'),
      text: 'Edit Details',
      width: wide ? 170 : null,
      icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
      onPressed: () => _edit(lead),
    );
    final followUp = AppButton.outline(
      key: const ValueKey('lead-add-follow-up'),
      text: 'Add Follow-up',
      width: wide ? 190 : null,
      icon: Icon(Icons.add_comment_outlined, color: AppColors.primary, size: 18),
      onPressed: () => _addFollowUp(lead),
    );
    final main = lead.isConverted
        ? AppButton.primary(
            key: const ValueKey('lead-view-customer'),
            text: 'View in Customers',
            width: wide ? 220 : double.infinity,
            gradient: AppColors.brandGradient,
            icon: const Icon(Icons.people_alt_outlined, color: Colors.white, size: 18),
            onPressed: widget.onShowCustomers,
          )
        : AppButton.primary(
            key: const ValueKey('lead-convert'),
            text: 'Convert to Customer',
            width: wide ? 230 : double.infinity,
            gradient: AppColors.brandGradient,
            icon: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 18),
            onPressed: () => _convert(lead),
          );
    // A converted lead is won: nothing more to follow up.
    final secondary = [edit, if (!lead.isConverted) followUp];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(top: BorderSide(color: AppColors.lightBorder)),
      ),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final button in secondary) ...[button, const SizedBox(width: 12)],
                if (widget.onShowCustomers != null || !lead.isConverted) main,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < secondary.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: secondary[i]),
                    ],
                  ],
                ),
                if (widget.onShowCustomers != null || !lead.isConverted) ...[const SizedBox(height: 10), main],
              ],
            ),
    );
  }
}

/// Contact details, what they are looking for, and the next follow-up.
class _DetailsPanel extends StatelessWidget {
  final Lead lead;

  const _DetailsPanel({required this.lead});

  /// "Next follow-up: Tomorrow · 14 Nov 2026", or just the date when
  /// [text] is the date already.
  static String _nextLine(String text, DateTime date) {
    final day = DateText.shortDate(date);
    return text == day ? 'Next follow-up: $day' : 'Next follow-up: $text · $day';
  }

  @override
  Widget build(BuildContext context) {
    final today = leadToday();
    final next = nextFollowUpText(lead, today);

    return DashboardPanel(
      title: 'Lead Details',
      subtitle: 'Added ${DateText.shortDate(lead.createdAt)}${lead.ownerName.isEmpty ? '' : ' by ${lead.ownerName}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('lead-next-banner'),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: (next == null ? lead.status.color : nextFollowUpColor(lead, today)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  next == null ? lead.status.icon : Icons.event_repeat_rounded,
                  color: next == null ? lead.status.color : nextFollowUpColor(lead, today),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lead.convertedAt != null
                        ? 'Converted to a customer on ${DateText.shortDate(lead.convertedAt!)}.'
                        : lead.status.isClosed
                        ? 'This lead is ${lead.status.label.toLowerCase()}.'
                        : next == null
                        ? 'No follow-up scheduled.'
                        : _nextLine(next, lead.nextFollowUp!),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Row(Icons.phone_iphone_rounded, 'Mobile', lead.mobile),
          _Row(Icons.mail_outline_rounded, 'Email', lead.email),
          _Row(Icons.location_on_outlined, 'Area', lead.area),
          _Row(lead.source.icon, 'Source', lead.source.label),
          _Row(Icons.domain_outlined, 'Interested in', lead.siteName.isEmpty ? 'Not decided yet' : lead.siteName),
          _Row(Icons.home_work_outlined, 'Looking for', lead.interest?.description ?? 'Not sure yet'),
          _Row(Icons.currency_rupee_rounded, 'Budget', lead.budget == null ? '' : MoneyText.full(lead.budget!)),
          _Row(Icons.sticky_note_2_outlined, 'Notes', lead.notes),
        ],
      ),
    );
  }
}

/// One labelled detail; empty values show a dash.
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMutedLight),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.bodySmall.copyWith(
                color: value.isEmpty ? AppColors.textMutedLight : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every follow-up, newest first, as a timeline.
class _FollowUpsPanel extends StatelessWidget {
  final Lead lead;

  const _FollowUpsPanel({required this.lead});

  @override
  Widget build(BuildContext context) {
    final followUps = lead.followUps.reversed.toList();
    final count = followUps.length;

    return DashboardPanel(
      title: 'Follow-ups',
      subtitle: count == 0 ? 'Nothing recorded yet' : '$count ${count == 1 ? 'contact' : 'contacts'} so far',
      child: count == 0
          ? const EmptyNote(
              icon: Icons.forum_outlined,
              text: 'No follow-ups yet. Add one after each call, message or visit.',
            )
          : Column(
              children: [
                for (var i = 0; i < count; i++)
                  _FollowUpTile(key: ValueKey('follow-up-$i'), followUp: followUps[i], last: i == count - 1),
              ],
            ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  final FollowUp followUp;
  final bool last;

  const _FollowUpTile({super.key, required this.followUp, required this.last});

  @override
  Widget build(BuildContext context) {
    final meta = [
      DateText.shortDate(followUp.date),
      followUp.mode.label,
      if (followUp.by.isNotEmpty) followUp.by,
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline: a dot in the mode's circle, joined to the next.
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: followUp.status.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(followUp.mode.icon, size: 16, color: followUp.status.color),
                ),
                if (!last) Expanded(child: Container(width: 2, color: AppColors.lightBorder)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(meta, style: AppTypography.caption.copyWith(color: AppColors.textMutedLight)),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: LeadStatusChip(followUp.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    followUp.note,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (followUp.nextDate != null && !followUp.status.isClosed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Next follow-up set for ${DateText.shortDate(followUp.nextDate!)}',
                        style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
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
}
