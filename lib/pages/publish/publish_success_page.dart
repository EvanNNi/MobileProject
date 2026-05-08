import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../widgets/app_components.dart';
import '../market/market_home_page.dart';
import 'publish_entry_page.dart';

class PublishSuccessPage extends StatelessWidget {
  const PublishSuccessPage({
    super.key,
    required this.draft,
    required this.listingId,
  });

  final ListingDraft draft;
  final String listingId;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '发布成功',
      previousPageTitle: 'AI 估价',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: AppPalette.ink,
                borderRadius: BorderRadius.circular(34),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppPalette.mint,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: AppPalette.ink,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.ui('商品已发布'),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.ui('已加入“我的发布”，买家现在可以在附近商品中看到它。'),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppPalette.mint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _SuccessArtwork(draft: draft),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.listingText(
                                draft.title,
                                draft.titleEn,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.strongText,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '£${draft.suggestedPrice}',
                              style: const TextStyle(
                                color: AppPalette.brand,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppTag(label: draft.category),
                      AppTag(label: draft.condition),
                      AppTag(label: '${draft.images.length} 张图'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                AppMetricTile(
                  label: '发布状态',
                  value: '在售',
                  caption: '已进入市场',
                  highlight: true,
                ),
                const SizedBox(width: 12),
                AppMetricTile(
                  label: '商品编号',
                  value: _shortListingId(listingId),
                  caption: '可在我的发布管理',
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              label: '返回首页',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute<void>(
                    builder: (_) => const MarketHomePage(),
                  ),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 12),
            AppSecondaryButton(
              label: '继续发布',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute<void>(
                    builder: (_) => const PublishEntryPage(),
                  ),
                  (route) => false,
                );
              },
              leading: const Icon(
                CupertinoIcons.plus_circle_fill,
                color: AppPalette.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessArtwork extends StatelessWidget {
  const _SuccessArtwork({required this.draft});

  final ListingDraft draft;

  @override
  Widget build(BuildContext context) {
    final path = draft.images.isEmpty ? null : draft.images.first.path;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return Icon(
      _iconForCategory(draft.category),
      color: AppPalette.ink,
      size: 28,
    );
  }
}

IconData _iconForCategory(String category) {
  if (category.contains('数码') || category.contains('耳机')) {
    return CupertinoIcons.headphones;
  }
  if (category.contains('相机') || category.contains('摄影')) {
    return CupertinoIcons.camera_fill;
  }
  if (category.contains('鞋')) {
    return CupertinoIcons.tag_fill;
  }
  if (category.contains('包') || category.contains('箱')) {
    return CupertinoIcons.bag_fill;
  }
  if (category.contains('家具')) {
    return CupertinoIcons.house_fill;
  }
  return CupertinoIcons.cube_box_fill;
}

String _shortListingId(String listingId) {
  if (listingId.length <= 6) {
    return listingId.isEmpty ? '已创建' : listingId;
  }
  return listingId.substring(0, 6).toUpperCase();
}
