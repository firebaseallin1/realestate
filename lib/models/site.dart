import 'package:crypto/crypto.dart' as crypto;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/api/json.dart';

/// SiteType is the kind of development a site offers.
enum SiteType {
  plots('Plots', Icons.grid_view_rounded),
  apartments('Apartments', Icons.apartment_rounded),
  villas('Villas', Icons.house_rounded),
  commercial('Commercial', Icons.storefront_rounded);

  const SiteType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// SiteStatus is where a site is in its sales lifecycle.
enum SiteStatus {
  upcoming('Upcoming'),
  active('Active'),
  completed('Completed');

  const SiteStatus(this.label);

  final String label;
}

/// SiteFile is an attached document: a site map, brochure or bill. A file just
/// picked has its [bytes]; one from the server has a [remoteId], and its bytes
/// are fetched when they are needed (see RemoteFileBytes).
class SiteFile {
  final String name;
  final Uint8List bytes;
  final String? remoteId;
  final int? remoteSize;

  /// SHA-256 of the bytes as the server worked it out, when uploaded.
  final String? sha256;

  const SiteFile({required this.name, required this.bytes, this.remoteId, this.remoteSize, this.sha256});

  factory SiteFile.fromJson(Map<String, dynamic> json) => SiteFile(
        name: json['name'] as String,
        bytes: Uint8List(0),
        remoteId: json['id'] as String,
        remoteSize: json['size'] as int?,
        sha256: (json['sha256'] as String?)?.isEmpty ?? true ? null : json['sha256'] as String,
      );

  /// A fingerprint of the content, the same for the same file however it
  /// is named. Null when neither the bytes nor the server's is known.
  String? get contentHash => sha256 ?? (bytes.isEmpty ? null : crypto.sha256.convert(bytes).toString());

  static const imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif'];

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isImage => imageExtensions.contains(extension);
  bool get isPdf => extension == 'pdf';

  /// Human-readable size, e.g. "240 KB" or "1.4 MB".
  String get sizeLabel {
    final kb = (remoteSize ?? bytes.lengthInBytes) / 1024;
    if (kb < 1024) return '${kb.ceil()} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// PlotFacing is the direction a plot's front (road side) faces.
/// [degrees] turns a north-pointing arrow to that direction.
enum PlotFacing {
  north('North', 'N', 0),
  northEast('North-East', 'NE', 45),
  east('East', 'E', 90),
  southEast('South-East', 'SE', 135),
  south('South', 'S', 180),
  southWest('South-West', 'SW', 225),
  west('West', 'W', 270),
  northWest('North-West', 'NW', 315);

  const PlotFacing(this.label, this.short, this.degrees);

  final String label;
  final String short;
  final double degrees;
}

/// PlotStatus is the sale state of one plot on the layout.
enum PlotStatus {
  available('Available'),
  booked('Booked'),
  sold('Sold');

  const PlotStatus(this.label);

  final String label;
}

/// Plot is one unit drawn on a site's layout. [rect] is where it sits on
/// the layout, in fractions (0–1) of the layout's width and height, so it
/// scales with the screen; [widthFt] × [lengthFt] is its real size.
class Plot {
  final String id;
  final String number;
  final double widthFt;
  final double lengthFt;
  final PlotFacing facing;
  final PlotStatus status;
  final double? price;
  final Rect rect;

  const Plot({
    required this.id,
    required this.number,
    required this.widthFt,
    required this.lengthFt,
    required this.facing,
    required this.status,
    required this.rect,
    this.price,
  });

  factory Plot.fromJson(Map<String, dynamic> json) {
    final rect = json['rect'] as Map<String, dynamic>;
    return Plot(
      id: json['id'] as String,
      number: json['number'] as String,
      widthFt: (json['widthFt'] as num).toDouble(),
      lengthFt: (json['lengthFt'] as num).toDouble(),
      facing: PlotFacing.values.byName(json['facing'] as String),
      status: PlotStatus.values.byName(json['status'] as String),
      price: json['pricePaise'] == null ? null : fromPaise(json['pricePaise'] as num),
      rect: Rect.fromLTWH(
        (rect['x'] as num).toDouble(),
        (rect['y'] as num).toDouble(),
        (rect['w'] as num).toDouble(),
        (rect['h'] as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'widthFt': widthFt,
        'lengthFt': lengthFt,
        'facing': facing.name,
        'status': status.name,
        'pricePaise': price == null ? null : toPaise(price!),
        'rect': {'x': rect.left, 'y': rect.top, 'w': rect.width, 'h': rect.height},
      };

  double get areaSqFt => widthFt * lengthFt;

  /// Square yards (1 sq yd = 9 sq ft), the usual unit for plots in India.
  double get areaSqYd => areaSqFt / 9;

  /// "30 × 40 ft", without trailing ".0".
  String get sizeLabel => '${_trim(widthFt)} × ${_trim(lengthFt)} ft';

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Plot copyWith({
    String? number,
    double? widthFt,
    double? lengthFt,
    PlotFacing? facing,
    PlotStatus? status,
    double? price,
    bool clearPrice = false,
    Rect? rect,
  }) {
    return Plot(
      id: id,
      number: number ?? this.number,
      widthFt: widthFt ?? this.widthFt,
      lengthFt: lengthFt ?? this.lengthFt,
      facing: facing ?? this.facing,
      status: status ?? this.status,
      price: clearPrice ? null : (price ?? this.price),
      rect: rect ?? this.rect,
    );
  }
}

/// Site is one real estate project at a location, with its unit inventory,
/// optional site map and brochure, and an optional drawn plot layout.
class Site {
  final String id;
  final String name;
  final String location;
  final SiteType type;
  final SiteStatus status;
  final int totalUnits;
  final int soldUnits;
  final int bookedUnits;
  final SiteFile? siteMap;
  final SiteFile? brochure;
  final List<Plot> plots;
  final String ownerName;

  /// Land areas in square yards; 0 means not entered.
  final double totalArea;
  final double salesArea;
  final double roadArea;
  final double gardenArea;
  final double otherArea;

  const Site({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    required this.status,
    required this.totalUnits,
    this.soldUnits = 0,
    this.bookedUnits = 0,
    this.siteMap,
    this.brochure,
    this.plots = const [],
    this.ownerName = '',
    this.totalArea = 0,
    this.salesArea = 0,
    this.roadArea = 0,
    this.gardenArea = 0,
    this.otherArea = 0,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    SiteFile? file(String key) =>
        json[key] == null ? null : SiteFile.fromJson(json[key] as Map<String, dynamic>);
    double area(String key) => (json[key] as num).toDouble();

    return Site(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      type: SiteType.values.byName(json['type'] as String),
      status: SiteStatus.values.byName(json['status'] as String),
      totalUnits: json['totalUnits'] as int,
      soldUnits: json['soldUnits'] as int,
      bookedUnits: json['bookedUnits'] as int,
      siteMap: file('siteMap'),
      brochure: file('brochure'),
      plots: [
        for (final plot in json['plots'] as List<dynamic>) Plot.fromJson(plot as Map<String, dynamic>),
      ],
      ownerName: json['ownerName'] as String? ?? '',
      totalArea: area('totalArea'),
      salesArea: area('salesArea'),
      roadArea: area('roadArea'),
      gardenArea: area('gardenArea'),
      otherArea: area('otherArea'),
    );
  }

  /// What the server saves for a site. Plots are saved on their own.
  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'type': type.name,
        'status': status.name,
        'totalUnits': totalUnits,
        'soldUnits': soldUnits,
        'bookedUnits': bookedUnits,
        'ownerName': ownerName,
        'totalArea': totalArea,
        'salesArea': salesArea,
        'roadArea': roadArea,
        'gardenArea': gardenArea,
        'otherArea': otherArea,
        'siteMapFileId': siteMap?.remoteId,
        'brochureFileId': brochure?.remoteId,
      };

  int get availableUnits => totalUnits - soldUnits - bookedUnits;

  /// False for sites added before owner and land details were recorded.
  bool get hasLandDetails => ownerName.isNotEmpty || totalArea > 0;

  /// Share of units sold, from 0.0 to 1.0.
  double get soldRatio => totalUnits == 0 ? 0 : soldUnits / totalUnits;

  /// True once plots are drawn; unit counts then come from the layout.
  bool get hasLayout => plots.isNotEmpty;

  /// This site with [plots] as its layout. With any plots, total / sold /
  /// booked units are recounted from them so the map and figures agree.
  Site withPlots(List<Plot> plots) {
    if (plots.isEmpty) return copyWith(plots: const []);
    return copyWith(
      plots: plots,
      totalUnits: plots.length,
      soldUnits: plots.where((p) => p.status == PlotStatus.sold).length,
      bookedUnits: plots.where((p) => p.status == PlotStatus.booked).length,
    );
  }

  Site copyWith({
    String? name,
    String? location,
    SiteType? type,
    SiteStatus? status,
    int? totalUnits,
    int? soldUnits,
    int? bookedUnits,
    SiteFile? siteMap,
    SiteFile? brochure,
    List<Plot>? plots,
    String? ownerName,
    double? totalArea,
    double? salesArea,
    double? roadArea,
    double? gardenArea,
    double? otherArea,
  }) {
    return Site(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      type: type ?? this.type,
      status: status ?? this.status,
      totalUnits: totalUnits ?? this.totalUnits,
      soldUnits: soldUnits ?? this.soldUnits,
      bookedUnits: bookedUnits ?? this.bookedUnits,
      siteMap: siteMap ?? this.siteMap,
      brochure: brochure ?? this.brochure,
      plots: plots ?? this.plots,
      ownerName: ownerName ?? this.ownerName,
      totalArea: totalArea ?? this.totalArea,
      salesArea: salesArea ?? this.salesArea,
      roadArea: roadArea ?? this.roadArea,
      gardenArea: gardenArea ?? this.gardenArea,
      otherArea: otherArea ?? this.otherArea,
    );
  }
}

/// LocationSummary rolls up every site at one location.
class LocationSummary {
  final String name;
  final int siteCount;
  final int totalUnits;
  final int soldUnits;
  final int bookedUnits;
  final Set<SiteType> types;

  /// Where the location is on the map, when one was picked.
  final MapPoint? point;

  const LocationSummary({
    required this.name,
    required this.siteCount,
    required this.totalUnits,
    required this.soldUnits,
    required this.bookedUnits,
    required this.types,
    this.point,
  });

  int get availableUnits => totalUnits - soldUnits - bookedUnits;

  double get soldRatio => totalUnits == 0 ? 0 : soldUnits / totalUnits;
}

/// A spot on the map, in degrees.
class MapPoint {
  final double latitude;
  final double longitude;

  const MapPoint(this.latitude, this.longitude);

  /// Six decimals is about 10 cm, more than enough for a city or plot.
  String get label => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  @override
  bool operator ==(Object other) =>
      other is MapPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// A location as the server keeps it: its name and, when picked, where it
/// is on the map.
class LocationInfo {
  final String? id;
  final String name;
  final MapPoint? point;

  const LocationInfo({this.id, required this.name, this.point});

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'] as num?;
    final lng = json['longitude'] as num?;
    return LocationInfo(
      id: json['id'] as String?,
      name: json['name'] as String,
      point: lat == null || lng == null ? null : MapPoint(lat.toDouble(), lng.toDouble()),
    );
  }
}
