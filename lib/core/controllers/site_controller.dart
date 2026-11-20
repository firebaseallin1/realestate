import 'package:flutter/material.dart';

import '../../models/site.dart';
import '../repositories/site_repository.dart';

/// SiteController holds every location and every site across them, plus
/// the dashboard's location filter and search. Locations can be added on
/// their own, and adding a site in a new city also creates that location.
///
/// The app's [instance] loads from and saves to the server, which throws an
/// ApiException if it refuses a change. Test controllers have no repository
/// and work on sample data in memory.
class SiteController extends ChangeNotifier {
  static final SiteController instance = SiteController._internal();

  factory SiteController() => instance;

  SiteController._internal() : _repository = SiteRepository();

  /// Fresh controller with its own data, for tests.
  @visibleForTesting
  SiteController.test() : _repository = null {
    _sites.addAll(_sampleSites);
    _seedLocations();
  }

  final SiteRepository? _repository;

  final List<Site> _sites = [];

  static const List<Site> _sampleSites = [
    Site(
      id: 's1',
      name: 'Kaira Green Meadows',
      location: 'Hyderabad',
      type: SiteType.plots,
      status: SiteStatus.active,
      totalUnits: 240,
      soldUnits: 168,
      bookedUnits: 22,
    ),
    Site(
      id: 's2',
      name: 'Kaira Skyline Towers',
      location: 'Hyderabad',
      type: SiteType.apartments,
      status: SiteStatus.active,
      totalUnits: 320,
      soldUnits: 141,
      bookedUnits: 36,
    ),
    Site(
      id: 's3',
      name: 'Kaira Lake View Villas',
      location: 'Hyderabad',
      type: SiteType.villas,
      status: SiteStatus.upcoming,
      totalUnits: 64,
      bookedUnits: 18,
    ),
    Site(
      id: 's4',
      name: 'Kaira Orchid Enclave',
      location: 'Bengaluru',
      type: SiteType.apartments,
      status: SiteStatus.active,
      totalUnits: 280,
      soldUnits: 196,
      bookedUnits: 30,
    ),
    Site(
      id: 's5',
      name: 'Kaira Tech Park Plaza',
      location: 'Bengaluru',
      type: SiteType.commercial,
      status: SiteStatus.upcoming,
      totalUnits: 90,
      bookedUnits: 12,
    ),
    Site(
      id: 's6',
      name: 'Kaira Coastal Residency',
      location: 'Chennai',
      type: SiteType.apartments,
      status: SiteStatus.completed,
      totalUnits: 180,
      soldUnits: 180,
    ),
    Site(
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

  /// Server IDs and map points of locations, by lowercase name.
  final Map<String, LocationInfo> _locationInfo = {};

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

  /// Where [location] is on the map, or null if no point was picked.
  MapPoint? pointOf(String location) => _locationInfo[location.trim().toLowerCase()]?.point;

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
  List<Site> sitesIn(String? location) =>
      location == null ? sites : _sites.where((s) => s.location == location).toList();

  int siteCountAt(String location) => _sites.where((s) => s.location == location).length;

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
        point: pointOf(name),
      );
    }).toList();
  }

  /// Best-selling sites first, by share of units sold.
  List<Site> topSites({int count = 4}) {
    final sorted = [..._sites]..sort((a, b) => b.soldRatio.compareTo(a.soldRatio));
    return sorted.take(count).toList();
  }

  int countWithStatus(SiteStatus status) => _sites.where((s) => s.status == status).length;

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

  /// Fetches the sites and locations from the server.
  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    final results = await Future.wait([repository.fetchSites(), repository.fetchLocations()]);
    _sites
      ..clear()
      ..addAll(results[0] as List<Site>);
    final locations = results[1] as List<LocationInfo>;
    _locations
      ..clear()
      ..addAll(locations.map((l) => l.name));
    _locationInfo
      ..clear()
      ..addEntries(locations.map((l) => MapEntry(l.name.toLowerCase(), l)));
    notifyListeners();
  }

  /// Forgets everything on sign-out, so the next user cannot see it.
  void clear() {
    _sites.clear();
    _locations.clear();
    _locationInfo.clear();
    _selectedLocation = null;
    _query = '';
    notifyListeners();
  }

  /// Adds a location, with its map point if one was picked, on the
  /// server, or in memory for tests.
  Future<void> saveLocation(String name, {MapPoint? point}) async {
    final repository = _repository;
    if (repository == null) {
      if (addLocation(name) && point != null) {
        _locationInfo[name.trim().toLowerCase()] = LocationInfo(name: name.trim(), point: point);
        notifyListeners();
      }
      return;
    }
    final saved = await repository.addLocation(name.trim(), point: point);
    _locations.add(saved.name);
    _locationInfo[saved.name.toLowerCase()] = saved;
    notifyListeners();
  }

  /// Sets where an existing location is on the map, or clears it.
  Future<void> setLocationPoint(String name, MapPoint? point) async {
    final key = name.trim().toLowerCase();
    final repository = _repository;
    if (repository == null) {
      _locationInfo[key] = LocationInfo(name: name.trim(), point: point);
      notifyListeners();
      return;
    }
    // A location made by adding a site arrives without its ID until reloaded.
    var id = _locationInfo[key]?.id;
    if (id == null) {
      for (final location in await repository.fetchLocations()) {
        _locationInfo[location.name.toLowerCase()] = location;
      }
      id = _locationInfo[key]?.id;
    }
    if (id == null) throw StateError('$name is not a saved location.');
    _locationInfo[key] = await repository.setLocationPoint(id, point);
    notifyListeners();
  }

  Future<void> addSite(Site site) async {
    final repository = _repository;
    if (repository == null) {
      _ensureLocation(site.location);
      _sites.add(site);
      notifyListeners();
      return;
    }
    final saved = await repository.createSite(site);
    _ensureLocation(saved.location);
    _sites.add(saved);
    notifyListeners();
  }

  Future<void> updateSite(Site site) async {
    final repository = _repository;
    if (repository == null) {
      _replaceSite(site);
      return;
    }
    _replaceSite(await repository.updateSite(site));
  }

  /// Saves the site's drawn plots. Its unit counts follow them.
  Future<void> savePlots(Site site, List<Plot> plots) async {
    final repository = _repository;
    if (repository == null) {
      _replaceSite(site.withPlots(plots));
      return;
    }
    _replaceSite(await repository.savePlots(site.id, plots));
  }

  void _replaceSite(Site site) {
    final index = _sites.indexWhere((s) => s.id == site.id);
    if (index == -1) return;
    _ensureLocation(site.location);
    _sites[index] = site;
    notifyListeners();
  }

  /// Removes the site; its location stays, even with no sites left. The
  /// server refuses if the site has bookings.
  Future<void> deleteSite(String id) async {
    final repository = _repository;
    if (repository != null) await repository.deleteSite(id);
    _sites.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
