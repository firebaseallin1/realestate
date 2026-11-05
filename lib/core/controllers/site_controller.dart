import 'package:flutter/material.dart';
import '../../models/site.dart';

/// SiteController holds every location and every site across them, plus
/// the dashboard's location filter and search. Locations can be added on
/// their own, and adding a site in a new city also creates that location.
///
/// Data is kept in memory for now; swap [_sites] for an API later.
class SiteController extends ChangeNotifier {
  static final SiteController instance = SiteController._internal();

  factory SiteController() => instance;

  SiteController._internal() {
    _seedLocations();
  }

  /// Fresh controller with its own data, for tests.
  @visibleForTesting
  SiteController.test() {
    _seedLocations();
  }

  final List<Site> _sites = [
    const Site(
      id: 's1',
      name: 'Kaira Green Meadows',
      location: 'Hyderabad',
      type: SiteType.plots,
      status: SiteStatus.active,
      totalUnits: 240,
      soldUnits: 168,
      bookedUnits: 22,
    ),
    const Site(
      id: 's2',
      name: 'Kaira Skyline Towers',
      location: 'Hyderabad',
      type: SiteType.apartments,
      status: SiteStatus.active,
      totalUnits: 320,
      soldUnits: 141,
      bookedUnits: 36,
    ),
    const Site(
      id: 's3',
      name: 'Kaira Lake View Villas',
      location: 'Hyderabad',
      type: SiteType.villas,
      status: SiteStatus.upcoming,
      totalUnits: 64,
      bookedUnits: 18,
    ),
    const Site(
      id: 's4',
      name: 'Kaira Orchid Enclave',
      location: 'Bengaluru',
      type: SiteType.apartments,
      status: SiteStatus.active,
      totalUnits: 280,
      soldUnits: 196,
      bookedUnits: 30,
    ),
    const Site(
      id: 's5',
      name: 'Kaira Tech Park Plaza',
      location: 'Bengaluru',
      type: SiteType.commercial,
      status: SiteStatus.upcoming,
      totalUnits: 90,
      bookedUnits: 12,
    ),
    const Site(
      id: 's6',
      name: 'Kaira Coastal Residency',
      location: 'Chennai',
      type: SiteType.apartments,
      status: SiteStatus.completed,
      totalUnits: 180,
      soldUnits: 180,
    ),
    const Site(
      id: 's7',
      name: 'Kaira River Front Plots',
      location: 'Vijayawada',
      type: SiteType.plots,
      status: SiteStatus.active,
      totalUnits: 150,
      soldUnits: 64,
      bookedUnits: 21,
    ),
  ];

  /// Every managed location, including ones that have no sites yet.
  final List<String> _locations = [];

  /// Starts the location list from the sample sites.
  void _seedLocations() {
    for (final site in _sites) {
      _ensureLocation(site.location);
    }
  }

  String? _selectedLocation;
  String _query = '';

  // Getters
  List<Site> get sites => List.unmodifiable(_sites);
  String? get selectedLocation => _selectedLocation;
  String get query => _query;

  List<String> get locations => [..._locations]..sort();

  /// The stored spelling of [name] if it is already a location
  /// (ignoring case and surrounding spaces), otherwise null.
  String? findLocation(String name) {
    final key = name.trim().toLowerCase();
    for (final location in _locations) {
      if (location.toLowerCase() == key) return location;
    }
    return null;
  }

  /// Sites matching the selected location and the search text.
  List<Site> get filteredSites {
    final q = _query.trim().toLowerCase();
    return _sites.where((site) {
      if (_selectedLocation != null && site.location != _selectedLocation) {
        return false;
      }
      if (q.isEmpty) return true;
      return site.name.toLowerCase().contains(q) ||
          site.location.toLowerCase().contains(q) ||
          site.type.label.toLowerCase().contains(q);
    }).toList();
  }

  Site? siteById(String id) {
    for (final site in _sites) {
      if (site.id == id) return site;
    }
    return null;
  }

  /// Sites at [location], or every site when it is null. Ignores search.
  List<Site> sitesIn(String? location) => location == null
      ? sites
      : _sites.where((s) => s.location == location).toList();

  int siteCountAt(String location) =>
      _sites.where((s) => s.location == location).length;

  List<LocationSummary> get locationSummaries {
    return locations.map((name) {
      final atLocation = _sites.where((s) => s.location == name);
      return LocationSummary(
        name: name,
        siteCount: atLocation.length,
        totalUnits: atLocation.fold(0, (sum, s) => sum + s.totalUnits),
        soldUnits: atLocation.fold(0, (sum, s) => sum + s.soldUnits),
        bookedUnits: atLocation.fold(0, (sum, s) => sum + s.bookedUnits),
        types: atLocation.map((s) => s.type).toSet(),
      );
    }).toList();
  }

  /// Best-selling sites first, by share of units sold.
  List<Site> topSites({int count = 4}) {
    final sorted = [..._sites]..sort((a, b) => b.soldRatio.compareTo(a.soldRatio));
    return sorted.take(count).toList();
  }

  int countWithStatus(SiteStatus status) =>
      _sites.where((s) => s.status == status).length;

  // Portfolio totals across every location
  int get totalUnits => _sites.fold(0, (sum, s) => sum + s.totalUnits);
  int get soldUnits => _sites.fold(0, (sum, s) => sum + s.soldUnits);
  int get bookedUnits => _sites.fold(0, (sum, s) => sum + s.bookedUnits);
  int get availableUnits => _sites.fold(0, (sum, s) => sum + s.availableUnits);
  double get soldRatio => totalUnits == 0 ? 0 : soldUnits / totalUnits;

  void selectLocation(String? location) {
    if (_selectedLocation != location) {
      _selectedLocation = location;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_query != value) {
      _query = value;
      notifyListeners();
    }
  }

  /// Adds a new location with no sites yet. Returns false when a location
  /// with that name (ignoring case) already exists.
  bool addLocation(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || findLocation(trimmed) != null) return false;
    _locations.add(trimmed);
    notifyListeners();
    return true;
  }

  /// A site in a city that is not yet a location creates that location.
  void _ensureLocation(String name) {
    if (findLocation(name) == null) _locations.add(name.trim());
  }

  void addSite(Site site) {
    _ensureLocation(site.location);
    _sites.add(site);
    notifyListeners();
  }

  void updateSite(Site site) {
    final index = _sites.indexWhere((s) => s.id == site.id);
    if (index == -1) return;
    _ensureLocation(site.location);
    _sites[index] = site;
    notifyListeners();
  }

  /// Removes the site; its location stays, even with no sites left.
  void deleteSite(String id) {
    _sites.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
