import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/location_service.dart';
import '../../widgets/app_components.dart';

class PublishLocationPickerPage extends StatefulWidget {
  const PublishLocationPickerPage({
    super.key,
    required this.initialLocation,
    this.pageTitle = '选择发布地址',
    this.previousPageTitle = '商品信息',
    this.sectionTitle = '发布地址',
    this.sectionSubtitle = '买家会看到大致位置，方便同城交易',
    this.confirmLabel = '使用此地址',
    this.mapFallbackName = '地图选择位置',
    this.mapSelectedMessage = '已选择发布位置',
    this.mapTapInstruction = '移动地图，将中心点对准发布位置',
    this.geocodingLanguage = 'zh-Hans',
  });

  final AppLocation initialLocation;
  final String pageTitle;
  final String previousPageTitle;
  final String sectionTitle;
  final String sectionSubtitle;
  final String confirmLabel;
  final String mapFallbackName;
  final String mapSelectedMessage;
  final String mapTapInstruction;
  final String geocodingLanguage;

  @override
  State<PublishLocationPickerPage> createState() =>
      _PublishLocationPickerPageState();
}

class _PublishLocationPickerPageState extends State<PublishLocationPickerPage> {
  late AppLocation _selectedLocation;
  bool _isLocating = false;
  bool _isResolvingAddress = false;
  int _selectionVersion = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
      _message = null;
    });

    try {
      final l10n = context.l10n;
      final location = await LocationService.instance.getCurrentLocation(
        language: widget.geocodingLanguage,
        fallbackName: l10n.ui('当前位置'),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedLocation = location;
        _message = '已定位到当前位置';
      });
    } on LocationServiceException catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = '定位失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _selectMapCenter(double latitude, double longitude) async {
    final version = ++_selectionVersion;
    final l10n = context.l10n;
    final fallback = AppLocation(
      latitude: latitude,
      longitude: longitude,
      name: l10n.ui(widget.mapFallbackName),
      detail: '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
    );

    setState(() {
      _selectedLocation = fallback;
      _isResolvingAddress = true;
      _message = '正在识别中心位置...';
    });

    final resolved = await LocationService.instance.resolveCoordinates(
      latitude: latitude,
      longitude: longitude,
      fallbackName: l10n.ui(widget.mapFallbackName),
      language: widget.geocodingLanguage,
    );

    if (!mounted || version != _selectionVersion) {
      return;
    }
    setState(() {
      _selectedLocation = resolved;
      _isResolvingAddress = false;
      _message = widget.mapSelectedMessage;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: widget.pageTitle,
      previousPageTitle: widget.previousPageTitle,
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SelectedLocationCard(
              title: widget.sectionTitle,
              subtitle: widget.sectionSubtitle,
              location: _selectedLocation,
              isResolving: _isResolvingAddress,
              message: _message,
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 0.76,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _PublishLocationMap(
                  location: _selectedLocation,
                  onCenterSelected: _selectMapCenter,
                  tapInstruction: widget.mapTapInstruction,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: _isLocating ? '定位中' : 'GPS 定位',
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    leading: const Icon(
                      CupertinoIcons.scope,
                      color: AppPalette.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    label: widget.confirmLabel,
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({
    required this.title,
    required this.subtitle,
    required this.location,
    required this.isResolving,
    required this.message,
  });

  final String title;
  final String subtitle;
  final AppLocation location;
  final bool isResolving;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F1915),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionTitle(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppPalette.brandLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: isResolving
                    ? const CupertinoActivityIndicator(radius: 10)
                    : const Icon(
                        CupertinoIcons.location_solid,
                        color: AppPalette.brand,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ui(location.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.ui(location.detail),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppPalette.brandLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: AppPalette.brand,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.ui(message!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.brandDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublishLocationMap extends StatefulWidget {
  const _PublishLocationMap({
    required this.location,
    required this.onCenterSelected,
    required this.tapInstruction,
  });

  final AppLocation location;
  final Future<void> Function(double latitude, double longitude)
  onCenterSelected;
  final String tapInstruction;

  @override
  State<_PublishLocationMap> createState() => _PublishLocationMapState();
}

class _PublishLocationMapState extends State<_PublishLocationMap> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  String? _loadError;
  bool _isMoving = false;

  CameraOptions get _camera => CameraOptions(
    center: _pointForLocation(widget.location),
    zoom: 14.2,
    pitch: 28,
    bearing: -10,
  );

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(
      AttributionSettings(marginBottom: 10, marginRight: 10),
    );
    await mapboxMap.setCamera(_camera);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (mounted) {
      setState(() {
        _mapReady = true;
        _loadError = null;
      });
    }
  }

  void _onCameraChanged(CameraChangedEventData _) {
    if (!_isMoving && mounted) {
      setState(() => _isMoving = true);
    }
  }

  Future<void> _onMapIdle(MapIdleEventData _) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    final cameraState = await mapboxMap.getCameraState();
    final coordinates = cameraState.center.coordinates;
    final latitude = coordinates.lat.toDouble();
    final longitude = coordinates.lng.toDouble();
    if (!mounted) {
      return;
    }

    setState(() => _isMoving = false);
    if (_isSamePoint(latitude, longitude, widget.location)) {
      return;
    }
    await widget.onCenterSelected(latitude, longitude);
  }

  void _onMapLoadError(MapLoadingErrorEventData event) {
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

  Future<void> _recenter() async {
    await _mapboxMap?.setCamera(_camera);
  }

  @override
  void didUpdateWidget(covariant _PublishLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      _mapboxMap?.setCamera(_camera);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('publish-location-map'),
          // ignore: deprecated_member_use
          cameraOptions: _camera,
          styleUri: MapboxStyles.LIGHT,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          onCameraChangeListener: _onCameraChanged,
          onMapIdleListener: _onMapIdle,
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
            child: _MapMessageCard(message: _loadError!),
          ),
        if (_loadError == null)
          Center(child: _CenterLocationPin(isMoving: _isMoving)),
        if (_loadError == null)
          Positioned(
            top: 14,
            left: 14,
            child: _MapGlassCard(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.hand_draw_fill,
                    color: AppPalette.brand,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.l10n.ui(widget.tapInstruction),
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_loadError == null)
          Positioned(
            right: 14,
            bottom: 14,
            child: _FloatingMapButton(
              icon: CupertinoIcons.location,
              onPressed: _recenter,
            ),
          ),
      ],
    );
  }

  bool _isSamePoint(double latitude, double longitude, AppLocation location) {
    return (latitude - location.latitude).abs() < 0.00001 &&
        (longitude - location.longitude).abs() < 0.00001;
  }
}

class _CenterLocationPin extends StatelessWidget {
  const _CenterLocationPin({required this.isMoving});

  final bool isMoving;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, isMoving ? -8 : -4, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppPalette.ink,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: AppPalette.yellow, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F1915),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.location_solid,
                color: AppPalette.mint,
                size: 24,
              ),
            ),
            Container(
              width: 16,
              height: 6,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: AppPalette.ink.withValues(alpha: isMoving ? 0.14 : 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
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
        child: Icon(icon, color: AppPalette.brand, size: 24),
      ),
    );
  }
}

class _MapGlassCard extends StatelessWidget {
  const _MapGlassCard({required this.child});

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

class _MapMessageCard extends StatelessWidget {
  const _MapMessageCard({required this.message});

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

Point _pointForLocation(AppLocation location) {
  return Point(coordinates: Position(location.longitude, location.latitude));
}
