import '../../models/site.dart';
import '../api/api_client.dart';
import 'file_repository.dart';

/// Sites, their plots and locations on the server.
class SiteRepository {
  SiteRepository({ApiClient? api, FileRepository? files})
    : _api = api ?? ApiClient.instance,
      _files = files ?? FileRepository.instance;

  final ApiClient _api;
  final FileRepository _files;

  Future<List<Site>> fetchSites() async {
    final page = await _api.get('/sites');
    return [for (final json in page!['items'] as List<dynamic>) Site.fromJson(json as Map<String, dynamic>)];
  }

  Future<List<LocationInfo>> fetchLocations() async {
    final page = await _api.get('/locations');
    return [for (final json in page!['items'] as List<dynamic>) LocationInfo.fromJson(json as Map<String, dynamic>)];
  }

  Future<LocationInfo> addLocation(String name, {MapPoint? point}) async {
    final json = await _api.post(
      '/locations',
      body: {
        'name': name,
        if (point != null) ...{'latitude': point.latitude, 'longitude': point.longitude},
      },
    );
    return LocationInfo.fromJson(json!);
  }

  /// Sets the location's map point, or clears it when [point] is null.
  Future<LocationInfo> setLocationPoint(String id, MapPoint? point) async {
    final json = await _api.patch('/locations/$id', body: {'latitude': point?.latitude, 'longitude': point?.longitude});
    return LocationInfo.fromJson(json!);
  }

  Future<Site> createSite(Site site) async {
    final json = await _api.post('/sites', body: (await _withUploads(site)).toJson());
    return Site.fromJson(json!);
  }

  Future<Site> updateSite(Site site) async {
    final json = await _api.patch('/sites/${site.id}', body: (await _withUploads(site)).toJson());
    return Site.fromJson(json!);
  }

  Future<void> deleteSite(String id) async {
    await _api.delete('/sites/$id');
  }

  Future<Site> savePlots(String siteId, List<Plot> plots) async {
    final json = await _api.put(
      '/sites/$siteId/plots',
      body: {
        'plots': [for (final plot in plots) plot.toJson()],
      },
    );
    return Site.fromJson(json!);
  }

  Future<Site> _withUploads(Site site) async {
    final map = site.siteMap;
    final brochure = site.brochure;
    return Site(
      id: site.id,
      name: site.name,
      location: site.location,
      type: site.type,
      status: site.status,
      totalUnits: site.totalUnits,
      soldUnits: site.soldUnits,
      bookedUnits: site.bookedUnits,
      siteMap: map == null ? null : await _files.ensureUploaded(map),
      brochure: brochure == null ? null : await _files.ensureUploaded(brochure),
      ownerName: site.ownerName,
      totalArea: site.totalArea,
      salesArea: site.salesArea,
      roadArea: site.roadArea,
      gardenArea: site.gardenArea,
      otherArea: site.otherArea,
    );
  }
}
