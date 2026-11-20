import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/core/repositories/local_user_repository.dart';
import 'package:real_estate/models/app_user.dart';
import 'package:real_estate/widgets/app_dropdown.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';
import 'package:real_estate/screens/dashboard/sections/role_home_section.dart';
import 'package:real_estate/screens/dashboard/sections/users_section.dart';
import 'package:real_estate/screens/dashboard/views/dashboard_mobile_view.dart';
import 'package:real_estate/screens/dashboard/views/dashboard_web_view.dart';
import 'package:real_estate/screens/dashboard/widgets/dashboard_notifications.dart';
import 'package:real_estate/screens/dashboard/widgets/dashboard_section.dart';
import 'package:real_estate/screens/dashboard/widgets/hero_banner.dart';
import 'package:real_estate/screens/dashboard/widgets/location_card.dart';
import 'package:real_estate/screens/dashboard/widgets/site_card.dart';

Future<SiteController> _pumpDashboard(WidgetTester tester, Size size, {Object? user, UserController? users}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Start fresh, so a previous pump's route and state don't carry over.
  await tester.pumpWidget(const SizedBox());
  final controller = SiteController.test();
  final argument = user ?? _username;
  _username = null;
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: argument),
        builder: (_) => DashboardScreen(controller: controller, userController: users ?? UserController.test()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Opens [section] through the main menu, however it is shown: expanded
/// sidebar, collapsed icon rail (group pop-out) or the phone drawer.
Future<void> _openSection(WidgetTester tester, DashboardSection section) async {
  final item = find.byKey(ValueKey('menu-${section.name}'));
  if (item.evaluate().isEmpty) {
    final drawerButton = find.byKey(const ValueKey('open-menu'));
    if (drawerButton.evaluate().isNotEmpty) {
      await tester.tap(drawerButton);
    } else {
      await tester.tap(find.byKey(ValueKey('menu-group-${section.group!.name}')));
    }
    await tester.pumpAndSettle();
  }
  // In the drawer the item's group may start collapsed (Admin's team groups).
  if (item.evaluate().isEmpty) {
    final group = find.byKey(ValueKey('menu-group-${section.group!.name}'));
    await tester.ensureVisible(group);
    await tester.pumpAndSettle();
    await tester.tap(group);
    await tester.pumpAndSettle();
  }
  // Long menus (Admin) may need a scroll to reach the item.
  await tester.ensureVisible(item.last);
  await tester.pumpAndSettle();
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

/// Fills the site form's first step and moves on to the site's details.
Future<void> _completeLandStep(WidgetTester tester) async {
  Finder field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextFormField));
  await tester.enterText(field('site-owner'), 'Ramesh Kumar');
  await tester.enterText(field('site-total-area'), '1000');
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('site-next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('site-next')));
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(360, 780);
  const tablet = Size(900, 1000);
  const desktop = Size(1440, 1000);

  testWidgets('Phone: overview with banner, stats and charts, no overflow', (tester) async {
    await _pumpDashboard(tester, phone);

    expect(find.byType(DashboardMobileView), findsOneWidget);
    expect(find.byType(HeroBanner), findsOneWidget);
    expect(find.text('Total Sites'), findsOneWidget);
    expect(find.text('Sales by Location'), findsOneWidget);
    expect(find.text('Top Performing Sites'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-menu')), findsOneWidget);
  });

  testWidgets('Phone: sites and locations sections render without overflow', (tester) async {
    await _pumpDashboard(tester, phone);

    await _openSection(tester, DashboardSection.sites);
    expect(find.byType(SiteCard), findsWidgets);

    await _openSection(tester, DashboardSection.locations);
    expect(find.byType(LocationCard), findsWidgets);
  });

  testWidgets('Desktop: sidebar frame, all sections render', (tester) async {
    await _pumpDashboard(tester, desktop);

    expect(find.byType(DashboardWebView), findsOneWidget);
    expect(find.byType(HeroBanner), findsOneWidget);

    await _openSection(tester, DashboardSection.sites);
    expect(find.byType(SiteCard), findsNWidgets(7));

    await _openSection(tester, DashboardSection.locations);
    expect(find.byType(LocationCard), findsNWidgets(4));
  });

  testWidgets('Smallest web width renders every section without overflow', (tester) async {
    await _pumpDashboard(tester, tablet);
    expect(find.byType(DashboardWebView), findsOneWidget);

    await _openSection(tester, DashboardSection.sites);
    await _openSection(tester, DashboardSection.locations);
  });

  testWidgets('Opening a location shows only its sites', (tester) async {
    await _pumpDashboard(tester, desktop);

    await _openSection(tester, DashboardSection.locations);
    await tester.tap(find.widgetWithText(LocationCard, 'Chennai'));
    await tester.pumpAndSettle();

    expect(find.text('Chennai Sites'), findsOneWidget);
    expect(find.byType(SiteCard), findsOneWidget);
  });

  testWidgets('Adding a site in a new city on web creates that location', (tester) async {
    final controller = await _pumpDashboard(tester, desktop);

    await _openSection(tester, DashboardSection.sites);
    await tester.tap(find.text('Add Site'));
    await tester.pumpAndSettle();
    expect(find.text('Add New Site'), findsOneWidget);
    await _completeLandStep(tester);

    final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'Kaira Hill Crest');

    // Location dropdown: search for a city that is not listed yet, add it.
    await tester.tap(find.byKey(const ValueKey('site-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search locations'), 'Pune');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add "Pune" as new location'));
    await tester.pumpAndSettle();

    await tester.enterText(fields.at(1), '40');
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Add Site')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(controller.locations, contains('Pune'));
    expect(find.text('Kaira Hill Crest'), findsOneWidget);
  });

  testWidgets('Web sidebar collapses to icons and expands again', (tester) async {
    await _pumpDashboard(tester, desktop);

    // Wide window starts expanded with labels.
    expect(find.text('Masters'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse menu'));
    await tester.pumpAndSettle();
    expect(find.text('Masters'), findsNothing);
    expect(find.byTooltip('Masters'), findsOneWidget);

    // Icons still navigate while collapsed.
    await _openSection(tester, DashboardSection.locations);
    expect(find.byType(LocationCard), findsNWidgets(4));

    await tester.tap(find.byTooltip('Expand menu'));
    await tester.pumpAndSettle();
    expect(find.text('Masters'), findsOneWidget);
  });

  testWidgets('Web sidebar starts collapsed on narrower windows', (tester) async {
    await _pumpDashboard(tester, tablet);
    expect(find.text('Masters'), findsNothing);
    expect(find.byTooltip('Expand menu'), findsOneWidget);
  });

  testWidgets('Overview has no add button; Sites and Locations show their own', (tester) async {
    await _pumpDashboard(tester, desktop);
    expect(find.text('Add Site'), findsNothing);
    expect(find.text('Add Location'), findsNothing);

    await _openSection(tester, DashboardSection.sites);
    expect(find.text('Add Site'), findsOneWidget);
    expect(find.text('Add Location'), findsNothing);

    await _openSection(tester, DashboardSection.locations);
    expect(find.text('Add Location'), findsOneWidget);
    expect(find.text('Add Site'), findsNothing);
  });

  testWidgets('Phone: floating button follows the section', (tester) async {
    await _pumpDashboard(tester, phone);
    expect(find.byType(FloatingActionButton), findsNothing);

    await _openSection(tester, DashboardSection.locations);
    expect(find.widgetWithText(FloatingActionButton, 'Add Location'), findsOneWidget);

    await _openSection(tester, DashboardSection.sites);
    expect(find.widgetWithText(FloatingActionButton, 'Add Site'), findsOneWidget);
  });

  testWidgets('Adding a location on web shows it as an empty location card', (tester) async {
    final controller = await _pumpDashboard(tester, desktop);

    await _openSection(tester, DashboardSection.locations);
    await tester.tap(find.text('Add Location'));
    await tester.pumpAndSettle();

    final field = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));

    // Existing name is rejected, whatever the case.
    await tester.enterText(field, 'chennai');
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Add Location')).last);
    await tester.pumpAndSettle();
    expect(find.text('chennai is already a location.'), findsOneWidget);

    await tester.enterText(field, 'Pune');
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Add Location')).last);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(controller.locations, contains('Pune'));
    expect(find.widgetWithText(LocationCard, 'Pune'), findsOneWidget);
    expect(find.text('No sites yet — add one from the Sites menu.'), findsOneWidget);
  });

  testWidgets('Add site form fits a phone bottom sheet', (tester) async {
    await _pumpDashboard(tester, phone);

    await _openSection(tester, DashboardSection.sites);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add New Site'), findsOneWidget);
  });

  testWidgets('Add location form fits a phone bottom sheet', (tester) async {
    await _pumpDashboard(tester, phone);

    await _openSection(tester, DashboardSection.locations);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('City'), findsOneWidget);
  });

  testWidgets('Admin menu lists Dashboard, then Transactions, Masters and Reports', (tester) async {
    await _pumpDashboard(tester, desktop);

    // Admin sees every group; its own three start open.
    expect(MenuGroup.forRole(UserRole.admin), MenuGroup.values);
    for (final group in [MenuGroup.sales, MenuGroup.construction, MenuGroup.siteWork]) {
      expect(find.text(group.label), findsOneWidget);
    }
    for (final group in [MenuGroup.transactions, MenuGroup.masters, MenuGroup.reports]) {
      expect(find.text(group.label), findsOneWidget);
      for (final section in group.sections) {
        expect(find.byKey(ValueKey('menu-${section.name}')), findsOneWidget);
      }
    }
    expect(find.byKey(const ValueKey('menu-overview')), findsOneWidget);

    // Dashboard sits above the first group.
    final dashboardY = tester.getTopLeft(find.byKey(const ValueKey('menu-overview'))).dy;
    final firstGroupY = tester.getTopLeft(find.byKey(const ValueKey('menu-group-transactions'))).dy;
    expect(dashboardY, lessThan(firstGroupY));
  });

  testWidgets('Groups expand and collapse in the sidebar', (tester) async {
    await _pumpDashboard(tester, desktop);

    await tester.tap(find.byKey(const ValueKey('menu-group-reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-inventoryReport')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('menu-group-reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-inventoryReport')), findsOneWidget);
  });

  testWidgets('Logo opens the dashboard', (tester) async {
    await _pumpDashboard(tester, desktop);

    await _openSection(tester, DashboardSection.sites);
    expect(find.byType(HeroBanner), findsNothing);

    await tester.tap(find.byKey(const ValueKey('go-dashboard')));
    await tester.pumpAndSettle();
    expect(find.byType(HeroBanner), findsOneWidget);
  });

  testWidgets('Reports render with totals on desktop and phone', (tester) async {
    for (final size in [desktop, tablet, phone]) {
      await _pumpDashboard(tester, size);

      await _openSection(tester, DashboardSection.inventoryReport);
      expect(find.text('Kaira Green Meadows'), findsOneWidget);
      expect(find.text('All locations'), findsOneWidget);

      await _openSection(tester, DashboardSection.locationReport);
      expect(find.text('All locations'), findsOneWidget);
      expect(find.text('Sales by Location'), findsOneWidget);
    }
  });

  testWidgets('Inventory report follows the location filter', (tester) async {
    await _pumpDashboard(tester, desktop);

    await _openSection(tester, DashboardSection.inventoryReport);
    await tester.tap(find.text('Chennai').first);
    await tester.pumpAndSettle();

    expect(find.text('Kaira Coastal Residency'), findsOneWidget);
    expect(find.text('Kaira Green Meadows'), findsNothing);
  });

  testWidgets('Pages not built yet show coming soon', (tester) async {
    await _pumpDashboard(tester, phone);

    await _openSection(tester, DashboardSection.propertyUnits);
    expect(find.text('Property Units is coming soon'), findsOneWidget);
  });

  testWidgets('Dashboard menu item returns to the main page in every layout', (tester) async {
    for (final size in [desktop, tablet, phone]) {
      await _pumpDashboard(tester, size);

      await _openSection(tester, DashboardSection.inventoryReport);
      expect(find.byType(HeroBanner), findsNothing);

      await _openSection(tester, DashboardSection.overview);
      expect(find.byType(HeroBanner), findsOneWidget);
    }
  });

  testWidgets('Location dropdown searches and picks an existing location (web)', (tester) async {
    await _pumpDashboard(tester, desktop);
    await _openSection(tester, DashboardSection.sites);
    await tester.tap(find.text('Add Site'));
    await tester.pumpAndSettle();
    await _completeLandStep(tester);

    // Submitting without a location shows the dropdown's error.
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Add Site')));
    await tester.pumpAndSettle();
    expect(find.text('Please select a location.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('site-location')));
    await tester.pumpAndSettle();
    // All locations listed before searching.
    expect(
      find.descendant(of: find.byKey(const ValueKey('search-dropdown-panel')), matching: find.text('Vijayawada')),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Search locations'), 'chen');
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('search-dropdown-panel'));
    expect(find.descendant(of: panel, matching: find.text('Hyderabad')), findsNothing);
    expect(find.descendant(of: panel, matching: find.text('Chennai')), findsOneWidget);
    await tester.tap(find.descendant(of: panel, matching: find.text('Chennai')));
    await tester.pumpAndSettle();

    expect(find.text('Please select a location.'), findsNothing);
    expect(
      find.descendant(of: find.byKey(const ValueKey('site-location')), matching: find.text('Chennai')),
      findsOneWidget,
    );
  });

  testWidgets('Location dropdown opens as a searchable sheet on phone', (tester) async {
    await _pumpDashboard(tester, phone);
    await _openSection(tester, DashboardSection.sites);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _completeLandStep(tester);

    await tester.tap(find.byKey(const ValueKey('site-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search locations'), 'benga');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('search-dropdown-panel')), matching: find.text('Bengaluru')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byKey(const ValueKey('site-location')), matching: find.text('Bengaluru')),
      findsOneWidget,
    );
  });

  testWidgets('Top bar shows the user and a notification bell with unread badge', (tester) async {
    _setUser(tester);
    await _pumpDashboard(tester, desktop);

    expect(find.descendant(of: find.byType(UserGreeting), matching: find.text('Priya')), findsOneWidget);
    // 1 booking to approve + 2 upcoming launches + 2 sites selling fast
    // in the sample data.
    expect(
      find.descendant(of: find.byKey(const ValueKey('notification-badge')), matching: find.text('5')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('notification-bell')));
    await tester.pumpAndSettle();
    expect(find.text('Booking to approve'), findsOneWidget);
    expect(find.text('Upcoming launch'), findsNWidgets(2));
    expect(find.text('Selling fast'), findsNWidgets(2));
    // Opening marks them read.
    expect(find.byKey(const ValueKey('notification-badge')), findsNothing);

    // Tapping an alert opens that site's location.
    await tester.tap(find.textContaining('Kaira Tech Park Plaza'));
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru Sites'), findsOneWidget);
  });

  testWidgets('Top bar fits at the smallest web width and on phone', (tester) async {
    for (final size in [tablet, phone]) {
      _setUser(tester);
      await _pumpDashboard(tester, size);
      expect(find.byKey(const ValueKey('notification-bell')), findsOneWidget);
      await _openSection(tester, DashboardSection.sites);
    }
  });
  testWidgets('Admin can open every team\'s pages, in every layout', (tester) async {
    for (final size in [desktop, tablet, phone]) {
      await _pumpDashboard(tester, size);

      for (final section in DashboardSection.values) {
        expect(section.allows(UserRole.admin), isTrue);
      }
      for (final section in [
        DashboardSection.leads,
        DashboardSection.propertyBooking,
        DashboardSection.paymentTracking,
        DashboardSection.progressMonitoring,
        DashboardSection.dailyConstruction,
      ]) {
        await _openSection(tester, section);
        expect(find.text(section.subtitle), findsOneWidget);
      }
      // Admin can book too.
      await _openSection(tester, DashboardSection.propertyBooking);
      expect(find.text('New Booking'), size == phone ? findsOneWidget : findsWidgets);
    }
  });

  testWidgets('Other roles still cannot open Admin pages', (tester) async {
    for (final role in [UserRole.salesExecutive, UserRole.siteManager, UserRole.siteIncharge]) {
      for (final section in [DashboardSection.users, DashboardSection.sites, DashboardSection.bookingApproval]) {
        expect(section.allows(role), isFalse);
      }
    }
    expect(DashboardSection.propertyBooking.allows(UserRole.siteIncharge), isFalse);
  });

  testWidgets('Each role gets its own menu and workspace dashboard', (tester) async {
    final expected = {'sales': MenuGroup.sales, 'manager': MenuGroup.construction, 'incharge': MenuGroup.siteWork};

    for (final size in [desktop, tablet, phone]) {
      for (final entry in expected.entries) {
        final users = UserController.test();
        final user = users.findByUsername(entry.key)!;
        await _pumpDashboard(tester, size, user: user, users: users);

        // Role dashboard instead of the portfolio overview.
        expect(find.byType(RoleHomeSection), findsOneWidget);
        expect(find.byType(HeroBanner), findsNothing);
        expect(find.text('${user.role.label.toUpperCase()} WORKSPACE'), findsOneWidget);

        // A tile per module, opening its page.
        final modules = DashboardSection.forRole(user.role);
        expect(modules, entry.value.sections);
        for (final section in modules) {
          expect(find.byKey(ValueKey('module-${section.name}')), findsOneWidget);
        }
        await tester.ensureVisible(find.byKey(ValueKey('module-${modules.last.name}')));
        await tester.tap(find.byKey(ValueKey('module-${modules.last.name}')));
        await tester.pumpAndSettle();
        expect(find.text('${modules.last.label} is coming soon'), findsOneWidget);

        // Only the role's own group is in the menu.
        await _openSection(tester, modules.first);
        expect(find.text(modules.first.subtitle), findsOneWidget);
        expect(find.byKey(const ValueKey('menu-group-masters')), findsNothing);
        expect(find.byKey(const ValueKey('menu-sites')), findsNothing);
        if (find.byType(Drawer).evaluate().isNotEmpty) {
          Navigator.of(tester.element(find.byType(Drawer))).pop();
          await tester.pumpAndSettle();
        }
      }
    }
  });

  testWidgets('Non-admin roles get no portfolio alerts', (tester) async {
    final users = UserController.test();
    await _pumpDashboard(tester, desktop, user: users.findByUsername('sales'), users: users);

    expect(find.byKey(const ValueKey('notification-badge')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification-bell')));
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up."), findsOneWidget);
  });

  testWidgets('Admin adds a user with a role and can filter and remove users', (tester) async {
    for (final size in [desktop, phone]) {
      final users = UserController.test();
      await _pumpDashboard(tester, size, user: users.findByUsername('admin'), users: users);

      await _openSection(tester, DashboardSection.users);
      expect(find.byType(UsersSection), findsOneWidget);
      expect(find.byKey(const ValueKey('user-sales')), findsOneWidget);
      // The signed-in admin can edit but not remove themselves.
      await tester.tap(find.byKey(const ValueKey('user-menu-admin')));
      await tester.pumpAndSettle();
      expect(find.text('Edit user'), findsOneWidget);
      expect(find.text('Remove user'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(size == phone ? find.byType(FloatingActionButton) : find.text('Add User'));
      await tester.pumpAndSettle();

      // Validation, including a taken username.
      await tester.enterText(find.byKey(const ValueKey('user-username')), 'Sales');
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a name.'), findsOneWidget);
      expect(find.text('Please select a role.'), findsOneWidget);
      expect(find.text('Sales is already taken.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('user-name')), 'Anil Kumar');
      await tester.enterText(find.byKey(const ValueKey('user-username')), 'anil');
      await tester.enterText(find.byKey(const ValueKey('user-password')), 'short');
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('user-password')), 'secret12');
      await tester.ensureVisible(find.byKey(const ValueKey('user-role')));
      await tester.tap(find.byKey(const ValueKey('user-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site Incharge').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();

      final anil = users.findByUsername('anil')!;
      expect(anil.role, UserRole.siteIncharge);
      expect((await (users.repository as LocalUserRepository).login('anil', 'secret12')).id, anil.id);
      expect(find.byKey(const ValueKey('user-anil')), findsOneWidget);

      // Filter by role.
      await tester.tap(find.byKey(const ValueKey('role-filter-siteIncharge')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user-anil')), findsOneWidget);
      expect(find.byKey(const ValueKey('user-sales')), findsNothing);

      // Remove.
      await tester.ensureVisible(find.byKey(const ValueKey('user-menu-anil')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('user-menu-anil')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(users.findByUsername('anil'), isNull);
      expect(find.byKey(const ValueKey('user-anil')), findsNothing);
    }
  });
  testWidgets('Admin edits a user; Admins cannot be removed and your own role is locked', (tester) async {
    for (final size in [desktop, phone]) {
      final users = UserController.test();
      await users.addUser(
        const NewUser(name: 'Second Admin', username: 'boss', password: 'secret12', role: UserRole.admin),
      );
      await _pumpDashboard(tester, size, user: users.findByUsername('admin'), users: users);
      await _openSection(tester, DashboardSection.users);

      Future<void> openMenu(String username) async {
        await tester.ensureVisible(find.byKey(ValueKey('user-menu-$username')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('user-menu-$username')));
        await tester.pumpAndSettle();
      }

      // Another Admin: edit only, no remove.
      await openMenu('boss');
      expect(find.text('Edit user'), findsOneWidget);
      expect(find.text('Remove user'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Edit a Sales Executive: name, role, phone and a new password.
      await openMenu('sales');
      expect(find.text('Remove user'), findsOneWidget);
      await tester.tap(find.text('Edit user'));
      await tester.pumpAndSettle();
      expect(find.text('Edit User'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('user-name')), matching: find.text('Priya Sharma')),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('user-name')), 'Priya S');
      await tester.enterText(find.byKey(const ValueKey('user-phone')), '90000 12345');
      await tester.enterText(find.byKey(const ValueKey('user-password')), 'short');
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('user-password')), 'newpass12');
      await tester.ensureVisible(find.byKey(const ValueKey('user-role')));
      await tester.tap(find.byKey(const ValueKey('user-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site Manager').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();

      final priya = users.findByUsername('sales')!;
      expect(priya.name, 'Priya S');
      expect(priya.role, UserRole.siteManager);
      expect(priya.phone, '90000 12345');
      expect((await (users.repository as LocalUserRepository).login('sales', 'newpass12')).id, priya.id);
      expect(find.text('Priya S updated.'), findsOneWidget);

      // Editing yourself: the role cannot change; a blank password keeps it.
      await openMenu('admin');
      await tester.tap(find.text('Edit user'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppDropdown<UserRole>>(find.byKey(const ValueKey('user-role'))).enabled, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('user-submit')));
      await tester.tap(find.byKey(const ValueKey('user-submit')));
      await tester.pumpAndSettle();
      expect(users.findByUsername('admin')!.role, UserRole.admin);
      expect((await (users.repository as LocalUserRepository).login('admin', 'kaira123')).username, 'admin');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('User cards show each person\'s role and current work', (tester) async {
    for (final size in [desktop, phone]) {
      await _pumpDashboard(tester, size, user: 'admin');
      await _openSection(tester, DashboardSection.users);

      expect(find.text('Full access to every module'), findsOneWidget);
      expect(find.text('3 bookings raised'), findsOneWidget);
      expect(find.text('1 house under construction'), findsOneWidget);
      expect(find.text('1 house assigned'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    }
  });
}

/// Route argument carrying the username, as login passes it.
void _setUser(WidgetTester tester) => _username = 'Priya';
String? _username;
