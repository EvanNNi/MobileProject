import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../models/market_item.dart';
import '../../services/listing_engagement_repository.dart';
import '../../services/market_listing_repository.dart';
import '../../widgets/app_components.dart';
import 'market_widgets.dart';
import 'product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Future<void> _removeFavorite(MarketItem item) async {
    await ListingEngagementRepository.instance.toggleFavorite(item);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: ListingEngagementRepository.instance.watchFavoriteListingIds(),
      builder: (context, favoriteSnapshot) {
        final favoriteIds = favoriteSnapshot.data;
        final isLoadingFavorites =
            favoriteSnapshot.connectionState == ConnectionState.waiting &&
            !favoriteSnapshot.hasData;

        return StreamBuilder<List<MarketItem>>(
          stream: MarketListingRepository.instance.watchActiveListings(),
          builder: (context, listingSnapshot) {
            final resolvedFavoriteIds = favoriteIds ?? <String>{};
            final items = (listingSnapshot.data ?? const <MarketItem>[])
                .where((item) => resolvedFavoriteIds.contains(item.id))
                .map((item) => item.copyWith(isFavorite: true))
                .toList();
            final isLoadingListings =
                listingSnapshot.connectionState == ConnectionState.waiting &&
                resolvedFavoriteIds.isNotEmpty &&
                items.isEmpty;

            return AppPageScaffold(
              title: '收藏夹',
              previousPageTitle: '首页',
              child: AppBackdrop(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    AppSectionCard(
                      child: Row(
                        children: [
                          const Expanded(
                            child: AppSectionTitle(
                              title: '我的收藏',
                              subtitle: '关注价格变化和卖家动态',
                            ),
                          ),
                          AppTag(
                            label: isLoadingFavorites
                                ? '同步中'
                                : '${items.length} 件',
                            icon: CupertinoIcons.heart_fill,
                            color: AppPalette.yellow,
                            textColor: AppPalette.ink,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (isLoadingFavorites || isLoadingListings)
                      const AppSectionCard(
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        ),
                      )
                    else if (favoriteSnapshot.hasError)
                      AppSectionCard(
                        child: AppSectionTitle(
                          title: '收藏加载失败',
                          subtitle: '${favoriteSnapshot.error}',
                        ),
                      )
                    else if (listingSnapshot.hasError)
                      AppSectionCard(
                        child: AppSectionTitle(
                          title: '收藏加载失败',
                          subtitle: '${listingSnapshot.error}',
                        ),
                      )
                    else if (items.isEmpty)
                      const AppSectionCard(
                        child: Center(
                          child: Text(
                            '还没有收藏商品',
                            style: TextStyle(color: AppPalette.mutedText),
                          ),
                        ),
                      )
                    else
                      for (final item in items) ...[
                        MarketListItem(
                          item: item,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => ProductDetailPage(item: item),
                              ),
                            );
                          },
                          onFavoriteTap: () => _removeFavorite(item),
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
