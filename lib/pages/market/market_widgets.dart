import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../widgets/app_components.dart';

class MarketSearchBar extends StatelessWidget {
  const MarketSearchBar({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.onFilterTap,
  });

  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppPalette.surfaceWarm,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: AppPalette.border.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.search,
                    color: AppPalette.mutedText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.ui(placeholder),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onFilterTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppPalette.border),
            ),
            child: const Icon(
              CupertinoIcons.slider_horizontal_3,
              color: AppPalette.strongText,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class MarketProductCard extends StatelessWidget {
  const MarketProductCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onFavoriteTap,
    this.compact = false,
  });

  final MarketItem item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ColoredBox(
        color: AppPalette.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _MarketItemArtwork(item: item, iconSize: 48),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: onFavoriteTap,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: CupertinoColors.white.withValues(
                              alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppPalette.border.withValues(alpha: 0.65),
                            ),
                          ),
                          child: Icon(
                            item.isFavorite
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            color: item.isFavorite
                                ? AppPalette.warmAccent
                                : AppPalette.ink,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(2, compact ? 8 : 10, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.listingText(item.title, item.titleEn),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '£${item.price}',
                        style: const TextStyle(
                          color: AppPalette.strongText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.l10n.ui(_distanceOrLocationText(item)),
                        style: const TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      AppTag(label: item.condition),
                      const Spacer(),
                      Icon(
                        CupertinoIcons.eye,
                        color: AppPalette.mutedText,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.views}',
                        style: const TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 12,
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

class MarketListItem extends StatelessWidget {
  const MarketListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final MarketItem item;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final condition = context.l10n.ui(item.condition);
    final title = context.l10n.listingText(item.title, item.titleEn);
    final distance = context.l10n.ui(_distanceOrLocationText(item));

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppSectionCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 84,
                height: 84,
                child: _MarketItemArtwork(item: item, iconSize: 36),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.brand} · $condition · $distance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '£${item.price}',
                    style: const TextStyle(
                      color: AppPalette.brand,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onFavoriteTap,
              child: Icon(
                item.isFavorite
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                color: item.isFavorite
                    ? AppPalette.warmAccent
                    : AppPalette.mutedText,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _distanceOrLocationText(MarketItem item) {
  if (item.distance > 0) {
    return '${item.distance.toStringAsFixed(1)}km';
  }
  final location = item.location.trim();
  if (location.isNotEmpty && location != '未知位置') {
    return location;
  }
  return '位置待确认';
}

class _MarketItemArtwork extends StatelessWidget {
  const _MarketItemArtwork({required this.item, required this.iconSize});

  final MarketItem item;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final imageUrls = item.imageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
    if (imageUrls.isEmpty) {
      return _ArtworkFallback(item: item, iconSize: iconSize);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPreviewCount = constraints.maxWidth < 100 ? 1 : 3;
        final previewUrls = imageUrls
            .skip(1)
            .take(maxPreviewCount)
            .toList(growable: false);

        return Stack(
          fit: StackFit.expand,
          children: [
            _NetworkArtworkImage(
              url: imageUrls.first,
              fallback: _ArtworkFallback(item: item, iconSize: iconSize),
            ),
            if (imageUrls.length > 1)
              Positioned(
                left: 7,
                right: 7,
                bottom: 7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final url in previewUrls) ...[
                      _ArtworkThumbnail(url: url, item: item),
                      const SizedBox(width: 5),
                    ],
                    _ImageCountBadge(count: imageUrls.length),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NetworkArtworkImage extends StatelessWidget {
  const _NetworkArtworkImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return fallback;
      },
      errorBuilder: (context, error, stackTrace) {
        return fallback;
      },
    );
  }
}

class _ArtworkThumbnail extends StatelessWidget {
  const _ArtworkThumbnail({required this.url, required this.item});

  final String url;
  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.white.withValues(alpha: 0.92),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F1915),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(item.icon, color: AppPalette.ink, size: 13);
        },
      ),
    );
  }
}

class _ImageCountBadge extends StatelessWidget {
  const _ImageCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppPalette.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CupertinoColors.white.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.photo_on_rectangle,
            color: CupertinoColors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.item, required this.iconSize});

  final MarketItem item;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.4)),
      child: Center(
        child: Icon(item.icon, color: AppPalette.ink, size: iconSize),
      ),
    );
  }
}
