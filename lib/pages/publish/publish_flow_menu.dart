import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/listing_draft_repository.dart';
import '../../widgets/app_components.dart';
import '../market/market_home_page.dart';

export '../../services/listing_draft_repository.dart'
    show ListingDraftResumeStage;

class PublishFlowMenuButton extends StatelessWidget {
  const PublishFlowMenuButton({
    super.key,
    required this.draftBuilder,
    required this.stage,
  });

  final ListingDraft Function() draftBuilder;
  final ListingDraftResumeStage stage;

  @override
  Widget build(BuildContext context) {
    return AppNavIconButton(
      icon: CupertinoIcons.ellipsis,
      semanticLabel: '发布操作',
      onPressed: () => _showActions(context),
    );
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(context.l10n.ui('发布操作')),
        message: Text(context.l10n.ui('可以先保存当前进度，或者退出并删除本次上传内容。')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _saveDraft(context);
            },
            child: Text(context.l10n.ui('保存到草稿箱')),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _confirmExitAndDelete(context);
            },
            child: Text(context.l10n.ui('退出并删除')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(context.l10n.ui('取消')),
        ),
      ),
    );
  }

  Future<void> _saveDraft(BuildContext context) async {
    final draft = draftBuilder();
    if (!_hasUserContent(draft)) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('还没有可保存内容')),
          content: Text(context.l10n.ui('请先添加商品图片，或填写商品信息后再保存草稿。')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.ui('知道了')),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await ListingDraftRepository.instance.saveDraft(draft, stage: stage);
      if (!context.mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('已保存到草稿箱')),
          content: Text(context.l10n.ui('当前图片和填写内容已经保存，之后可以继续完善。')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.ui('知道了')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(context.l10n.ui('保存失败')),
          content: Text(
            context.l10n.text(
              '草稿暂时没有保存成功：$error',
              'Draft could not be saved: $error',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.ui('知道了')),
            ),
          ],
        ),
      );
    }
  }

  bool _hasUserContent(ListingDraft draft) {
    return draft.images.isNotEmpty ||
        draft.category.trim().isNotEmpty ||
        draft.condition.trim().isNotEmpty ||
        draft.brand.trim().isNotEmpty ||
        draft.model.trim().isNotEmpty ||
        draft.title.trim().isNotEmpty ||
        draft.description.trim().isNotEmpty ||
        draft.aiSupplement.trim().isNotEmpty ||
        draft.locationLabel.trim().isNotEmpty;
  }

  Future<void> _confirmExitAndDelete(BuildContext context) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.l10n.ui('退出并删除？')),
        content: Text(context.l10n.ui('本次上传的照片和填写内容会被清空，已经保存到草稿箱的副本不会受影响。')),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.ui('取消')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.ui('删除并退出')),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    await ListingDraftRepository.instance.deleteWorkingFiles(draftBuilder());
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute<void>(builder: (_) => const MarketHomePage()),
      (route) => false,
    );
  }
}
