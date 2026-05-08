import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/album_image_picker_service.dart';
import '../../widgets/app_components.dart';
import '../market/market_home_page.dart';
import 'image_preview_page.dart';
import 'publish_camera_page.dart';

class PublishEntryPage extends StatefulWidget {
  const PublishEntryPage({super.key, this.showHomeExitWhenRoot = true});

  final bool showHomeExitWhenRoot;

  @override
  State<PublishEntryPage> createState() => _PublishEntryPageState();
}

class _PublishEntryPageState extends State<PublishEntryPage> {
  bool _isPickingAlbum = false;

  void _returnHome() {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute<void>(builder: (_) => const MarketHomePage()),
      (route) => false,
    );
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const PublishCameraPage(draft: ListingDraft()),
      ),
    );
  }

  Future<void> _openAlbum(BuildContext context) async {
    if (_isPickingAlbum) {
      return;
    }

    setState(() {
      _isPickingAlbum = true;
    });

    try {
      final images = await AlbumImagePickerService.instance.pickListingImages(
        remainingSlots: 6,
        startIndex: 0,
      );
      if (!context.mounted || images.isEmpty) {
        return;
      }

      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => ImagePreviewPage(draft: ListingDraft(images: images)),
        ),
      );
    } on AlbumPickerException catch (error) {
      if (context.mounted) {
        _showPickerError(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAlbum = false;
        });
      }
    }
  }

  Future<void> _showPickerError(BuildContext context, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui('无法读取相册')),
        content: Text(message),
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
    final canPop = Navigator.of(context).canPop();
    return AppPageScaffold(
      title: '卖闲置',
      previousPageTitle: '首页',
      leading: !canPop && widget.showHomeExitWhenRoot
          ? AppNavIconButton(
              icon: CupertinoIcons.chevron_left,
              semanticLabel: '返回首页',
              onPressed: _returnHome,
            )
          : null,
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                _PublishMethodCard(
                  icon: CupertinoIcons.camera_fill,
                  title: '拍照添加',
                  caption: '实时拍摄商品',
                  color: AppPalette.mint,
                  onTap: () => _openCamera(context),
                ),
                const SizedBox(width: 12),
                _PublishMethodCard(
                  icon: CupertinoIcons.photo_on_rectangle,
                  title: '相册上传',
                  caption: _isPickingAlbum ? '正在打开相册' : '多图选择',
                  color: AppPalette.yellow,
                  onTap: _isPickingAlbum ? null : () => _openAlbum(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionTitle(title: '常卖分类', subtitle: '数码、球鞋、箱包、摄影器材'),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppTag(label: '耳机'),
                      AppTag(label: '显示器'),
                      AppTag(label: '球鞋'),
                      AppTag(label: '相机'),
                      AppTag(label: '包袋'),
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

class _PublishMethodCard extends StatelessWidget {
  const _PublishMethodCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: AppSectionCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppPalette.ink, size: 26),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.ui(title),
                style: const TextStyle(
                  color: AppPalette.strongText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.ui(caption),
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
