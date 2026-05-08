import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../services/browse_location_repository.dart';
import '../../services/chat_repository.dart';
import '../../services/listing_engagement_repository.dart';
import '../../services/location_service.dart';
import '../../services/market_filter_preferences.dart';
import '../../services/market_listing_repository.dart';
import '../../widgets/app_components.dart';
import '../chat/conversations_page.dart';
import '../profile/profile_page.dart';
import '../publish/publish_entry_page.dart';
import '../publish/publish_location_picker_page.dart';
import 'market_filter_sheet.dart';
import 'market_widgets.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

class MarketHomePage extends StatefulWidget {
  const MarketHomePage({super.key});

  @override
  State<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends State<MarketHomePage> {
  MarketFilter _filter = const MarketFilter();
  BrowseLocation _selectedLocation = const BrowseLocation.pending();
  bool _isLocating = false;
  bool _hasLoadedSavedFilter = false;
  bool _hasSelectedLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useCurrentLocation(showErrors: false);
    });
  }

  Future<void> _loadSavedFilter() async {
    final savedFilter = await MarketFilterPreferences.instance.loadHomeFilter();
    if (!mounted) {
      return;
    }

    setState(() {
      _filter = savedFilter;
      _hasLoadedSavedFilter = true;
    });
  }

  List<MarketItem> _itemsAroundLocation(
    List<MarketItem> items,
    Set<String> favoriteListingIds,
    BrowseLocation origin,
  ) {
    final itemsAroundLocation = items
        .map(
          (item) => item.copyWith(
            distance: _distanceInKm(
              origin.latitude,
              origin.longitude,
              item.latitude,
              item.longitude,
            ),
            isFavorite: favoriteListingIds.contains(item.id),
          ),
        )
        .toList();

    return itemsAroundLocation
      ..sort((a, b) => a.distance.compareTo(b.distance));
  }

  List<MarketItem> _filteredItems(
    List<MarketItem> items,
    Set<String> favoriteListingIds,
    BrowseLocation origin,
  ) {
    final itemsAroundLocation = _itemsAroundLocation(
      items,
      favoriteListingIds,
      origin,
    );

    final filtered = itemsAroundLocation.where((item) {
      final priceMatches = _filter.matchesPrice(item.price);
      final distanceMatches = item.distance <= _filter.distance;
      final conditionMatches =
          _filter.condition == '全部' || item.condition == _filter.condition;
      final brandMatches = _filter.brand == '全部' || item.brand == _filter.brand;
      return priceMatches &&
          distanceMatches &&
          conditionMatches &&
          brandMatches;
    }).toList();

    return filtered..sort((a, b) => a.distance.compareTo(b.distance));
  }

  Future<void> _toggleFavorite(MarketItem item) async {
    await ListingEngagementRepository.instance.toggleFavorite(item);
  }

  Future<void> _openFilter() async {
    final filter = await showMarketFilterSheet(context, initialFilter: _filter);
    if (filter != null) {
      setState(() {
        _filter = filter;
      });
      await MarketFilterPreferences.instance.saveHomeFilter(filter);
    }
  }

  void _openDetail(MarketItem item) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => ProductDetailPage(item: item)),
    );
  }

  BrowseLocation _effectiveLocation(List<BrowseLocation> savedLocations) {
    if (_hasSelectedLocation) {
      return _selectedLocation;
    }
    if (savedLocations.isNotEmpty) {
      return savedLocations.first;
    }
    return _selectedLocation;
  }

  Future<void> _openLocationPicker(List<BrowseLocation> savedLocations) async {
    final selectedLocation = _effectiveLocation(savedLocations);
    final result = await showCupertinoModalPopup<_LocationPickerResult>(
      context: context,
      builder: (context) => _LocationPickerSheet(
        selectedLocation: selectedLocation,
        locations: savedLocations,
      ),
    );

    if (result == null) {
      return;
    }

    if (result.useCurrentLocation) {
      await _useCurrentLocation();
      return;
    }

    if (result.chooseOnMap) {
      await _chooseBrowsingLocationOnMap(selectedLocation);
      return;
    }

    final location = result.location;
    if (location != null) {
      setState(() {
        _selectedLocation = location;
        _hasSelectedLocation = true;
        _locationError = null;
      });
      unawaited(
        BrowseLocationRepository.instance
            .touchLocation(location.id)
            .catchError((_) {}),
      );
    }
  }

  Future<void> _chooseBrowsingLocationOnMap(
    BrowseLocation selectedLocation,
  ) async {
    final pickedLocation = await Navigator.of(context).push<AppLocation>(
      CupertinoPageRoute<AppLocation>(
        builder: (_) => PublishLocationPickerPage(
          initialLocation: _appLocationForBrowsing(selectedLocation),
          pageTitle: '选择浏览位置',
          previousPageTitle: '首页',
          sectionTitle: '浏览位置',
          sectionSubtitle: '选择后首页会展示该位置附近的商品',
          confirmLabel: '使用此位置',
          mapFallbackName: '地图选择位置',
          mapSelectedMessage: '已选择浏览位置',
          mapTapInstruction: '移动地图，将中心点对准浏览位置',
          geocodingLanguage: _geocodingLanguage(context),
        ),
      ),
    );

    if (!mounted || pickedLocation == null) {
      return;
    }

    final browseLocation = BrowseLocation.fromCurrentLocation(pickedLocation);
    setState(() {
      _selectedLocation = browseLocation;
      _hasSelectedLocation = true;
      _locationError = null;
    });
    unawaited(_saveBrowsingLocation(pickedLocation));
  }

  Future<void> _saveBrowsingLocation(AppLocation location) async {
    try {
      await BrowseLocationRepository.instance.saveLocation(location);
    } catch (_) {
      // Saving a map-picked browsing location should not block browsing.
    }
  }

  AppLocation _appLocationForBrowsing(BrowseLocation location) {
    if (location.latitude != 0 || location.longitude != 0) {
      return AppLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        name: location.name,
        detail: location.detail,
      );
    }

    return const AppLocation(
      latitude: 51.5074,
      longitude: -0.1278,
      name: 'London',
      detail: 'London, UK',
    );
  }

  Future<void> _useCurrentLocation({bool showErrors = true}) async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final location = await LocationService.instance.getCurrentLocation(
        language: _geocodingLanguage(context),
        fallbackName: context.l10n.ui('当前位置'),
      );
      if (!mounted) {
        return;
      }

      final browseLocation = BrowseLocation.fromCurrentLocation(location);
      setState(() {
        _selectedLocation = browseLocation;
        _hasSelectedLocation = true;
        _isLocating = false;
        _locationError = null;
      });
      unawaited(_saveCurrentLocation(location));
    } on LocationServiceException catch (error) {
      _handleLocationError(error.message, showErrors: showErrors);
    } catch (_) {
      _handleLocationError('定位失败，请稍后再试', showErrors: showErrors);
    }
  }

  Future<void> _saveCurrentLocation(AppLocation location) async {
    try {
      await BrowseLocationRepository.instance.saveCurrentLocation(location);
    } catch (_) {
      // Location persistence should not block using the app with GPS.
    }
  }

  void _handleLocationError(String message, {required bool showErrors}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocating = false;
      _locationError = message;
    });

    if (showErrors) {
      _showLocationError(message);
    }
  }

  Future<void> _showLocationError(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui('无法获取当前位置')),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ui('知道了')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<List<BrowseLocation>>(
      stream: BrowseLocationRepository.instance.watchLocations(),
      builder: (context, locationSnapshot) {
        final savedLocations =
            locationSnapshot.data ?? const <BrowseLocation>[];
        final effectiveLocation = _effectiveLocation(savedLocations);
        final hasBrowsingLocation =
            _hasSelectedLocation || savedLocations.isNotEmpty;
        final locationSubtitle = _locationError != null && !hasBrowsingLocation
            ? _locationError!
            : l10n.text(
                '${effectiveLocation.name} 周边 · 可在筛选中调整距离',
                'Around ${effectiveLocation.name} · adjust distance in filters',
              );
        final searchPlaceholder = _isLocating && !hasBrowsingLocation
            ? l10n.text('正在获取当前位置', 'Getting current location')
            : l10n.text(
                '搜索${effectiveLocation.name}附近商品',
                'Search near ${effectiveLocation.name}',
              );

        return StreamBuilder<Set<String>>(
          stream: ListingEngagementRepository.instance
              .watchFavoriteListingIds(),
          builder: (context, favoriteSnapshot) {
            final favoriteListingIds = favoriteSnapshot.data ?? <String>{};

            return StreamBuilder<List<MarketItem>>(
              stream: MarketListingRepository.instance.watchActiveListings(),
              builder: (context, snapshot) {
                final sourceItems = snapshot.data ?? const <MarketItem>[];
                final displayedItems = hasBrowsingLocation
                    ? _filteredItems(
                        sourceItems,
                        favoriteListingIds,
                        effectiveLocation,
                      )
                    : const <MarketItem>[];
                final isLoadingListings =
                    !_hasLoadedSavedFilter ||
                    _isLocating && !hasBrowsingLocation ||
                    snapshot.connectionState == ConnectionState.waiting &&
                        sourceItems.isEmpty;
                final listingError = snapshot.hasError;
                final marketSubtitle = listingError
                    ? l10n.text(
                        '商品加载失败，请检查网络后重试',
                        'Could not load items. Check your connection and retry.',
                      )
                    : locationSubtitle;

                return CupertinoPageScaffold(
                  backgroundColor: AppPalette.background,
                  child: AppBackdrop(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                28,
                              ),
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _LocationButton(
                                      location: effectiveLocation,
                                      isLocating:
                                          _isLocating && !hasBrowsingLocation,
                                      onTap: () =>
                                          _openLocationPicker(savedLocations),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: MarketSearchBar(
                                        placeholder: searchPlaceholder,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            CupertinoPageRoute<void>(
                                              builder: (_) => SearchPage(
                                                origin: hasBrowsingLocation
                                                    ? effectiveLocation
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                        onFilterTap: _openFilter,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppSectionTitle(
                                        title: '附近发布',
                                        subtitle: marketSubtitle,
                                      ),
                                    ),
                                    AppTag(
                                      label: isLoadingListings
                                          ? '同步中'
                                          : '${displayedItems.length} 件',
                                      color: AppPalette.brandLight,
                                      textColor: AppPalette.brandDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (isLoadingListings)
                                  const AppSectionCard(
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 13,
                                      ),
                                    ),
                                  )
                                else if (listingError)
                                  AppSectionCard(
                                    child: AppSectionTitle(
                                      title: '暂时无法读取商品',
                                      subtitle: '${snapshot.error}',
                                    ),
                                  )
                                else if (!hasBrowsingLocation)
                                  const AppSectionCard(
                                    child: AppSectionTitle(
                                      title: '请先选择浏览位置',
                                      subtitle: '选择当前位置后，会保存为常用浏览位置。',
                                    ),
                                  )
                                else if (displayedItems.isEmpty)
                                  AppSectionCard(
                                    child: AppSectionTitle(
                                      title: '附近暂时没有商品',
                                      subtitle: sourceItems.isEmpty
                                          ? '附近还没有人发布商品，稍后再来看看。'
                                          : '可以更换浏览位置，或放宽右侧筛选条件再看看。',
                                    ),
                                  )
                                else
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: displayedItems.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.62,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 20,
                                        ),
                                    itemBuilder: (context, index) {
                                      final item = displayedItems[index];
                                      return MarketProductCard(
                                        item: item,
                                        onTap: () => _openDetail(item),
                                        onFavoriteTap: () =>
                                            _toggleFavorite(item),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          StreamBuilder(
                            stream: ChatRepository.instance
                                .watchConversations(),
                            builder: (context, conversationSnapshot) {
                              final hasUnread =
                                  (conversationSnapshot.data ?? const []).any((
                                    conversation,
                                  ) {
                                    return conversation.unreadCount > 0;
                                  });
                              return _MarketBottomNavBar(
                                showInboxDot: hasUnread,
                                onSearch: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (_) => SearchPage(
                                        origin: hasBrowsingLocation
                                            ? effectiveLocation
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                onSell: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (_) => const PublishEntryPage(),
                                    ),
                                  );
                                },
                                onInbox: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (_) => const ConversationsPage(),
                                    ),
                                  );
                                },
                                onProfile: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute<void>(
                                      builder: (_) => const ProfilePage(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

String _geocodingLanguage(BuildContext context) {
  return context.l10n.isEnglish ? 'en' : 'zh-Hans';
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({
    required this.location,
    required this.isLocating,
    required this.onTap,
  });

  final BrowseLocation location;
  final bool isLocating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: 104,
        height: 50,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppPalette.border.withValues(alpha: 0.85)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (isLocating)
              const CupertinoActivityIndicator(radius: 9)
            else
              const Icon(
                CupertinoIcons.location_fill,
                color: AppPalette.brand,
                size: 19,
              ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                isLocating
                    ? context.l10n.ui('定位中')
                    : context.l10n.ui(location.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.brandDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              CupertinoIcons.chevron_down,
              color: AppPalette.mutedText,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({
    required this.selectedLocation,
    required this.locations,
  });

  final BrowseLocation selectedLocation;
  final List<BrowseLocation> locations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: Container(
          color: AppPalette.surface,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: AppSectionTitle(
                      title: '选择浏览位置',
                      subtitle: '像外卖软件一样，先选位置，再看附近发布的商品。',
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppPalette.mutedText,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(
                  context,
                ).pop(const _LocationPickerResult.useCurrentLocation()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppPalette.brand,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.brand.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_solid,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.ui('使用当前定位'),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(
                  context,
                ).pop(const _LocationPickerResult.chooseOnMap()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceWarm,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppPalette.brand.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.map,
                        color: AppPalette.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.ui('在地图上选择位置'),
                        style: const TextStyle(
                          color: AppPalette.brandDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        CupertinoIcons.chevron_forward,
                        color: AppPalette.mutedText,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.ui('常用位置'),
                style: const TextStyle(
                  color: AppPalette.strongText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (locations.isEmpty)
                const AppSectionCard(
                  child: AppSectionTitle(
                    title: '暂无常用位置',
                    subtitle: '点击上方“使用当前定位”后，会自动保存为常用位置。',
                  ),
                )
              else
                for (final location in locations) ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_LocationPickerResult.location(location)),
                    child: _LocationOptionRow(
                      location: location,
                      selected: location.id == selectedLocation.id,
                    ),
                  ),
                  if (location != locations.last) const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationOptionRow extends StatelessWidget {
  const _LocationOptionRow({required this.location, required this.selected});

  final BrowseLocation location;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppPalette.brandLight : AppPalette.surfaceWarm,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected
              ? AppPalette.brand.withValues(alpha: 0.24)
              : AppPalette.border.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? AppPalette.brand : AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              selected
                  ? CupertinoIcons.check_mark
                  : CupertinoIcons.location_solid,
              color: selected ? CupertinoColors.white : AppPalette.brand,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.ui(location.name),
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.ui(location.detail),
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
            CupertinoIcons.chevron_forward,
            color: AppPalette.mutedText,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _MarketBottomNavBar extends StatelessWidget {
  const _MarketBottomNavBar({
    required this.showInboxDot,
    required this.onSearch,
    required this.onSell,
    required this.onInbox,
    required this.onProfile,
  });

  final bool showInboxDot;
  final VoidCallback onSearch;
  final VoidCallback onSell;
  final VoidCallback onInbox;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: AppPalette.border.withValues(alpha: 0.85)),
          ),
        ),
        child: Row(
          children: [
            const _BottomNavItem(
              icon: CupertinoIcons.house_fill,
              label: '首页',
              active: true,
            ),
            _BottomNavItem(
              icon: CupertinoIcons.search,
              label: '搜索',
              onTap: onSearch,
            ),
            _BottomNavItem(
              icon: CupertinoIcons.plus_circle,
              label: '卖闲置',
              onTap: onSell,
              prominent: true,
            ),
            _BottomNavItem(
              icon: CupertinoIcons.envelope,
              label: '消息',
              onTap: onInbox,
              showDot: showInboxDot,
            ),
            _BottomNavItem(
              icon: CupertinoIcons.person,
              label: '我的',
              onTap: onProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.prominent = false,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool prominent;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppPalette.brand : AppPalette.mutedText;

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: prominent ? AppPalette.strongText : color,
                  size: prominent ? 31 : 27,
                ),
                if (showDot)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppPalette.warmAccent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.ui(label),
              style: TextStyle(
                color: active ? AppPalette.brand : AppPalette.mutedText,
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPickerResult {
  const _LocationPickerResult.location(this.location)
    : useCurrentLocation = false,
      chooseOnMap = false;

  const _LocationPickerResult.useCurrentLocation()
    : location = null,
      useCurrentLocation = true,
      chooseOnMap = false;

  const _LocationPickerResult.chooseOnMap()
    : location = null,
      useCurrentLocation = false,
      chooseOnMap = true;

  final BrowseLocation? location;
  final bool useCurrentLocation;
  final bool chooseOnMap;
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
