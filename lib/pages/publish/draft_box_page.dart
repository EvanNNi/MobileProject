import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/listing_draft_repository.dart';
import '../../widgets/app_components.dart';
import 'ai_price_result_page.dart';
import 'image_preview_page.dart';
import 'product_info_edit_page.dart';
import 'publish_camera_page.dart';
import 'publish_entry_page.dart';

class DraftBoxPage extends StatefulWidget {
  const DraftBoxPage({super.key});

  @override
  State<DraftBoxPage> createState() => _DraftBoxPageState();
}

class _DraftBoxPageState extends State<DraftBoxPage> {
  late Future<List<SavedListingDraft>> _draftsFuture;

  @override
  void initState() {
    super.initState();
    _reloadDrafts();
  }

  void _reloadDrafts() {
    _draftsFuture = ListingDraftRepository.instance.loadDrafts();
  }

  Future<void> _refreshDrafts() async {
    setState(_reloadDrafts);
    await _draftsFuture;
  }

  Future<void> _continueDraft(SavedListingDraft draft) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => _resumePageForDraft(draft)),
    );
    if (mounted) {
      setState(_reloadDrafts);
    }
  }

  Widget _resumePageForDraft(SavedListingDraft savedDraft) {
    final draft = savedDraft.draft;
    switch (savedDraft.stage) {
      case ListingDraftResumeStage.camera:
        return PublishCameraPage(draft: draft);
      case ListingDraftResumeStage.preview:
        if (draft.images.isEmpty) {
          return PublishCameraPage(draft: draft);
        }
        return ImagePreviewPage(draft: draft);
      case ListingDraftResumeStage.info:
        return ProductInfoEditPage(draft: draft);
      case ListingDraftResumeStage.price:
        return AiPriceResultPage(draft: draft);
    }
  }

  Future<void> _deleteDraft(SavedListingDraft draft) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.ui('删除草稿？')),
        content: Text(
          context.l10n.text(
            '“${_draftTitle(context, draft.draft)}”会从本机草稿箱移除。',
            '"${_draftTitle(context, draft.draft)}" will be removed from local drafts.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.ui('取消')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.ui('删除')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await ListingDraftRepository.instance.deleteDraft(draft.id);
    if (mounted) {
      setState(_reloadDrafts);
    }
  }

  void _startNewPublish() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const PublishEntryPage()));
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '草稿箱',
      previousPageTitle: '个人中心',
      child: AppBackdrop(
        child: FutureBuilder<List<SavedListingDraft>>(
          future: _draftsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final drafts = snapshot.data ?? const <SavedListingDraft>[];
            if (drafts.isEmpty) {
              return _EmptyDraftBox(onStartNew: _startNewPublish);
            }

            return CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _refreshDrafts),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: drafts.length + 1,
                    separatorBuilder: (_, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return AppSectionCard(
                          child: Row(
                            children: [
                              const Expanded(
                                child: AppSectionTitle(
                                  title: '本地草稿',
                                  subtitle: '草稿只保存在当前设备，不会自动同步到云端。',
                                ),
                              ),
                              AppTag(
                                label: '${drafts.length} 个',
                                icon: CupertinoIcons.doc_text_fill,
                                color: AppPalette.yellow,
                                textColor: AppPalette.ink,
                              ),
                            ],
                          ),
                        );
                      }

                      final draft = drafts[index - 1];
                      return _DraftCard(
                        draft: draft,
                        onContinue: () => _continueDraft(draft),
                        onDelete: () => _deleteDraft(draft),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onContinue,
    required this.onDelete,
  });

  final SavedListingDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final listingDraft = draft.draft;
    return AppSectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _DraftThumbnail(
            image: listingDraft.images.isEmpty
                ? null
                : listingDraft.images.first,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppTag(label: _stageLabel(draft.stage)),
                    const SizedBox(width: 8),
                    AppTag(label: '${listingDraft.images.length} 张图'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _draftTitle(context, listingDraft),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _draftSubtitle(context, listingDraft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.ui('保存于 ${_relativeTime(draft.savedAt)}'),
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppPrimaryButton(
                        label: '继续编辑',
                        onPressed: onContinue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: onDelete,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          CupertinoIcons.trash,
                          color: CupertinoColors.systemRed,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftThumbnail extends StatelessWidget {
  const _DraftThumbnail({required this.image});

  final ListingImage? image;

  @override
  Widget build(BuildContext context) {
    final path = image?.path;
    final imageFile = path == null || path.isEmpty ? null : File(path);
    final hasImage = imageFile != null && imageFile.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 96,
        height: 124,
        color: AppPalette.brandLight,
        child: hasImage
            ? Image.file(imageFile, fit: BoxFit.cover)
            : const Icon(
                CupertinoIcons.cube_box_fill,
                color: AppPalette.brand,
                size: 34,
              ),
      ),
    );
  }
}

class _EmptyDraftBox extends StatelessWidget {
  const _EmptyDraftBox({required this.onStartNew});

  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppSectionCard(
          child: Column(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppPalette.brandLight,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  CupertinoIcons.tray,
                  color: AppPalette.brand,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.ui('还没有本地草稿'),
                style: const TextStyle(
                  color: AppPalette.strongText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.ui('发布商品时点击右上角按钮，就可以把当前图片和填写内容保存到这里。'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(label: '去发布商品', onPressed: onStartNew),
            ],
          ),
        ),
      ],
    );
  }
}

String _draftTitle(BuildContext context, ListingDraft draft) {
  final title = draft.title.trim();
  if (title.isNotEmpty) {
    return context.l10n.listingText(title, draft.titleEn);
  }

  final brandAndModel = [
    draft.brand.trim(),
    draft.model.trim(),
  ].where((item) => item.isNotEmpty).join(' ');
  if (brandAndModel.isNotEmpty) {
    return brandAndModel;
  }

  return '未命名商品草稿';
}

String _draftSubtitle(BuildContext context, ListingDraft draft) {
  final parts = [
    context.l10n.ui(draft.category),
    context.l10n.ui(draft.condition),
    if (draft.suggestedPrice > 0) '£${draft.suggestedPrice}',
    draft.locationLabel,
  ].where((item) => item.trim().isNotEmpty).toList();
  return parts.join(' · ');
}

String _stageLabel(ListingDraftResumeStage stage) {
  switch (stage) {
    case ListingDraftResumeStage.camera:
      return '拍照中';
    case ListingDraftResumeStage.preview:
      return '图片预览';
    case ListingDraftResumeStage.info:
      return '信息编辑';
    case ListingDraftResumeStage.price:
      return 'AI 估价';
  }
}

String _relativeTime(DateTime savedAt) {
  final now = DateTime.now();
  final difference = now.difference(savedAt);
  if (difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} 天前';
  }

  final month = savedAt.month.toString().padLeft(2, '0');
  final day = savedAt.day.toString().padLeft(2, '0');
  final hour = savedAt.hour.toString().padLeft(2, '0');
  final minute = savedAt.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
