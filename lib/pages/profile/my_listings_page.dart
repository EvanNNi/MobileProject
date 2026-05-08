import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/market_item.dart';
import '../../services/auth_service.dart';
import '../../services/listing_repository.dart';
import '../../services/market_listing_repository.dart';
import '../../widgets/app_components.dart';
import 'edit_my_listing_page.dart';

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  String _filter = 'all';
  String? _updatingListingId;

  Future<void> _openEditor(MarketItem item) async {
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(builder: (_) => EditMyListingPage(item: item)),
    );
  }

  Future<void> _confirmStatusUpdate({
    required MarketItem item,
    required String nextStatus,
    required String title,
    required String message,
  }) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui(title)),
        content: Text(context.l10n.ui(message)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.ui('取消')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.ui('确认')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _updateStatus(item: item, nextStatus: nextStatus);
  }

  Future<void> _updateStatus({
    required MarketItem item,
    required String nextStatus,
  }) async {
    setState(() => _updatingListingId = item.id);
    try {
      await ListingRepository.instance.updateListingStatus(
        listingId: item.id,
        status: nextStatus,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('操作失败')),
          content: Text(authErrorMessage(error)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ui('知道了')),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingListingId = null);
      }
    }
  }

  List<MarketItem> _visibleItems(List<MarketItem> items) {
    if (_filter == 'all') {
      return items;
    }
    return items.where((item) => item.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '我的发布',
      previousPageTitle: '个人中心',
      child: AppBackdrop(
        child: StreamBuilder<List<MarketItem>>(
          stream: MarketListingRepository.instance.watchMyListings(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <MarketItem>[];
            final visibleItems = _visibleItems(items);
            final activeCount = items
                .where((item) => item.status == 'active')
                .length;
            final soldCount = items
                .where((item) => item.status == 'sold')
                .length;
            final inactiveCount = items
                .where((item) => item.status == 'inactive')
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                AppHeroCard(
                  title: '你的闲置货架',
                  subtitle: '这里显示你发布到平台的所有商品，可以下架、标记已售或修改信息。',
                  badge: '${items.length} 件发布',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    AppMetricTile(
                      label: '在售',
                      value: '$activeCount',
                      caption: '正在市场展示',
                      highlight: true,
                    ),
                    const SizedBox(width: 12),
                    AppMetricTile(
                      label: '已售',
                      value: '$soldCount',
                      caption: '成交后可留档',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppSectionCard(
                  padding: const EdgeInsets.all(14),
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _filter,
                    thumbColor: AppPalette.surface,
                    backgroundColor: AppPalette.surfaceWarm,
                    children: {
                      'all': _FilterLabel(label: '全部', count: items.length),
                      'active': _FilterLabel(label: '在售', count: activeCount),
                      'sold': _FilterLabel(label: '已售', count: soldCount),
                      'inactive': _FilterLabel(
                        label: '下架',
                        count: inactiveCount,
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => _filter = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const AppSectionCard(
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                else if (snapshot.hasError)
                  AppSectionCard(
                    child: Text(
                      context.l10n.text(
                        '读取我的发布失败：${authErrorMessage(snapshot.error ?? '')}',
                        'Could not load my listings: ${authErrorMessage(snapshot.error ?? '')}',
                      ),
                      style: const TextStyle(color: AppPalette.mutedText),
                    ),
                  )
                else if (visibleItems.isEmpty)
                  _EmptyListingsCard(filter: _filter)
                else
                  for (final item in visibleItems) ...[
                    _MyListingCard(
                      item: item,
                      isUpdating: _updatingListingId == item.id,
                      onEdit: () => _openEditor(item),
                      onTakeDown: () => _confirmStatusUpdate(
                        item: item,
                        nextStatus: 'inactive',
                        title: '下架这个商品？',
                        message: '下架后商品不会继续出现在交易市场，但你仍可以在个人中心重新上架。',
                      ),
                      onMarkSold: () => _confirmStatusUpdate(
                        item: item,
                        nextStatus: 'sold',
                        title: '标记为已售？',
                        message: '标记后商品会从交易市场移除，并保留在你的已售记录里。',
                      ),
                      onRelist: () => _confirmStatusUpdate(
                        item: item,
                        nextStatus: 'active',
                        title: '重新上架这个商品？',
                        message: '重新上架后，买家可以再次在交易市场看到这个商品。',
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  const _MyListingCard({
    required this.item,
    required this.isUpdating,
    required this.onEdit,
    required this.onTakeDown,
    required this.onMarkSold,
    required this.onRelist,
  });

  final MarketItem item;
  final bool isUpdating;
  final VoidCallback onEdit;
  final VoidCallback onTakeDown;
  final VoidCallback onMarkSold;
  final VoidCallback onRelist;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: _ListingThumbnail(item: item),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppTag(
                          label: _statusLabel(item.status),
                          color: _statusColor(item.status),
                          textColor: AppPalette.ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.ui(_updatedText(item)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.listingText(item.title, item.titleEn),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.l10n.ui(item.category)} · ${context.l10n.ui(item.condition)} · ${item.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '£${item.price}',
                          style: const TextStyle(
                            color: AppPalette.brand,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          CupertinoIcons.eye,
                          color: AppPalette.mutedText,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.views}',
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          CupertinoIcons.heart,
                          color: AppPalette.mutedText,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.likes}',
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isUpdating)
            const Center(child: CupertinoActivityIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ListingActionButton(
                  label: '修改',
                  icon: CupertinoIcons.pencil,
                  onPressed: onEdit,
                ),
                if (item.status == 'active') ...[
                  _ListingActionButton(
                    label: '标记已售',
                    icon: CupertinoIcons.check_mark_circled_solid,
                    onPressed: onMarkSold,
                    isPrimary: true,
                  ),
                  _ListingActionButton(
                    label: '下架',
                    icon: CupertinoIcons.archivebox_fill,
                    onPressed: onTakeDown,
                  ),
                ] else
                  _ListingActionButton(
                    label: '重新上架',
                    icon: CupertinoIcons.arrow_up_circle_fill,
                    onPressed: onRelist,
                    isPrimary: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ListingThumbnail extends StatelessWidget {
  const _ListingThumbnail({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrls.isEmpty ? null : item.imageUrls.first;
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          return loadingProgress == null
              ? child
              : _ThumbnailFallback(item: item);
        },
        errorBuilder: (context, error, stackTrace) {
          return _ThumbnailFallback(item: item);
        },
      );
    }

    return _ThumbnailFallback(item: item);
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.32)),
      child: Center(child: Icon(item.icon, color: AppPalette.ink, size: 34)),
    );
  }
}

class _ListingActionButton extends StatelessWidget {
  const _ListingActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: isPrimary ? AppPalette.brand : AppPalette.surfaceWarm,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPrimary
                ? AppPalette.brand
                : AppPalette.border.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? CupertinoColors.white : AppPalette.brand,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.ui(label),
              style: TextStyle(
                color: isPrimary ? CupertinoColors.white : AppPalette.brand,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        '${context.l10n.ui(label)} $count',
        style: const TextStyle(
          color: AppPalette.strongText,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyListingsCard extends StatelessWidget {
  const _EmptyListingsCard({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'active' => '还没有在售商品',
      'sold' => '还没有已售商品',
      'inactive' => '还没有下架商品',
      _ => '还没有发布商品',
    };

    return AppSectionCard(
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppPalette.brandLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              CupertinoIcons.cube_box,
              color: AppPalette.brand,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.ui(label),
            style: const TextStyle(
              color: AppPalette.strongText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.ui('发布成功后，商品会自动出现在这里。'),
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

String _statusLabel(String status) {
  return switch (status) {
    'sold' => '已售',
    'inactive' => '已下架',
    _ => '在售',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'sold' => AppPalette.yellow,
    'inactive' => AppPalette.surfaceWarm,
    _ => AppPalette.mint,
  };
}

String _updatedText(MarketItem item) {
  final time = item.updatedAt ?? item.createdAt;
  if (time == null) {
    return '刚刚更新';
  }

  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.inMinutes < 1) {
    return '刚刚更新';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前更新';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前更新';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} 天前更新';
  }
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}
