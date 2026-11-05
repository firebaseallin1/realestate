import 'package:flutter/material.dart';
import '../../core/controllers/booking_controller.dart';
import '../../core/controllers/construction_controller.dart';
import '../../core/controllers/site_controller.dart';
import '../../core/controllers/user_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/construction.dart';
import '../../models/site.dart';
import '../../widgets/app_form_sheet.dart';
import '../booking/booking_detail_screen.dart';
import '../booking/sections/booking_approval_section.dart';
import '../booking/sections/customers_section.dart';
import '../booking/sections/payment_tracking_section.dart';
import '../booking/sections/property_booking_section.dart';
import '../booking/widgets/booking_form.dart';
import '../construction/construction_screen.dart';
import '../construction/sections/construction_projects_section.dart';
import '../site_layout/site_layout_screen.dart';
import 'sections/coming_soon_section.dart';
import 'sections/inventory_report_section.dart';
import 'sections/location_report_section.dart';
import 'sections/locations_section.dart';
import 'sections/overview_section.dart';
import 'sections/role_home_section.dart';
import 'sections/sites_section.dart';
import 'sections/users_section.dart';
import 'views/dashboard_mobile_view.dart';
import 'views/dashboard_web_view.dart';
import 'widgets/dashboard_notifications.dart';
import 'widgets/dashboard_section.dart';
import 'widgets/location_form.dart';
import 'widgets/site_form.dart';
import 'widgets/user_form.dart';

/// DashboardScreen owns the dashboard logic (current section and its
/// action, site add / edit / delete, adding locations and users,
/// bookings and their approval, construction projects, search, logout). It builds the shared section content and hands it to the
/// mobile or web frame by width.
/// The signed-in [AppUser] arrives as the route argument; their role picks
/// the menu, the dashboard and which pages open.
class DashboardScreen extends StatefulWidget {
  final SiteController? controller;
  final UserController? userController;
  final BookingController? bookingController;
  final ConstructionController? constructionController;

  const DashboardScreen({
    super.key,
    this.controller,
    this.userController,
    this.bookingController,
    this.constructionController,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final SiteController _siteController;
  late final UserController _userController;
  late final BookingController _bookingController;
  late final ConstructionController _constructionController;
  late final TextEditingController _searchController;
  DashboardSection _section = DashboardSection.overview;

  @override
  void initState() {
    super.initState();
    _siteController = widget.controller ?? SiteController.instance;
    _siteController.addListener(_onDataUpdate);
    _userController = widget.userController ?? UserController.instance;
    _userController.addListener(_onDataUpdate);
    // Bookings move units on the same sites the dashboard shows.
    _bookingController = widget.bookingController ??
        (widget.controller == null ? BookingController.instance : BookingController(_siteController));
    _bookingController.addListener(_onDataUpdate);
    // Construction follows the same bookings.
    _constructionController = widget.constructionController ??
        (identical(_bookingController, BookingController.instance)
            ? ConstructionController.instance
            : ConstructionController(_bookingController));
    _constructionController.addListener(_onDataUpdate);
    _searchController = TextEditingController(text: _siteController.query);
  }

  void _onDataUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _siteController.removeListener(_onDataUpdate);
    _userController.removeListener(_onDataUpdate);
    _bookingController.removeListener(_onDataUpdate);
    _constructionController.removeListener(_onDataUpdate);
    _searchController.dispose();
    super.dispose();
  }

  /// The signed-in user. A plain username (or nothing) falls back to that
  /// account, or to an Admin by that name.
  AppUser get _user {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AppUser) return args;
    final name = args is String && args.trim().isNotEmpty ? args.trim() : 'admin';
    return _userController.findByUsername(name) ??
        AppUser(id: 'guest', name: name, username: name, password: '', role: UserRole.admin);
  }

  void _showMessage(String message) => showAppMessage(context, message);

  /// Opens the site form to add a site, or edit [site].
  Future<void> _openSiteForm({Site? site}) {
    return _showForm(
      SiteForm(
        site: site,
        existingLocations: _siteController.locations,
        onSubmit: (result) {
          Navigator.of(context).pop();
          if (site == null) {
            _siteController.addSite(result);
            _showMessage('${result.name} added to ${result.location}.');
          } else {
            _siteController.updateSite(result);
            _showMessage('${result.name} updated.');
          }
        },
      ),
    );
  }

  /// Opens the form to add a location with no sites yet.
  Future<void> _openLocationForm() {
    return _showForm(
      LocationForm(
        existingLocations: _siteController.locations,
        onSubmit: (name) {
          Navigator.of(context).pop();
          _siteController.addLocation(name);
          _showMessage('$name added to your locations.');
        },
      ),
    );
  }

  /// Opens the form to add a team member with a role.
  Future<void> _openUserForm() {
    return _showForm(
      UserForm(
        newId: _userController.newId(),
        isUsernameTaken: _userController.isUsernameTaken,
        onSubmit: (user) {
          Navigator.of(context).pop();
          _userController.addUser(user);
          _showMessage('${user.name} added as ${user.role.label}.');
        },
      ),
    );
  }

  Future<void> _showForm(Widget form) => showAppForm(context, form);

  /// Asks before a destructive action; true when confirmed.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            title,
            style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryLight),
          ),
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmDelete(Site site) async {
    final confirmed = await _confirm(
      title: 'Delete site?',
      message: '${site.name} in ${site.location} will be removed. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      _siteController.deleteSite(site.id);
      _showMessage('${site.name} deleted.');
    }
  }

  Future<void> _confirmRemoveUser(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Remove user?',
      message: '${user.name} (${user.role.label}) will no longer be able to sign in.',
      confirmLabel: 'Remove',
    );
    if (confirmed) {
      _userController.removeUser(user.id);
      _showMessage('${user.name} removed.');
    }
  }

  /// Opens the site's plot layout (mapped view) as a full page.
  void _openLayout(Site site) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SiteLayoutScreen(siteId: site.id, controller: _siteController),
      ),
    );
  }

  /// Opens the form to book a plot. Completed sites have nothing to sell.
  Future<void> _openBookingForm() {
    return _showForm(
      BookingForm(
        sites: _siteController.sites.where((s) => s.status != SiteStatus.completed).toList(),
        isPlotTaken: _bookingController.isPlotTaken,
        newId: _bookingController.newId(),
        bookedBy: _user.name,
        onSubmit: (booking) {
          Navigator.of(context).pop();
          _bookingController.addBooking(booking);
          _showMessage('Plot ${booking.plotNumber} booked for ${booking.customer.name}. Sent for approval.');
        },
      ),
    );
  }

  /// Opens a booking in full. Sales and Admins record payments; Admins
  /// approve.
  void _openBooking(Booking booking) {
    final role = _user.role;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailScreen(
          bookingId: booking.id,
          controller: _bookingController,
          canRecordPayments: role == UserRole.salesExecutive || role == UserRole.admin,
          canApprove: role == UserRole.admin,
        ),
      ),
    );
  }

  void _approveBooking(Booking booking) {
    _bookingController.approve(booking.id);
    _showMessage('Booking for ${booking.customer.name} approved.');
  }

  Future<void> _rejectBooking(Booking booking) async {
    final confirmed = await _confirm(
      title: 'Reject booking?',
      message: 'Plot ${booking.plotNumber} at ${booking.siteName} for ${booking.customer.name} '
          'will be freed for other customers.',
      confirmLabel: 'Reject',
    );
    if (confirmed) {
      _bookingController.reject(booking.id);
      _showMessage('Booking for ${booking.customer.name} rejected.');
    }
  }

  /// A line about what [member] is working on, for their user card.
  String _activityOf(AppUser member) {
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    switch (member.role) {
      case UserRole.admin:
        return 'Full access to every module';
      case UserRole.salesExecutive:
        final n = _bookingController.bookings.where((b) => b.bookedBy == member.name).length;
        return '${count(n, 'booking', 'bookings')} raised';
      case UserRole.siteManager:
        return '${count(_constructionController.projects.length, 'house', 'houses')} under construction';
      case UserRole.siteIncharge:
        return '${count(_constructionController.projectsFor(member).length, 'house', 'houses')} assigned';
    }
  }

  /// Opens a house under construction at [tab].
  void _openProject(ConstructionProject project, ConstructionTab tab) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConstructionScreen(
          projectId: project.id,
          controller: _constructionController,
          userName: _user.name,
          initialTab: tab,
        ),
      ),
    );
  }

  void _assignIncharge(ConstructionProject project, String? inchargeId) {
    _constructionController.assignIncharge(project.id, inchargeId);
    final name = _userController.users.where((u) => u.id == inchargeId).map((u) => u.name).firstOrNull;
    _showMessage(name == null
        ? "Site Incharge removed from ${project.booking.customer.name}'s house."
        : "$name assigned to ${project.booking.customer.name}'s house.");
  }

  void _logout() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  /// Ids of notifications already seen, so the badge only counts new ones.
  final Set<String> _readNotifications = {};

  /// The bell with today's alerts, shared by both frames' top bars. The
  /// portfolio alerts lead to Admin pages, so only Admins get them.
  Widget _buildNotificationBell(AppUser user) {
    final notifications =
        user.role == UserRole.admin ? DashboardNotification.fromData(_siteController, bookings: _bookingController) : <DashboardNotification>[];
    final unread = notifications.where((n) => !_readNotifications.contains(n.id)).length;

    return NotificationBell(
      notifications: notifications,
      unreadCount: unread,
      onOpened: () => setState(() => _readNotifications.addAll(notifications.map((n) => n.id))),
      onSelected: (n) {
        _siteController.selectLocation(n.location);
        _changeSection(n.section);
      },
    );
  }

  /// Opens [section] if the signed-in role is allowed to.
  void _changeSection(DashboardSection section) {
    if (!section.allows(_user.role)) return;
    setState(() => _section = section);
  }

  /// Jumps to the Sites section filtered to [location].
  void _openLocation(String location) {
    _siteController.selectLocation(location);
    _changeSection(DashboardSection.sites);
  }

  /// The current section's content, shared by both frames.
  Widget _buildContent(AppUser user, {required bool wide}) {
    switch (_section) {
      case DashboardSection.overview:
        if (user.role != UserRole.admin) {
          return RoleHomeSection(
            user: user,
            controller: _siteController,
            wide: wide,
            onOpenSection: _changeSection,
          );
        }
        return OverviewSection(
          controller: _siteController,
          wide: wide,
          onOpenLocation: _openLocation,
          onViewAllSites: () {
            _siteController.selectLocation(null);
            _changeSection(DashboardSection.sites);
          },
        );
      case DashboardSection.sites:
        return SitesSection(
          controller: _siteController,
          searchController: _searchController,
          wide: wide,
          onEditSite: (site) => _openSiteForm(site: site),
          onDeleteSite: _confirmDelete,
          onOpenLayout: _openLayout,
        );
      case DashboardSection.locations:
        return LocationsSection(
          controller: _siteController,
          onOpenLocation: _openLocation,
        );
      case DashboardSection.users:
        return UsersSection(
          controller: _userController,
          currentUserId: user.id,
          onRemoveUser: _confirmRemoveUser,
          activityFor: _activityOf,
        );
      case DashboardSection.inventoryReport:
        return InventoryReportSection(controller: _siteController, wide: wide);
      case DashboardSection.locationReport:
        return LocationReportSection(
          controller: _siteController,
          onOpenLocation: _openLocation,
        );
      case DashboardSection.bookingApproval:
        return BookingApprovalSection(
          controller: _bookingController,
          onOpenBooking: _openBooking,
          onApprove: _approveBooking,
          onReject: _rejectBooking,
        );
      case DashboardSection.propertyBooking:
        return PropertyBookingSection(
          controller: _bookingController,
          onOpenBooking: _openBooking,
        );
      case DashboardSection.paymentTracking:
        return PaymentTrackingSection(
          controller: _bookingController,
          wide: wide,
          onOpenBooking: _openBooking,
        );
      case DashboardSection.customers:
        return CustomersSection(
          controller: _bookingController,
          onOpenBooking: _openBooking,
        );
      case DashboardSection.constructionPlanning:
      case DashboardSection.siteAssignment:
      case DashboardSection.progressMonitoring:
      case DashboardSection.dailyConstruction:
      case DashboardSection.labor:
      case DashboardSection.materials:
        return ConstructionProjectsSection(
          controller: _constructionController,
          user: user,
          section: _section,
          incharges: _userController.usersWithRole(UserRole.siteIncharge),
          wide: wide,
          onOpenProject: _openProject,
          onAssign: _assignIncharge,
        );
      case DashboardSection.propertyUnits:
      case DashboardSection.leads:
      case DashboardSection.customerHandover:
      case DashboardSection.inspection:
      case DashboardSection.sitePhotos:
      case DashboardSection.siteReports:
        return ComingSoonSection(section: _section);
    }
  }

  /// The main button for the current section: pages that add something
  /// have one.
  DashboardAction? get _sectionAction {
    switch (_section) {
      case DashboardSection.sites:
        return DashboardAction(
          label: 'Add Site',
          icon: Icons.add_business_rounded,
          onPressed: () => _openSiteForm(),
        );
      case DashboardSection.locations:
        return DashboardAction(
          label: 'Add Location',
          icon: Icons.add_location_alt_rounded,
          onPressed: _openLocationForm,
        );
      case DashboardSection.propertyBooking:
      case DashboardSection.customers:
        return DashboardAction(
          label: 'New Booking',
          icon: Icons.event_available_rounded,
          onPressed: _openBookingForm,
        );
      case DashboardSection.users:
        return DashboardAction(
          label: 'Add User',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _openUserForm,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final action = _sectionAction;

    // Dashboard follows the signature white & sage look.
    return Theme(
      data: AppTheme.lightTheme,
      child: ResponsiveLayout(
        mobile: (context) => DashboardMobileView(
          section: _section,
          onSectionChanged: _changeSection,
          user: user,
          action: action,
          onLogout: _logout,
          notificationBell: _buildNotificationBell(user),
          content: _buildContent(user, wide: false),
        ),
        web: (context) => DashboardWebView(
          section: _section,
          onSectionChanged: _changeSection,
          user: user,
          action: action,
          onLogout: _logout,
          notificationBell: _buildNotificationBell(user),
          content: _buildContent(user, wide: true),
        ),
      ),
    );
  }
}
