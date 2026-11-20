import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/models/site.dart';

void main() {
  test('Locations are derived from sites and sorted', () {
    final c = SiteController.test();
    expect(c.locations, ['Bengaluru', 'Chennai', 'Hyderabad', 'Vijayawada']);
  });

  test('Adding a site in a new city creates that location', () {
    final c = SiteController.test();
    c.addSite(const Site(
      id: 'x',
      name: 'Kaira Hill Crest',
      location: 'Pune',
      type: SiteType.villas,
      status: SiteStatus.upcoming,
      totalUnits: 40,
    ));
    expect(c.locations, contains('Pune'));
    expect(c.siteCountAt('Pune'), 1);
  });

  test('Location filter and search narrow the site list', () {
    final c = SiteController.test();
    c.selectLocation('Hyderabad');
    expect(c.filteredSites.every((s) => s.location == 'Hyderabad'), isTrue);
    c.setQuery('villa');
    expect(c.filteredSites.map((s) => s.name), ['Kaira Lake View Villas']);
  });

  test('A location stays after its last site is deleted', () {
    final c = SiteController.test();
    c.deleteSite('s6');
    expect(c.locations, contains('Chennai'));
    expect(c.siteCountAt('Chennai'), 0);
  });

  test('Locations can be added without sites, duplicates are rejected', () {
    final c = SiteController.test();
    expect(c.addLocation('Pune'), isTrue);
    expect(c.locations, contains('Pune'));
    expect(c.siteCountAt('Pune'), 0);
    expect(c.addLocation('  pune '), isFalse);
    expect(c.addLocation('HYDERABAD'), isFalse);
    expect(c.locations.where((l) => l == 'Pune').length, 1);
  });

  test('Totals add up across locations', () {
    final c = SiteController.test();
    expect(c.soldUnits + c.bookedUnits + c.availableUnits, c.totalUnits);
  });

  test('A location keeps its map point and shows it in its summary', () async {
    final c = SiteController.test();
    const goa = MapPoint(15.4909, 73.8278);
    await c.saveLocation('Goa', point: goa);
    expect(c.pointOf('goa'), goa);
    expect(c.locationSummaries.firstWhere((s) => s.name == 'Goa').point, goa);

    expect(c.pointOf('Chennai'), isNull);
    const chennai = MapPoint(13.0827, 80.2707);
    await c.setLocationPoint('Chennai', chennai);
    expect(c.locationSummaries.firstWhere((s) => s.name == 'Chennai').point, chennai);

    await c.setLocationPoint('Chennai', null);
    expect(c.pointOf('Chennai'), isNull);
  });

  test('A map point is read from the server, or absent', () {
    final withPoint = LocationInfo.fromJson({'id': 'l1', 'name': 'Goa', 'latitude': 15.5, 'longitude': 73});
    expect(withPoint.point, const MapPoint(15.5, 73.0));
    final without = LocationInfo.fromJson({'id': 'l2', 'name': 'Pune', 'latitude': null, 'longitude': null});
    expect(without.point, isNull);
  });
}
