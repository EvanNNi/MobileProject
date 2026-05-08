import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../services/browse_location_repository.dart';
import '../../services/listing_engagement_repository.dart';
import '../../services/market_listing_repository.dart';
import '../../widgets/app_components.dart';
import 'market_filter_sheet.dart';
import 'market_widgets.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    this.items,
    this.initialCategory = '推荐',
    this.origin,
  });

  final List<MarketItem>? items;
  final String initialCategory;
  final BrowseLocation? origin;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late String _selectedCategory;
  MarketFilter _filter = const MarketFilter();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  List<MarketItem> _visibleItems(
    List<MarketItem> items,
    Set<String> favoriteListingIds,
  ) {
    return items
        .map((item) {
          final origin = widget.origin;
          final distance = origin == null
              ? item.distance
              : _distanceInKm(
                  origin.latitude,
                  origin.longitude,
                  item.latitude,
                  item.longitude,
                );
          return item.copyWith(
            isFavorite: favoriteListingIds.contains(item.id),
            distance: distance,
          );
        })
        .where((item) {
          final categoryMatches =
              _selectedCategory == '推荐' || item.category == _selectedCategory;
          final priceMatches = _filter.matchesPrice(item.price);
          final distanceMatches =
              widget.origin == null || item.distance <= _filter.distance;
          final conditionMatches =
              _filter.condition == '全部' || item.condition == _filter.condition;
          final brandMatches =
              _filter.brand == '全部' || item.brand == _filter.brand;
          return categoryMatches &&
              priceMatches &&
              distanceMatches &&
              conditionMatches &&
              brandMatches;
        })
        .toList();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return StreamBuilder<Set<String>>(
      stream: ListingEngagementRepository.instance.watchFavoriteListingIds(),
      builder: (context, favoriteSnapshot) {
        final favoriteListingIds = favoriteSnapshot.data ?? <String>{};

        return StreamBuilder<List<MarketItem>>(
          stream: widget.items == null
              ? MarketListingRepository.instance.watchActiveListings()
              : Stream<List<MarketItem>>.value(widget.items!),
          builder: (context, listingSnapshot) {
            final sourceItems = listingSnapshot.data ?? const <MarketItem>[];
            final visibleItems = _visibleItems(sourceItems, favoriteListingIds);

            return AppPageScaffold(
              title: '分类',
              previousPageTitle: '首页',
              child: AppBackdrop(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    MarketSearchBar(
                      placeholder: '搜索当前分类',
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => SearchPage(
                              initialQuery: _selectedCategory == '推荐'
                                  ? ''
                                  : _selectedCategory,
                              origin: widget.origin,
                            ),
                          ),
                        );
                      },
                      onFilterTap: _openFilter,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: marketCategories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = marketCategories[index];
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            child: AppTag(
                              label: category,
                              color: category == _selectedCategory
                                  ? AppPalette.yellow
                                  : AppPalette.brandLight,
                              textColor: AppPalette.ink,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AppSectionTitle(
                            title: _selectedCategory,
                            subtitle:
                                listingSnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    sourceItems.isEmpty
                                ? '正在同步最新商品'
                                : '筛选后 ${visibleItems.length} 件商品',
                          ),
                        ),
                        const AppTag(
                          label: '附近优先',
                          icon: CupertinoIcons.location_solid,
                          color: AppPalette.mint,
                          textColor: AppPalette.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (listingSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        sourceItems.isEmpty)
                      const AppSectionCard(
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        ),
                      )
                    else if (visibleItems.isEmpty)
                      AppSectionCard(
                        child: Center(
                          child: Text(
                            l10n.ui('当前分类暂无商品'),
                            style: const TextStyle(color: AppPalette.mutedText),
                          ),
                        ),
                      )
                    else
                      for (final item in visibleItems) ...[
                        MarketListItem(
                          item: item,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => ProductDetailPage(item: item),
                              ),
                            );
                          },
                          onFavoriteTap: () => _toggleFavorite(item),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
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
