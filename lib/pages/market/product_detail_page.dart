import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_models.dart';
import '../../models/market_item.dart';
import '../../services/auth_service.dart';
import '../../services/listing_engagement_repository.dart';
import '../../services/market_listing_repository.dart';
import '../../widgets/app_components.dart';
import '../chat/chat_thread_page.dart';
import '../profile/my_listings_page.dart';
import 'listing_location_map_page.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.item});

  final MarketItem item;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ListingEngagementRepository.instance
          .recordView(widget.item)
          .catchError((_) {}),
    );
  }

  Future<void> _toggleFavorite(MarketItem item) async {
    try {
      await ListingEngagementRepository.instance.toggleFavorite(item);
    } catch (error) {
      await _showActionError('收藏失败', error);
    }
  }

  Future<void> _toggleLike(MarketItem item) async {
    try {
      await ListingEngagementRepository.instance.toggleLike(item);
    } catch (error) {
      await _showActionError('点赞失败', error);
    }
  }

  Future<void> _showActionError(String title, Object error) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui(title)),
        content: Text(authErrorMessage(error)),
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
    return StreamBuilder<MarketItem?>(
      stream: MarketListingRepository.instance.watchListing(widget.item.id),
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data ?? widget.item;
        return StreamBuilder<bool>(
          stream: ListingEngagementRepository.instance.watchIsFavorite(item.id),
          builder: (context, favoriteSnapshot) {
            final favoriteItem = item.copyWith(
              isFavorite: favoriteSnapshot.data ?? item.isFavorite,
            );
            return StreamBuilder<bool>(
              stream: ListingEngagementRepository.instance.watchIsLiked(
                item.id,
              ),
              builder: (context, likedSnapshot) {
                return _ProductDetailContent(
                  item: favoriteItem,
                  isLiked: likedSnapshot.data ?? false,
                  isOwnListing:
                      favoriteItem.sellerId ==
                      AuthService.instance.currentUser?.uid,
                  onFavorite: () => _toggleFavorite(favoriteItem),
                  onLike: () => _toggleLike(favoriteItem),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProductDetailContent extends StatelessWidget {
  const _ProductDetailContent({
    required this.item,
    required this.isLiked,
    required this.isOwnListing,
    required this.onFavorite,
    required this.onLike,
  });

  final MarketItem item;
  final bool isLiked;
  final bool isOwnListing;
  final VoidCallback onFavorite;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: AppBackdrop(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeroPhoto(
              item: item,
              onBack: () => Navigator.of(context).maybePop(),
              onFavorite: onFavorite,
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppTag(label: item.category),
                            AppTag(label: item.condition),
                            AppTag(
                              label: '${item.distance.toStringAsFixed(1)}km',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.listingText(item.title, item.titleEn),
                          style: const TextStyle(
                            color: AppPalette.strongText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '£${item.price}',
                              style: const TextStyle(
                                color: AppPalette.brand,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            _IconStat(
                              icon: CupertinoIcons.eye,
                              label: '${item.views}',
                            ),
                            const SizedBox(width: 12),
                            _IconStat(
                              icon: CupertinoIcons.heart,
                              label: '${item.likes}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: '商品信息',
                          subtitle: '品牌、型号、位置',
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(label: '品牌', value: item.brand),
                        const SizedBox(height: 12),
                        _DetailRow(label: '型号', value: item.model),
                        const SizedBox(height: 12),
                        _DetailRow(label: '卖家', value: item.seller),
                        const SizedBox(height: 12),
                        _DetailRow(label: '位置', value: item.location),
                        const SizedBox(height: 18),
                        Text(
                          context.l10n.listingText(
                            item.description,
                            item.descriptionEn,
                          ),
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AppSecondaryButton(
                          label: '查看发布地点',
                          onPressed: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) =>
                                    ListingLocationMapPage(item: item),
                              ),
                            );
                          },
                          leading: const Icon(
                            CupertinoIcons.location_solid,
                            color: AppPalette.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isOwnListing)
                    AppPrimaryButton(
                      label: '管理这个商品',
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const MyListingsPage(),
                          ),
                        );
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: isLiked ? '已点赞' : '点赞',
                            onPressed: onLike,
                            leading: Icon(
                              isLiked
                                  ? CupertinoIcons.hand_thumbsup_fill
                                  : CupertinoIcons.hand_thumbsup,
                              color: AppPalette.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPrimaryButton(
                            label: '联系卖家',
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => ChatThreadPage(
                                    conversation: buildConversationForItem(
                                      item,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPhoto extends StatefulWidget {
  const _HeroPhoto({
    required this.item,
    required this.onBack,
    required this.onFavorite,
  });

  final MarketItem item;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  State<_HeroPhoto> createState() => _HeroPhotoState();
}

class _HeroPhotoState extends State<_HeroPhoto> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final imageUrls = widget.item.imageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);

    return SizedBox(
      height: MediaQuery.sizeOf(context).width * 1.12,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.item.color.withValues(alpha: 0.46),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: _HeroArtwork(
              item: widget.item,
              imageUrls: imageUrls,
              onImageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x550F1915), Color(0x000F1915)],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: topInset + 10,
            child: AppNavIconButton(
              icon: CupertinoIcons.chevron_left,
              semanticLabel: '返回',
              onPressed: widget.onBack,
            ),
          ),
          Positioned(
            right: 18,
            top: topInset + 10,
            child: AppNavIconButton(
              icon: widget.item.isFavorite
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
              semanticLabel: widget.item.isFavorite ? '取消收藏' : '收藏',
              color: widget.item.isFavorite
                  ? AppPalette.warmAccent
                  : AppPalette.brand,
              onPressed: widget.onFavorite,
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: _HeroImageIndicator(
                count: imageUrls.length,
                currentIndex: _currentImageIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({
    required this.item,
    required this.imageUrls,
    required this.onImageChanged,
  });

  final MarketItem item;
  final List<String> imageUrls;
  final ValueChanged<int> onImageChanged;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Center(
        child: Icon(item.icon, color: AppPalette.brandDark, size: 118),
      );
    }

    if (imageUrls.length == 1) {
      return _HeroNetworkImage(url: imageUrls.first, item: item);
    }

    return PageView.builder(
      itemCount: imageUrls.length,
      onPageChanged: onImageChanged,
      itemBuilder: (context, index) {
        return _HeroNetworkImage(url: imageUrls[index], item: item);
      },
    );
  }
}

class _HeroNetworkImage extends StatelessWidget {
  const _HeroNetworkImage({required this.url, required this.item});

  final String url;
  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Center(
          child: Icon(item.icon, color: AppPalette.brandDark, size: 118),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(item.icon, color: AppPalette.brandDark, size: 118),
        );
      },
    );
  }
}

class _HeroImageIndicator extends StatelessWidget {
  const _HeroImageIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppPalette.ink.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: CupertinoColors.white.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < count; index++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == currentIndex ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == currentIndex
                      ? CupertinoColors.white
                      : CupertinoColors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (index != count - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconStat extends StatelessWidget {
  const _IconStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppPalette.mutedText, size: 16),
        const SizedBox(width: 4),
        Text(
          context.l10n.ui(label),
          style: const TextStyle(
            color: AppPalette.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.ui(label),
          style: const TextStyle(color: AppPalette.mutedText, fontSize: 14),
        ),
        const Spacer(),
        Text(
          context.l10n.ui(value),
          style: const TextStyle(
            color: AppPalette.strongText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
