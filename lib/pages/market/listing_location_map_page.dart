import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../services/market_listing_repository.dart';
import '../../widgets/app_components.dart';
import 'product_detail_page.dart';

class ListingLocationMapPage extends StatelessWidget {
  const ListingLocationMapPage({super.key, required this.item, this.items});

  final MarketItem item;
  final List<MarketItem>? items;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MarketItem>>(
      stream: items == null
          ? MarketListingRepository.instance.watchActiveListings()
          : Stream<List<MarketItem>>.value(items!),
      builder: (context, snapshot) {
        final sourceItems = snapshot.data ?? const <MarketItem>[];
        final nearbyItems = _nearbyItemsFor(item, sourceItems);

        return AppPageScaffold(
          title: '发布地点',
          previousPageTitle: '商品详情',
          child: AppBackdrop(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _SelectedItemCard(item: item),
                const SizedBox(height: 18),
                AspectRatio(
                  aspectRatio: 0.78,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: _MapboxListingMap(
                      selectedItem: item,
                      nearbyItems: nearbyItems,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionTitle(
                        title: '附近同类商品',
                        subtitle:
                            snapshot.connectionState == ConnectionState.waiting
                            ? '正在同步附近商品'
                            : '可以横向比较距离和价格',
                      ),
                      const SizedBox(height: 16),
                      if (nearbyItems.isEmpty)
                        Text(
                          context.l10n.ui('附近暂时没有同类商品'),
                          style: const TextStyle(color: AppPalette.mutedText),
                        )
                      else
                        for (final nearby in nearbyItems.take(3)) ...[
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                CupertinoPageRoute<void>(
                                  builder: (_) =>
                                      ProductDetailPage(item: nearby),
                                ),
                              );
                            },
                            child: _NearbyRow(item: nearby),
                          ),
                          if (nearby != nearbyItems.take(3).last)
                            const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectedItemCard extends StatelessWidget {
  const _SelectedItemCard({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon, color: AppPalette.ink, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.listingText(item.title, item.titleEn),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.location} · ${item.distance.toStringAsFixed(1)}km',
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '£${item.price}',
            style: const TextStyle(
              color: AppPalette.brand,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapboxListingMap extends StatefulWidget {
  const _MapboxListingMap({
    required this.selectedItem,
    required this.nearbyItems,
  });

  final MarketItem selectedItem;
  final List<MarketItem> nearbyItems;

  @override
  State<_MapboxListingMap> createState() => _MapboxListingMapState();
}

class _MapboxListingMapState extends State<_MapboxListingMap> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  bool _mapReady = false;
  String? _loadError;

  CameraOptions get _selectedCamera => CameraOptions(
    center: Point(
      coordinates: Position(
        widget.selectedItem.longitude,
        widget.selectedItem.latitude,
      ),
    ),
    zoom: 13.6,
    pitch: 34,
    bearing: -12,
  );

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(
      AttributionSettings(marginBottom: 10, marginRight: 10),
    );
    await mapboxMap.setCamera(_selectedCamera);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    try {
      await _addListingAnnotations();
      if (mounted) {
        setState(() {
          _mapReady = true;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mapReady = true;
          _loadError = '地图标记加载失败，请稍后重试';
        });
      }
    }
  }

  void _onMapLoadError(MapLoadingErrorEventData event) {
    if (!mounted) {
      return;
    }
    if (event.type != MapLoadErrorType.STYLE &&
        event.type != MapLoadErrorType.SOURCE) {
      return;
    }
    if (mounted) {
      setState(() {
        _mapReady = true;
        _loadError = '地图加载失败，请检查网络或 Mapbox Token';
      });
    }
  }

  Future<void> _addListingAnnotations() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    _circleAnnotationManager ??= await mapboxMap.annotations
        .createCircleAnnotationManager();
    await _circleAnnotationManager?.deleteAll();

    final options = <CircleAnnotationOptions>[
      for (final item in widget.nearbyItems)
        CircleAnnotationOptions(
          geometry: _pointForItem(item),
          circleColor: _mapColor(AppPalette.brand),
          circleOpacity: 0.82,
          circleRadius: 9,
          circleStrokeColor: _mapColor(CupertinoColors.white),
          circleStrokeWidth: 3,
        ),
      CircleAnnotationOptions(
        geometry: _pointForItem(widget.selectedItem),
        circleColor: _mapColor(AppPalette.ink),
        circleRadius: 14,
        circleStrokeColor: _mapColor(AppPalette.yellow),
        circleStrokeWidth: 5,
      ),
    ];

    await _circleAnnotationManager?.createMulti(options);
  }

  Future<void> _recenter() async {
    await _mapboxMap?.setCamera(_selectedCamera);
  }

  @override
  void didUpdateWidget(covariant _MapboxListingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedItem.id != widget.selectedItem.id) {
      _mapboxMap?.setCamera(_selectedCamera);
      if (_mapReady) {
        _addListingAnnotations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: ValueKey('listing-map-${widget.selectedItem.id}'),
          // ignore: deprecated_member_use
          cameraOptions: _selectedCamera,
          styleUri: MapboxStyles.LIGHT,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          onMapLoadErrorListener: _onMapLoadError,
        ),
        if (!_mapReady)
          Container(
            color: AppPalette.backgroundCool,
            alignment: Alignment.center,
            child: const CupertinoActivityIndicator(radius: 13),
          ),
        if (_loadError != null)
          Container(
            color: AppPalette.backgroundCool,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: _MapErrorCard(message: _loadError!),
          ),
        if (_loadError == null)
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: _MapOverlayCard(
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.location_solid,
                    color: AppPalette.brand,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.selectedItem.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AppTag(
                    label:
                        '${widget.selectedItem.distance.toStringAsFixed(1)}km',
                    color: AppPalette.yellow,
                    textColor: AppPalette.ink,
                  ),
                ],
              ),
            ),
          ),
        if (_loadError == null)
          Positioned(
            right: 14,
            bottom: 92,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: _recenter,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220F1915),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.scope,
                  color: AppPalette.brand,
                  size: 24,
                ),
              ),
            ),
          ),
        if (_loadError == null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _MapOverlayCard(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppPalette.ink,
                      border: Border.all(color: AppPalette.yellow, width: 3),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      widget.selectedItem.icon,
                      color: AppPalette.mint,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.ui('卖家发布位置'),
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.l10n.listingText(
                            widget.selectedItem.title,
                            widget.selectedItem.titleEn,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.strongText,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '£${widget.selectedItem.price}',
                    style: const TextStyle(
                      color: AppPalette.brand,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MapErrorCard extends StatelessWidget {
  const _MapErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.map_pin_ellipse,
            color: AppPalette.brand,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.ui(message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.strongText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapOverlayCard extends StatelessWidget {
  const _MapOverlayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F1915),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(item.icon, color: AppPalette.ink, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.listingText(item.title, item.titleEn),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.strongText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.location} · ${item.distance.toStringAsFixed(1)}km',
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          '£${item.price}',
          style: const TextStyle(
            color: AppPalette.brand,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

Point _pointForItem(MarketItem item) {
  return Point(coordinates: Position(item.longitude, item.latitude));
}

int _mapColor(Color color) {
  return color.toARGB32();
}

List<MarketItem> _nearbyItemsFor(
  MarketItem selectedItem,
  List<MarketItem> all,
) {
  final sameCategory = all
      .where((item) {
        return item.id != selectedItem.id &&
            item.category == selectedItem.category;
      })
      .map((item) {
        return item.copyWith(
          distance: _distanceInKm(
            selectedItem.latitude,
            selectedItem.longitude,
            item.latitude,
            item.longitude,
          ),
        );
      })
      .toList();

  sameCategory.sort((a, b) => a.distance.compareTo(b.distance));
  return sameCategory;
}

double _distanceInKm(
  double fromLatitude,
  double fromLongitude,
  double toLatitude,
  double toLongitude,
) {
  const earthRadiusKm = 6371.0;
  final deltaLat = _degreesToRadians(toLatitude - fromLatitude);
  final deltaLng = _degreesToRadians(toLongitude - fromLongitude);
  final fromLatRad = _degreesToRadians(fromLatitude);
  final toLatRad = _degreesToRadians(toLatitude);

  final haversine =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(fromLatRad) *
          math.cos(toLatRad) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return earthRadiusKm *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

double _degreesToRadians(double degrees) {
  return degrees * math.pi / 180;
}
