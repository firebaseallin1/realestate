import 'package:flutter/material.dart';
import '../../../models/app_user.dart';

/// MenuGroup is a top-level heading of the main menu. Each role sees only
/// the groups holding its pages: Admin gets every group (its own
/// Transactions / Masters / Reports plus every team's), the others one
/// group of their own work.
enum MenuGroup {
  transactions('Transactions', Icons.receipt_long_outlined),
  masters('Masters', Icons.inventory_2_outlined),
  reports('Reports', Icons.assessment_outlined),
  sales('Sales', Icons.handshake_outlined),
  construction('Construction', Icons.engineering_outlined),
  siteWork('Site Work', Icons.construction_outlined),
  settings('Settings', Icons.settings_outlined);

  const MenuGroup(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The pages listed under this group, in menu order.
  List<DashboardSection> get sections =>
      DashboardSection.values.where((s) => s.group == this).toList();

  /// The groups [role] sees, in menu order.
  static List<MenuGroup> forRole(UserRole role) =>
      values.where((g) => g.sections.any((s) => s.allows(role))).toList();
}

// Admin has full access, so every team's pages also allow it.
const _admin = {UserRole.admin};
const _sales = {UserRole.salesExecutive, UserRole.admin};
const _manager = {UserRole.siteManager, UserRole.admin};
const _incharge = {UserRole.siteIncharge, UserRole.admin};

/// DashboardSection is one page of the dashboard. Every page except the
/// dashboard itself belongs to a [MenuGroup]; the dashboard is its own
/// entry at the top of the menu (and also opens from the logo).
/// [roles] are the roles allowed to open it.
enum DashboardSection {
  overview('Dashboard', 'Your work at a glance', Icons.space_dashboard_outlined, null, UserRole.values),

  // Admin
  bookingApproval('Booking Approval', 'Approve bookings raised by sales', Icons.fact_check_outlined, MenuGroup.transactions, _admin),
  locations('Locations', 'Cities and areas you manage', Icons.location_city_outlined, MenuGroup.masters, _admin),
  sites('Sites', 'Every project across your locations', Icons.domain_outlined, MenuGroup.masters, _admin),
  propertyUnits('Property Units', 'Plots and units across your projects', Icons.grid_view_outlined, MenuGroup.masters, _admin),
  users('Users', 'Team members and their roles', Icons.manage_accounts_outlined, MenuGroup.masters, _admin),
  inventoryReport('Inventory Report', 'Site-wise unit inventory', Icons.table_chart_outlined, MenuGroup.reports, _admin),
  locationReport('Location Report', 'Location-wise sales summary', Icons.summarize_outlined, MenuGroup.reports, _admin),

  // Sales Executive
  customers('Customers', 'Buyers and their details', Icons.people_alt_outlined, MenuGroup.sales, _sales),
  leads('Leads', 'Enquiries and follow-ups', Icons.contact_phone_outlined, MenuGroup.sales, _sales),
  propertyBooking('Property Booking', 'Book units for customers', Icons.event_available_outlined, MenuGroup.sales, _sales),
  paymentTracking('Payment Tracking', 'Instalments, collections and receipts', Icons.payments_outlined, MenuGroup.sales, _sales),
  customerHandover('Customer Handover', 'Possession and document handover', Icons.key_outlined, MenuGroup.sales, _sales),

  // Site Manager
  constructionPlanning('Construction Planning', 'Phases, schedules and milestones', Icons.timeline_outlined, MenuGroup.construction, _manager),
  siteAssignment('Site Assignment', 'Assign incharges to sites', Icons.assignment_ind_outlined, MenuGroup.construction, _manager),
  progressMonitoring('Progress Monitoring', 'Work progress across sites', Icons.trending_up_rounded, MenuGroup.construction, _manager),
  inspection('Inspection', 'Quality checks and site visits', Icons.verified_outlined, MenuGroup.construction, _manager),

  // Site Incharge
  dailyConstruction('Daily Construction', "Today's work update", Icons.today_outlined, MenuGroup.siteWork, _incharge),
  labor('Labour', 'Attendance and workforce', Icons.groups_2_outlined, MenuGroup.siteWork, _incharge),
  materials('Materials', 'Stock received and used', Icons.inventory_outlined, MenuGroup.siteWork, _incharge),
  sitePhotos('Photos', 'Progress photos from site', Icons.photo_camera_outlined, MenuGroup.siteWork, _incharge),
  siteReports('Site Reports', 'Daily and weekly site reports', Icons.description_outlined, MenuGroup.siteWork, _incharge),

  // Admin, last in the menu
  appSettings('App Settings', 'File storage, theme and text', Icons.tune_rounded, MenuGroup.settings, _admin);

  const DashboardSection(this.label, this.subtitle, this.icon, this.group, this.roles);

  final String label;
  final String subtitle;
  final IconData icon;
  final MenuGroup? group;
  final Iterable<UserRole> roles;

  bool allows(UserRole role) => roles.contains(role);

  /// The pages [role] can open, besides the dashboard, in menu order.
  static List<DashboardSection> forRole(UserRole role) =>
      values.where((s) => s.group != null && s.allows(role)).toList();
}

/// DashboardAction is a section's main button ("Add Site", "Add Location").
/// The web top bar shows it as a button, mobile as the floating button.
/// Sections without one, like the dashboard, show neither.
class DashboardAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const DashboardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}
