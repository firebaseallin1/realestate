import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_text.dart';
import '../../../models/lead.dart';
import '../../booking/widgets/booking_widgets.dart';

/// Today's date, without the time.
DateTime leadToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// When the next follow-up is, in words: "Today", "Overdue by 2 days",
/// "Tomorrow", "In 5 days" or the date. Null when there is none.
String? nextFollowUpText(Lead lead, DateTime today) {
  final next = lead.nextFollowUp;
  if (next == null || lead.status.isClosed) return null;
  final days = next.difference(today).inDays;
  if (days == 0) return 'Today';
  if (days < 0) return 'Overdue by ${-days} ${days == -1 ? 'day' : 'days'}';
  if (days == 1) return 'Tomorrow';
  if (days <= 7) return 'In $days days';
  return DateText.shortDate(next);
}

/// Red when overdue, gold when due today, otherwise the brand colour.
Color nextFollowUpColor(Lead lead, DateTime today) {
  if (lead.isOverdue(today)) return AppColors.error;
  if (lead.isDueOn(today)) return AppColors.accentGold;
  return AppColors.primary;
}

/// The lead's status as a coloured chip.
class LeadStatusChip extends StatelessWidget {
  final LeadStatus status;

  const LeadStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) => BookingChip(label: status.label, icon: status.icon, color: status.color);
}
