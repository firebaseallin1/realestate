import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/controllers/app_data.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/controllers/booking_controller.dart';
import '../../core/controllers/construction_controller.dart';
import '../../core/controllers/lead_controller.dart';
import '../../core/controllers/settings_controller.dart';
import '../../core/controllers/theme_controller.dart';
import '../../core/controllers/site_controller.dart';
import '../../core/controllers/user_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/responsive.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/construction.dart';
import '../../models/lead.dart';
import '../../models/site.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/full_screen_dialog.dart';
import '../../widgets/location_map.dart';
import '../booking/booking_detail_screen.dart';
import '../booking/sections/booking_approval_section.dart';
import '../booking/sections/customers_section.dart';
import '../booking/sections/payment_tracking_section.dart';
import '../booking/sections/property_booking_section.dart';
import '../booking/widgets/booking_form.dart';
import '../construction/construction_screen.dart';
import '../construction/sections/construction_projects_section.dart';
import '../leads/lead_detail_screen.dart';
import '../leads/leads_section.dart';
import '../leads/widgets/lead_form.dart';
import '../settings/settings_section.dart';
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
  final LeadController? leadController;
  final SettingsController? settingsController;

  /// Defaults to the app's theme.
  final ThemeController? themeController;

  const DashboardScreen({
    super.key,
    this.controller,
    this.userController,
    this.bookingController,
    this.constructionController,
    this.leadController,
    this.settingsController,
    this.themeController,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final SiteController _siteController;
  late final UserController _userController;
  late final BookingController _bookingController;
  late final ConstructionController _constructionController;
  late final LeadController _leadController;
  late final SettingsController _settingsController;
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
    _bookingController =
        widget.bookingController ??
        (widget.controller == null ? BookingController.instance : BookingController(_siteController));
    _bookingController.addListener(_onDataUpdate);
    // Construction follows the same bookings.
    _constructionController =
        widget.constructionController ??
        (identical(_bookingController, BookingController.instance)
            ? ConstructionController.instance
            : ConstructionController(_bookingController));
    _constructionController.addListener(_onDataUpdate);
    _leadController =
        widget.leadController ??
        (identical(_bookingController, BookingController.instance) ? LeadController.instance : LeadController());
    _leadController.addListener(_onDataUpdate);
    _settingsController =
        widget.settingsController ??
        (identical(_bookingController, BookingController.instance)
            ? SettingsController.instance
            : SettingsController());
    // Converted leads become customers.
    _leadController.customers.addListener(_onDataUpdate);
    _searchController = TextEditingController(text: _siteController.query);
    _usesServer = ApiClient.instance.isSignedIn && identical(_siteController, SiteController.instance);
    if (_usesServer) WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// True in the live app; tests work on sample data in memory.
  late final bool _usesServer;
  bool _firstLoadDone = false;
  bool _loading = false;
  String? _loadError;
  DateTime? _lastLoad;

  /// Fetches what this role may see, keeping what is on screen meanwhile.
  Future<void> _loadData() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    String? problem;
    try {
      await AppData.loadFor(_user);
      _lastLoad = DateTime.now();
    } on ApiException catch (error) {
      problem = error.message;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _firstLoadDone = true;
      _loadError = problem;
    });
  }

  /// Moving between pages picks up what others have changed, at most every
  /// 15 seconds.
  void _refreshIfStale() {
    final last = _lastLoad;
    if (_usesServer && (last == null || DateTime.now().difference(last).inSeconds >= 15)) _loadData();
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
    _leadController.removeListener(_onDataUpdate);
    _leadController.customers.removeListener(_onDataUpdate);
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
        AppUser(id: 'guest', name: name, username: name, role: UserRole.admin);
  }

  void _showMessage(String message) => showAppMessage(context, message);

  /// Opens the site form to add a site, or edit [site].
  Future<void> _openSiteForm({Site? site}) {
    return _showForm(
      SiteForm(
        site: site,
        existingLocations: _siteController.locations,
        onSubmit: (result) async {
          final saved = await runSave(
            context,
            () => site == null ? _siteController.addSite(result) : _siteController.updateSite(result),
          );
          if (!saved || !mounted) return;
          Navigator.of(context).pop();
          _showMessage(site == null ? '${result.name} added to ${result.location}.' : '${result.name} updated.');
        },
      ),
    );
  }

  /// Opens the form to add a location with no sites yet.
  Future<void> _openLocationForm() {
    return _showForm(
      LocationForm(
        existingLocations: _siteController.locations,
        onSubmit: (name, point) async {
          if (!await runSave(context, () => _siteController.saveLocation(name, point: point)) || !mounted) return;
          Navigator.of(context).pop();
          _showMessage('$name added to your locations.');
        },
      ),
    );
  }

  /// Picks where an existing location is on the map and saves it.
  Future<void> _setLocationPoint(String location) async {
    final picked = await pickMapPoint(context, initial: _siteController.pointOf(location), title: location);
    if (picked == null || !mounted) return;
    if (!await runSave(context, () => _siteController.setLocationPoint(location, picked.point)) || !mounted) return;
    _showMessage('Map location saved for $location.');
  }

  /// Opens the form to add a team member with a role, or to edit [user].
  Future<void> _openUserForm({AppUser? user}) {
    return _showForm(
      UserForm(
        user: user,
        roleLocked: user?.id == _user.id,
        onUpdate: user == null
            ? null
            : (changes) async {
                try {
                  final updated = await _userController.updateUser(user.id, changes);
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showMessage('${updated.name} updated.');
                  }
                  return null;
                } on ApiException catch (error) {
                  return error.message;
                }
              },
        isUsernameTaken: _userController.isUsernameTaken,
        onSubmit: (newUser) async {
          try {
            final user = await _userController.addUser(newUser);
            if (mounted) {
              Navigator.of(context).pop();
              _showMessage('${user.name} added as ${user.role.label}.');
            }
            return null;
          } on ApiException catch (error) {
            return error.message;
          }
        },
      ),
    );
  }

  Future<void> _showForm(Widget form) => showAppForm(context, form);

  /// Asks before a destructive action; true when confirmed.
  Future<bool> _confirm({required String title, required String message, required String confirmLabel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryLight)),
          content: Text(message, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
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
    if (!confirmed || !mounted) return;
    if (!await runSave(context, () => _siteController.deleteSite(site.id)) || !mounted) return;
    _showMessage('${site.name} deleted.');
  }

  Future<void> _confirmRemoveUser(AppUser user) async {
    final confirmed = await _confirm(
      title: 'Remove user?',
      message: '${user.name} (${user.role.label}) will no longer be able to sign in.',
      confirmLabel: 'Remove',
    );
    if (confirmed) {
      try {
        await _userController.removeUser(user.id);
        if (mounted) _showMessage('${user.name} removed.');
      } on ApiException catch (error) {
        if (mounted) _showMessage(error.message);
      }
    }
  }

  /// Opens the site's plot layout (mapped view) as a full-screen dialog.
  void _openLayout(Site site) {
    SiteLayoutScreen.open(context, siteId: site.id, controller: _siteController);
  }

  /// Opens the form to book a plot, with [customer]'s details filled in
  /// when booking for a known customer. Completed sites have nothing to sell.
  Future<void> _openBookingForm({Customer? customer}) {
    return _showForm(
      BookingForm(
        sites: _siteController.sites.where((s) => s.status != SiteStatus.completed).toList(),
        isPlotTaken: _bookingController.isPlotTaken,
        newId: _bookingController.newId(),
        bookedBy: _user.name,
        customer: customer,
        onSubmit: (booking) async {
          if (!await runSave(context, () => _bookingController.addBooking(booking)) || !mounted) return;
          Navigator.of(context).pop();
          _showMessage('Plot ${booking.plotNumber} booked for ${booking.customer.name}. Sent for approval.');
        },
      ),
    );
  }

  /// Opens a booking in a full-screen dialog. Sales and Admins record
  /// payments; Admins approve.
  void _openBooking(Booking booking) {
    final role = _user.role;
    pushFullScreenDialog<void>(
      context,
      (_) => BookingDetailScreen(
        bookingId: booking.id,
        controller: _bookingController,
        canRecordPayments: role == UserRole.salesExecutive || role == UserRole.admin,
        canApprove: role == UserRole.admin,
      ),
      label: 'Booking details',
    );
  }

  Future<void> _approveBooking(Booking booking) async {
    if (!await runSave(context, () => _bookingController.approve(booking.id)) || !mounted) return;
    _showMessage('Booking for ${booking.customer.name} approved.');
  }

  Future<void> _rejectBooking(Booking booking) async {
    final confirmed = await _confirm(
      title: 'Reject booking?',
      message:
          'Plot ${booking.plotNumber} at ${booking.siteName} for ${booking.customer.name} '
          'will be freed for other customers.',
      confirmLabel: 'Reject',
    );
    if (!confirmed || !mounted) return;
    if (!await runSave(context, () => _bookingController.reject(booking.id)) || !mounted) return;
    _showMessage('Booking for ${booking.customer.name} rejected.');
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

  /// The Site Incharges to show. A Site Incharge may not list the team, so
  /// they know only themselves, which is all their own houses need.
  List<AppUser> _inchargesFor(AppUser user) =>
      user.role == UserRole.siteIncharge ? [user] : _userController.usersWithRole(UserRole.siteIncharge);

  /// Opens the form to add someone enquiring about a plot.
  Future<void> _openLeadForm() {
    return _showForm(
      LeadForm(
        sites: _siteController.sites.where((s) => s.status != SiteStatus.completed).toList(),
        newId: _leadController.newId('l'),
        ownerName: _user.name,
        onSubmit: (lead) async {
          if (!await runSave(context, () => _leadController.addLead(lead)) || !mounted) return;
          Navigator.of(context).pop();
          _showMessage(
            lead.nextFollowUp == null
                ? '${lead.name} added as a lead.'
                : '${lead.name} added. Follow up on ${DateText.shortDate(lead.nextFollowUp!)}.',
          );
        },
      ),
    );
  }

  /// Opens a lead with its follow-ups, as a full-screen dialog.
  void _openLead(Lead lead) {
    LeadDetailScreen.open(
      context,
      leadId: lead.id,
      controller: _leadController,
      sites: _siteController.sites,
      userName: _user.name,
      // Closes the lead and shows Customers, where a converted lead now is.
      onShowCustomers: () {
        Navigator.of(context).pop();
        _changeSection(DashboardSection.customers);
      },
    );
  }

  /// Opens a house under construction at [tab], as a full-screen dialog.
  void _openProject(ConstructionProject project, ConstructionTab tab) {
    pushFullScreenDialog<void>(
      context,
      (_) => ConstructionScreen(
        projectId: project.id,
        controller: _constructionController,
        userName: _user.name,
        initialTab: tab,
      ),
      label: 'Construction project',
    );
  }

  Future<void> _assignIncharge(ConstructionProject project, String? inchargeId) async {
    final saved = await runSave(context, () => _constructionController.assignIncharge(project.id, inchargeId));
    if (!saved || !mounted) return;
    final name = _userController.users.where((u) => u.id == inchargeId).map((u) => u.name).firstOrNull;
    _showMessage(
      name == null
          ? "Site Incharge removed from ${project.booking.customer.name}'s house."
          : "$name assigned to ${project.booking.customer.name}'s house.",
    );
  }

  void _logout() {
    // Signs out here at once; telling the server must not hold up the user.
    AuthController().logout();
    AppData.clear();
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  /// Ids of notifications already seen, so the badge only counts new ones.
  final Set<String> _readNotifications = {};

  /// The bell with today's alerts, shared by both frames' top bars. The
  /// portfolio alerts lead to Admin pages, so only Admins get them.
  Widget _buildNotificationBell(AppUser user) {
    final notifications = user.role == UserRole.admin
        ? DashboardNotification.fromData(_siteController, bookings: _bookingController)
        : <DashboardNotification>[];
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
    _refreshIfStale();
  }

  /// The section's content with the state of loading it from the server: a
  /// spinner the first time, then a thin bar, and any problem with a retry.
  Widget _buildContentWithStatus(AppUser user, {required bool wide}) {
    if (_usesServer && !_firstLoadDone) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadError != null)
          Container(
            key: const ValueKey('load-problem'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_loadError!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                ),
                TextButton(onPressed: _loadData, child: const Text('Try Again')),
              ],
            ),
          ),
        _buildContent(user, wide: wide),
      ],
    );
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
          return RoleHomeSection(user: user, controller: _siteController, wide: wide, onOpenSection: _changeSection);
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
          onSetPoint: _user.role == UserRole.admin ? _setLocationPoint : null,
        );
      case DashboardSection.users:
        return UsersSection(
          controller: _userController,
          currentUserId: user.id,
          onRemoveUser: _confirmRemoveUser,
          onEditUser: (user) => _openUserForm(user: user),
          activityFor: _activityOf,
        );
      case DashboardSection.inventoryReport:
        return InventoryReportSection(controller: _siteController, wide: wide);
      case DashboardSection.locationReport:
        return LocationReportSection(controller: _siteController, onOpenLocation: _openLocation);
      case DashboardSection.bookingApproval:
        return BookingApprovalSection(
          controller: _bookingController,
          onOpenBooking: _openBooking,
          onApprove: _approveBooking,
          onReject: _rejectBooking,
        );
      case DashboardSection.propertyBooking:
        return PropertyBookingSection(controller: _bookingController, onOpenBooking: _openBooking);
      case DashboardSection.paymentTracking:
        return PaymentTrackingSection(controller: _bookingController, wide: wide, onOpenBooking: _openBooking);
      case DashboardSection.customers:
        return CustomersSection(
          controller: _bookingController,
          customers: _leadController.customers,
          onOpenBooking: _openBooking,
          onBookPlot: (profile) => _openBookingForm(
            customer: Customer(
              name: profile.name,
              mobile: profile.mobile,
              email: profile.email,
              address: profile.address,
            ),
          ),
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
          incharges: _inchargesFor(user),
          wide: wide,
          onOpenProject: _openProject,
          onAssign: _assignIncharge,
        );
      case DashboardSection.appSettings:
        return SettingsSection(controller: _settingsController, themeController: widget.themeController);
      case DashboardSection.leads:
        return LeadsSection(controller: _leadController, showOwner: user.role == UserRole.admin, onOpenLead: _openLead);
      case DashboardSection.propertyUnits:
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
        return DashboardAction(label: 'Add Site', icon: Icons.add_business_rounded, onPressed: () => _openSiteForm());
      case DashboardSection.locations:
        return DashboardAction(
          label: 'Add Location',
          icon: Icons.add_location_alt_rounded,
          onPressed: _openLocationForm,
        );
      case DashboardSection.propertyBooking:
      case DashboardSection.customers:
        return DashboardAction(label: 'New Booking', icon: Icons.event_available_rounded, onPressed: _openBookingForm);
      case DashboardSection.users:
        return DashboardAction(label: 'Add User', icon: Icons.person_add_alt_1_rounded, onPressed: () => _openUserForm());
      case DashboardSection.leads:
        return DashboardAction(label: 'New Lead', icon: Icons.person_add_alt_1_rounded, onPressed: _openLeadForm);
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
          content: _buildContentWithStatus(user, wide: false),
        ),
        web: (context) => DashboardWebView(
          section: _section,
          onSectionChanged: _changeSection,
          user: user,
          action: action,
          onLogout: _logout,
          notificationBell: _buildNotificationBell(user),
          content: _buildContentWithStatus(user, wide: true),
        ),
      ),
    );
  }
}
