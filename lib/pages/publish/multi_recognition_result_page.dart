import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../widgets/app_components.dart';
import 'product_info_edit_page.dart';

class MultiRecognitionResultPage extends StatelessWidget {
  const MultiRecognitionResultPage({super.key, required this.draft});

  final ListingDraft draft;

  void _openProductInfo(BuildContext context, ListingDraft selectedDraft) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ProductInfoEditPage(draft: selectedDraft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = draft.recognizedItems;
    final hasMultipleItems = items.length > 1;

    return AppPageScaffold(
      title: hasMultipleItems ? '选择物品' : '识别结果',
      previousPageTitle: '图片预览',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AppHeroCard(
              title: hasMultipleItems ? '识别到多个物品' : '识别到 1 个物品',
              subtitle: hasMultipleItems
                  ? '请选择这次要发布的商品。后续仍然可以手动修改品牌、型号和描述。'
                  : '这是 AI 当前识别到的商品。如果图片里还有其他物品，可以返回补拍或手动填写。',
              badge: hasMultipleItems ? '多物品识别' : 'AI 识别结果',
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < items.length; index++) ...[
              _RecognizedItemCard(
                item: items[index],
                index: index,
                image: draft.images.isEmpty ? null : draft.images.first,
                onSelected: () {
                  _openProductInfo(context, items[index].applyToDraft(draft));
                },
              ),
              const SizedBox(height: 14),
            ],
            AppSecondaryButton(
              label: '都不对，手动填写',
              onPressed: () {
                _openProductInfo(
                  context,
                  draft.copyWith(recognizedItems: const []),
                );
              },
              leading: const Icon(
                CupertinoIcons.pencil,
                color: AppPalette.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecognizedItemCard extends StatelessWidget {
  const _RecognizedItemCard({
    required this.item,
    required this.index,
    required this.image,
    required this.onSelected,
  });

  final RecognizedListingItem item;
  final int index;
  final ListingImage? image;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = item.title.trim().isEmpty ? '未命名物品' : item.title;
    final meta = [
      item.category,
      item.brand,
      item.model,
      item.condition,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return AppSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CandidateImage(image: image),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppTag(
                          label: '物品 ${index + 1}',
                          color: AppPalette.yellow,
                          textColor: AppPalette.ink,
                        ),
                        const Spacer(),
                        if (item.confidence > 0)
                          AppTag(
                            label: '${item.confidence}%',
                            icon: CupertinoIcons.check_mark_circled_solid,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.listingText(title, item.titleEn),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.strongText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.ui(meta),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.listingText(item.description, item.descriptionEn),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.mutedText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag
                    in l10n.listingTags(item.tags, item.tagsEn).take(5))
                  AppTag(label: tag),
              ],
            ),
          ],
          const SizedBox(height: 14),
          AppPrimaryButton(label: '选择这个物品', onPressed: onSelected),
        ],
      ),
    );
  }
}

class _CandidateImage extends StatelessWidget {
  const _CandidateImage({required this.image});

  final ListingImage? image;

  @override
  Widget build(BuildContext context) {
    final path = image?.path;
    final file = path == null ? null : File(path);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 86,
        height: 102,
        child: file != null && file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: AppPalette.mint,
                child: const Icon(
                  CupertinoIcons.cube_box_fill,
                  color: AppPalette.ink,
                  size: 34,
                ),
              ),
      ),
    );
  }
}
