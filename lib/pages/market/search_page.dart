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
import 'search_results_map_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.items,
    this.initialQuery = '',
    this.origin,
  });

  final List<MarketItem>? items;
  final String initialQuery;
  final BrowseLocation? origin;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _searchController;
  MarketFilter _filter = const MarketFilter();
  bool _hasAppliedFilter = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MarketItem> _results(
    List<MarketItem> items,
    Set<String> favoriteListingIds,
    AppLocalizations l10n,
  ) {
    final query = _searchController.text.trim().toLowerCase();
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
          final searchableValues = [
            item.title,
            item.titleEn,
            l10n.ui(item.title),
            item.description,
            item.descriptionEn,
            l10n.ui(item.description),
            item.category,
            l10n.ui(item.category),
            item.brand,
            item.model,
            item.condition,
            l10n.ui(item.condition),
          ];
          final queryMatches =
              query.isEmpty ||
              searchableValues.any(
                (value) => value.toLowerCase().contains(query),
              );
          final priceMatches =
              !_hasAppliedFilter || _filter.matchesPrice(item.price);
          final distanceMatches =
              !_hasAppliedFilter ||
              widget.origin == null ||
              item.distance <= _filter.distance;
          final conditionMatches =
              !_hasAppliedFilter ||
              _filter.condition == '全部' ||
              item.condition == _filter.condition;
          final brandMatches =
              !_hasAppliedFilter ||
              _filter.brand == '全部' ||
              item.brand == _filter.brand;
          return queryMatches &&
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
        _hasAppliedFilter = true;
      });
    }
  }

  void _setQuery(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    setState(() {});
  }

  Stream<List<MarketItem>> _watchSearchItems() {
    final suppliedItems = widget.items;
    if (suppliedItems == null || suppliedItems.isEmpty) {
      return MarketListingRepository.instance.watchActiveListings();
    }

    return Stream<List<MarketItem>>.value(suppliedItems);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return StreamBuilder<Set<String>>(
      stream: ListingEngagementRepository.instance.watchFavoriteListingIds(),
      builder: (context, favoriteSnapshot) {
        final favoriteListingIds = favoriteSnapshot.data ?? <String>{};

        return StreamBuilder<List<MarketItem>>(
          stream: _watchSearchItems(),
          builder: (context, listingSnapshot) {
            final sourceItems = listingSnapshot.data ?? const <MarketItem>[];
            final query = _searchController.text.trim();
            final hasSearchIntent = query.isNotEmpty || _hasAppliedFilter;
            final results = hasSearchIntent
                ? _results(sourceItems, favoriteListingIds, l10n)
                : const <MarketItem>[];
            final isLoading =
                listingSnapshot.connectionState == ConnectionState.waiting &&
                sourceItems.isEmpty;

            return AppPageScaffold(
              title: '搜索',
              previousPageTitle: '首页',
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _openFilter,
                child: const Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: AppPalette.brand,
                  size: 23,
                ),
              ),
              child: AppBackdrop(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    CupertinoTextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      placeholder: l10n.ui('搜索商品、品牌、型号'),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Icon(
                          CupertinoIcons.search,
                          color: AppPalette.mutedText,
                          size: 20,
                        ),
                      ),
                      suffix: query.isEmpty
                          ? null
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () => _setQuery(''),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  color: AppPalette.mutedText,
                                  size: 20,
                                ),
                              ),
                            ),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceWarm,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppPalette.border.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in const ['耳机', '相机', '显示器', '球鞋'])
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () => _setQuery(l10n.ui(tag)),
                            child: AppTag(label: tag),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppSectionTitle(
                      title: hasSearchIntent
                          ? _hasAppliedFilter && query.isEmpty
                                ? '筛选结果'
                                : '搜索结果'
                          : '开始搜索',
                      subtitle: !hasSearchIntent
                          ? '输入关键词，或点上方标签快速搜索。'
                          : isLoading
                          ? '正在同步最新商品'
                          : '${results.length} 件匹配商品',
                    ),
                    const SizedBox(height: 16),
                    if (!hasSearchIntent)
                      const _SearchIdleState()
                    else if (isLoading)
                      const AppSectionCard(
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        ),
                      )
                    else if (results.isEmpty)
                      AppSectionCard(
                        child: Center(
                          child: Text(
                            l10n.ui('没有找到匹配商品'),
                            style: const TextStyle(color: AppPalette.mutedText),
                          ),
                        ),
                      )
                    else
                      _MapResultsButton(items: results, queryLabel: query),
                    if (hasSearchIntent && !isLoading && results.isNotEmpty)
                      const SizedBox(height: 12),
                    if (hasSearchIntent && !isLoading && results.isNotEmpty)
                      for (final item in results) ...[
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

class _MapResultsButton extends StatelessWidget {
  const _MapResultsButton({required this.items, required this.queryLabel});

  final List<MarketItem> items;
  final String queryLabel;

  @override
  Widget build(BuildContext context) {
    final locatedCount = items.where(_hasMapLocation).length;
    final enabled = locatedCount > 0;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled
          ? () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SearchResultsMapPage(
                    items: items,
                    queryLabel: queryLabel,
                  ),
                ),
              );
            }
          : null,
      child: AppSectionCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enabled
                    ? AppPalette.ink
                    : AppPalette.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                CupertinoIcons.map_fill,
                color: enabled ? AppPalette.mint : AppPalette.mutedText,
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.ui('在地图上查看'),
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    enabled
                        ? context.l10n.text(
                            '$locatedCount 件商品有位置，查看价格和主图',
                            '$locatedCount items have a location. View price and photo.',
                          )
                        : context.l10n.ui('这些商品还没有发布位置'),
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              color: enabled ? AppPalette.brand : AppPalette.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasMapLocation(MarketItem item) {
  final hasCoordinate =
      item.latitude.abs() > 0.0001 || item.longitude.abs() > 0.0001;
  return hasCoordinate &&
      item.latitude >= -90 &&
      item.latitude <= 90 &&
      item.longitude >= -180 &&
      item.longitude <= 180;
}

class _SearchIdleState extends StatelessWidget {
  const _SearchIdleState();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppPalette.brandLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              CupertinoIcons.search,
              color: AppPalette.brand,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.ui('还没有输入搜索内容'),
            style: const TextStyle(
              color: AppPalette.strongText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.ui('搜索商品名、品牌、型号，或直接点击上方标签。'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
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
