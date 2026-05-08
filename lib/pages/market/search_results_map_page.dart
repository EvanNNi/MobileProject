import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../widgets/app_components.dart';
import 'product_detail_page.dart';

class SearchResultsMapPage extends StatefulWidget {
  const SearchResultsMapPage({
    super.key,
    required this.items,
    required this.queryLabel,
  });

  final List<MarketItem> items;
  final String queryLabel;

  @override
  State<SearchResultsMapPage> createState() => _SearchResultsMapPageState();
}

class _SearchResultsMapPageState extends State<SearchResultsMapPage> {
  late final List<MarketItem> _mapItems;
  late final PageController _cardController;
  final Map<String, Uint8List> _pinImageCache = {};
  final Map<String, String> _annotationItemIds = {};

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  bool _mapReady = false;
  bool _didFitInitialCamera = false;
  bool _tapHandlerAttached = false;
  String? _loadError;
  int _selectedIndex = 0;

  MarketItem get _selectedItem => _mapItems[_selectedIndex];

  CameraOptions get _initialCamera {
    final item = _mapItems.first;
    return CameraOptions(
      center: _pointForItem(item),
      zoom: 12.8,
      pitch: 0,
      bearing: 0,
    );
  }

  @override
  void initState() {
    super.initState();
    _mapItems = widget.items.where(_hasValidLocation).toList(growable: false);
    _cardController = PageController(viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(
      AttributionSettings(marginBottom: 10, marginRight: 10),
    );
    await mapboxMap.setCamera(_initialCamera);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    try {
      await _refreshAnnotations();
      await _fitAllPins();
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
    if (!mounted ||
        (event.type != MapLoadErrorType.STYLE &&
            event.type != MapLoadErrorType.SOURCE)) {
      return;
    }
    setState(() {
      _mapReady = true;
      _loadError = '地图加载失败，请检查网络或 Mapbox Token';
    });
  }

  Future<void> _ensureAnnotationManager() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    _pointAnnotationManager ??= await mapboxMap.annotations
        .createPointAnnotationManager();
    await _pointAnnotationManager?.setIconAllowOverlap(true);
    await _pointAnnotationManager?.setTextAllowOverlap(true);

    if (_tapHandlerAttached) {
      return;
    }
    _tapHandlerAttached = true;
    _pointAnnotationManager?.tapEvents(
      onTap: (annotation) {
        final itemId =
            annotation.customData?['itemId'] as String? ??
            _annotationItemIds[annotation.id];
        if (itemId == null) {
          return;
        }
        _selectItemById(itemId, animateCard: true);
      },
    );
  }

  Future<void> _refreshAnnotations() async {
    await _ensureAnnotationManager();
    final manager = _pointAnnotationManager;
    if (manager == null) {
      return;
    }

    await manager.deleteAll();
    _annotationItemIds.clear();

    final options = <PointAnnotationOptions>[];
    for (var index = 0; index < _mapItems.length; index++) {
      final item = _mapItems[index];
      final isSelected = index == _selectedIndex;
      options.add(
        PointAnnotationOptions(
          geometry: _pointForItem(item),
          image: await _pinImageFor(item, isSelected: isSelected),
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: isSelected ? 10 : 1,
          customData: {'itemId': item.id},
        ),
      );
    }

    final annotations = await manager.createMulti(options);
    for (var index = 0; index < annotations.length; index++) {
      final annotation = annotations[index];
      if (annotation != null) {
        _annotationItemIds[annotation.id] = _mapItems[index].id;
      }
    }
  }

  Future<Uint8List> _pinImageFor(
    MarketItem item, {
    required bool isSelected,
  }) async {
    final key = '${item.price}-$isSelected';
    final cached = _pinImageCache[key];
    if (cached != null) {
      return cached;
    }

    final bytes = await _drawPricePin('£${item.price}', isSelected);
    _pinImageCache[key] = bytes;
    return bytes;
  }

  Future<void> _fitAllPins() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || _didFitInitialCamera) {
      return;
    }
    _didFitInitialCamera = true;

    if (_mapItems.length == 1) {
      await _focusSelectedItem(zoom: 13.6);
      return;
    }

    final camera = await mapboxMap.cameraForCoordinatesPadding(
      _mapItems.map(_pointForItem).toList(growable: false),
      CameraOptions(pitch: 0, bearing: 0),
      MbxEdgeInsets(top: 112, left: 58, bottom: 260, right: 58),
      14.0,
      null,
    );
    await mapboxMap.setCamera(camera);
  }

  Future<void> _focusSelectedItem({double zoom = 13.2}) async {
    await _mapboxMap?.setCamera(
      CameraOptions(
        center: _pointForItem(_selectedItem),
        zoom: zoom,
        pitch: 0,
        bearing: 0,
      ),
    );
  }

  Future<void> _selectItemById(
    String itemId, {
    required bool animateCard,
  }) async {
    final index = _mapItems.indexWhere((item) => item.id == itemId);
    if (index == -1 || index == _selectedIndex) {
      return;
    }

    setState(() => _selectedIndex = index);
    await _focusSelectedItem();
    await _refreshAnnotations();

    if (animateCard && _cardController.hasClients) {
      await _cardController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _onCardChanged(int index) async {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
    await _focusSelectedItem();
    await _refreshAnnotations();
  }

  void _openDetail(MarketItem item) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => ProductDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_mapItems.isEmpty) {
      return AppPageScaffold(
        title: '地图查看',
        previousPageTitle: '搜索',
        child: AppBackdrop(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.map_pin_ellipse,
                      color: AppPalette.brand,
                      size: 38,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.ui('这些商品还没有发布位置'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.ui('发布商品时添加位置后，就能在地图上查看附近商品。'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AppPageScaffold(
      title: '地图查看',
      previousPageTitle: '搜索',
      child: AppBackdrop(
        child: Stack(
          children: [
            Positioned.fill(
              child: MapWidget(
                key: ValueKey('search-map-${_mapItems.length}'),
                // ignore: deprecated_member_use
                cameraOptions: _initialCamera,
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
            ),
            if (!_mapReady)
              Positioned.fill(
                child: Container(
                  color: AppPalette.backgroundCool,
                  alignment: Alignment.center,
                  child: const CupertinoActivityIndicator(radius: 13),
                ),
              ),
            if (_loadError != null)
              Positioned.fill(
                child: Container(
                  color: AppPalette.backgroundCool,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: AppSectionCard(
                    child: Text(
                      l10n.ui(_loadError!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            if (_loadError == null) ...[
              Positioned(
                top: 14,
                left: 20,
                right: 20,
                child: _MapHeaderOverlay(
                  queryLabel: widget.queryLabel,
                  itemCount: _mapItems.length,
                  selectedItem: _selectedItem,
                  onRecenter: _focusSelectedItem,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 154,
                    child: PageView.builder(
                      controller: _cardController,
                      itemCount: _mapItems.length,
                      onPageChanged: _onCardChanged,
                      itemBuilder: (context, index) {
                        final item = _mapItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _MapItemPreviewCard(
                            item: item,
                            isSelected: index == _selectedIndex,
                            onTap: () => _openDetail(item),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapHeaderOverlay extends StatelessWidget {
  const _MapHeaderOverlay({
    required this.queryLabel,
    required this.itemCount,
    required this.selectedItem,
    required this.onRecenter,
  });

  final String queryLabel;
  final int itemCount;
  final MarketItem selectedItem;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = queryLabel.trim().isEmpty
        ? '附近类似商品'
        : '${queryLabel.trim()} · 附近类似商品';

    return _MapGlassCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              CupertinoIcons.map_fill,
              color: AppPalette.mint,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.ui(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.text(
                    '$itemCount 件有位置 · 当前 £${selectedItem.price}',
                    '$itemCount with location · selected £${selectedItem.price}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onRecenter,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppPalette.brandLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppPalette.brand.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(
                CupertinoIcons.scope,
                color: AppPalette.brand,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapItemPreviewCard extends StatelessWidget {
  const _MapItemPreviewCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final MarketItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppPalette.brand.withValues(alpha: 0.42)
                : AppPalette.border.withValues(alpha: 0.78),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F1915),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 104,
                height: 108,
                child: _MapItemImage(item: item),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppTag(
                        label: '£${item.price}',
                        color: AppPalette.yellow,
                        textColor: AppPalette.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.distance > 0
                              ? '${item.distance.toStringAsFixed(1)}km'
                              : item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    l10n.listingText(item.title, item.titleEn),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${l10n.ui(item.condition)} · ${item.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppPalette.brand,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapItemImage extends StatelessWidget {
  const _MapItemImage({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrls.isEmpty ? null : item.imageUrls.first;
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _MapItemImageFallback(item: item);
        },
        errorBuilder: (context, error, stackTrace) {
          return _MapItemImageFallback(item: item);
        },
      );
    }
    return _MapItemImageFallback(item: item);
  }
}

class _MapItemImageFallback extends StatelessWidget {
  const _MapItemImageFallback({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.36)),
      child: Center(child: Icon(item.icon, color: AppPalette.ink, size: 36)),
    );
  }
}

class _MapGlassCard extends StatelessWidget {
  const _MapGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.52)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F1915),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

Point _pointForItem(MarketItem item) {
  return Point(coordinates: Position(item.longitude, item.latitude));
}

bool _hasValidLocation(MarketItem item) {
  final latitude = item.latitude;
  final longitude = item.longitude;
  final hasCoordinate = latitude.abs() > 0.0001 || longitude.abs() > 0.0001;
  return hasCoordinate &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

Future<Uint8List> _drawPricePin(String label, bool isSelected) async {
  final fontSize = isSelected ? 36.0 : 32.0;
  final bubbleHeight = isSelected ? 62.0 : 56.0;
  final horizontalPadding = isSelected ? 52.0 : 46.0;
  final minWidth = isSelected ? 112.0 : 102.0;
  final maxWidth = isSelected ? 196.0 : 184.0;
  final tailHalfWidth = isSelected ? 11.0 : 10.0;
  final tailHeight = isSelected ? 14.0 : 12.0;

  final textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: isSelected ? CupertinoColors.white : AppPalette.ink,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final logicalWidth = (textPainter.width + horizontalPadding).clamp(
    minWidth,
    maxWidth,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bubbleRect = Rect.fromLTWH(0, 0, logicalWidth, bubbleHeight);
  final bubble = RRect.fromRectAndRadius(
    bubbleRect.deflate(1.5),
    Radius.circular(isSelected ? 24 : 22),
  );
  final background = isSelected ? AppPalette.ink : CupertinoColors.white;
  final border = isSelected ? AppPalette.yellow : AppPalette.brand;

  final shadowPaint = Paint()
    ..color = const Color(0x300F1915)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
  canvas.drawRRect(bubble.shift(const Offset(0, 5)), shadowPaint);

  final fillPaint = Paint()..color = background;
  canvas.drawRRect(bubble, fillPaint);

  final tail = Path()
    ..moveTo(logicalWidth / 2 - tailHalfWidth, bubbleHeight - 4)
    ..lineTo(logicalWidth / 2, bubbleHeight + tailHeight)
    ..lineTo(logicalWidth / 2 + tailHalfWidth, bubbleHeight - 4)
    ..close();
  canvas.drawPath(tail, fillPaint);

  final strokePaint = Paint()
    ..color = border
    ..style = PaintingStyle.stroke
    ..strokeWidth = isSelected ? 5 : 4;
  canvas.drawRRect(bubble, strokePaint);
  canvas.drawPath(tail, strokePaint);

  textPainter.paint(
    canvas,
    Offset(
      (logicalWidth - textPainter.width) / 2,
      (bubbleHeight - textPainter.height) / 2 - 1,
    ),
  );

  final image = await recorder.endRecording().toImage(
    logicalWidth.ceil(),
    (bubbleHeight + tailHeight + 8).ceil(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
