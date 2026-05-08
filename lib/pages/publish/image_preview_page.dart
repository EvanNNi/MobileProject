import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/ai_listing_analysis_service.dart';
import '../../services/album_image_picker_service.dart';
import '../../widgets/app_components.dart';
import 'multi_recognition_result_page.dart';
import 'publish_camera_page.dart';
import 'publish_flow_menu.dart';
import 'product_info_edit_page.dart';

class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({super.key, required this.draft});

  final ListingDraft draft;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late List<ListingImage> _images;
  bool _isPickingAlbum = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0;

  @override
  void initState() {
    super.initState();
    _images = [...widget.draft.images];
  }

  Future<void> _addAlbumImage() async {
    if (_isPickingAlbum || _images.length >= 6) {
      return;
    }

    setState(() {
      _isPickingAlbum = true;
    });

    try {
      final pickedImages = await AlbumImagePickerService.instance
          .pickListingImages(
            remainingSlots: 6 - _images.length,
            startIndex: _images.length,
          );
      if (!mounted || pickedImages.isEmpty) {
        return;
      }
      setState(() {
        _images = [..._images, ...pickedImages];
      });
    } on AlbumPickerException catch (error) {
      if (mounted) {
        _showPickerError(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAlbum = false;
        });
      }
    }
  }

  void _remove(String id) {
    setState(() {
      _images = _images.where((image) => image.id != id).toList();
    });
  }

  Future<void> _continue() async {
    if (_isAnalyzing || _images.isEmpty) {
      return;
    }

    final draft = widget.draft.copyWith(images: _images);
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0;
    });

    try {
      final analyzedDraft = await AiListingAnalysisService.instance
          .analyzeDraft(
            draft,
            stage: AiListingAnalysisStage.recognition,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _analysisProgress = progress);
              }
            },
          );
      if (!mounted) {
        return;
      }
      _openRecognitionResult(analyzedDraft);
    } on AiListingAnalysisException catch (error) {
      if (!mounted) {
        return;
      }
      final shouldContinue = await _showAnalysisError(error.message);
      if (mounted && shouldContinue) {
        _openProductInfo(draft);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisProgress = 0;
        });
      }
    }
  }

  void _openProductInfo(ListingDraft draft) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ProductInfoEditPage(draft: draft),
      ),
    );
  }

  void _openRecognitionResult(ListingDraft draft) {
    if (draft.recognizedItems.isNotEmpty) {
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => MultiRecognitionResultPage(draft: draft),
        ),
      );
      return;
    }

    _openProductInfo(draft);
  }

  Future<bool> _showAnalysisError(String message) async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(context.l10n.ui('AI 识别失败')),
            content: Text(
              context.l10n.text(
                '$message\n\n你也可以先手动填写商品信息。',
                '$message\n\nYou can also fill in the item details manually.',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.ui('稍后再试')),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.ui('手动填写')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showPickerError(String message) {
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

  Future<void> _addCameraImage() async {
    if (_isAnalyzing || _images.length >= 6) {
      return;
    }

    final updatedDraft = await Navigator.of(context).push<ListingDraft>(
      CupertinoPageRoute<ListingDraft>(
        builder: (_) => PublishCameraPage(
          draft: widget.draft.copyWith(images: _images),
          returnDraftOnComplete: true,
        ),
      ),
    );

    if (!mounted || updatedDraft == null) {
      return;
    }

    setState(() {
      _images = [...updatedDraft.images];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '图片预览',
      previousPageTitle: '卖闲置',
      trailing: PublishFlowMenuButton(
        draftBuilder: () => widget.draft.copyWith(images: _images),
        stage: ListingDraftResumeStage.preview,
      ),
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AppSectionCard(
              child: Row(
                children: [
                  const Expanded(
                    child: AppSectionTitle(title: '商品图片', subtitle: '主图、细节、配件'),
                  ),
                  AppTag(
                    label: '${_images.length}/6',
                    icon: CupertinoIcons.photo_fill,
                    color: AppPalette.yellow,
                    textColor: AppPalette.ink,
                  ),
                ],
              ),
            ),
            if (_images.length < 6) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      label: '继续拍照',
                      onPressed: _isAnalyzing ? null : _addCameraImage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppSecondaryButton(
                      label: _isPickingAlbum ? '打开中' : '相册上传',
                      onPressed: _isAnalyzing || _isPickingAlbum
                          ? null
                          : _addAlbumImage,
                      leading: const Icon(
                        CupertinoIcons.photo_on_rectangle,
                        color: AppPalette.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _images.length + (_images.length < 6 ? 1 : 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _AddImageTile(
                    isPicking: _isPickingAlbum,
                    isDisabled: _isAnalyzing,
                    onCameraTap: _addCameraImage,
                    onAlbumTap: _addAlbumImage,
                  );
                }
                final image = _images[index];
                return _PreviewTile(
                  image: image,
                  isCover: index == 0,
                  onRemove: () => _remove(image.id),
                );
              },
            ),
            const SizedBox(height: 18),
            if (_isAnalyzing) ...[
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionTitle(
                      title: 'AI 正在识别商品',
                      subtitle: '正在上传图片并识别类别、品牌、型号和成色。',
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        color: AppPalette.surfaceWarm,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _analysisProgress == 0
                              ? 0.12
                              : _analysisProgress.clamp(0.08, 1.0).toDouble(),
                          child: Container(color: AppPalette.brand),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            AppPrimaryButton(
              label: _isAnalyzing ? 'AI 识别中...' : '上传并识别',
              onPressed: _images.isEmpty || _isAnalyzing ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.image,
    required this.isCover,
    required this.onRemove,
  });

  final ListingImage image;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ImageVisual(image: image),
            Positioned(
              left: 10,
              top: 10,
              child: AppTag(
                label: isCover ? '主图' : image.label,
                color: isCover ? AppPalette.yellow : AppPalette.brandLight,
                textColor: AppPalette.ink,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onRemove,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppPalette.ink.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: CupertinoColors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageVisual extends StatelessWidget {
  const _ImageVisual({required this.image});

  final ListingImage image;

  @override
  Widget build(BuildContext context) {
    final path = image.path;
    if (path != null) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: image.color.withValues(alpha: 0.45)),
      child: Center(child: Icon(image.icon, color: AppPalette.ink, size: 54)),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({
    required this.isPicking,
    required this.isDisabled,
    required this.onCameraTap,
    required this.onAlbumTap,
  });

  final bool isPicking;
  final bool isDisabled;
  final VoidCallback onCameraTap;
  final VoidCallback onAlbumTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceWarm,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.plus_circle_fill,
            color: AppPalette.brand,
            size: 36,
          ),
          const SizedBox(height: 10),
          _AddImageAction(
            icon: CupertinoIcons.camera_fill,
            label: '继续拍照',
            onTap: isDisabled ? null : onCameraTap,
          ),
          const SizedBox(height: 8),
          _AddImageAction(
            icon: CupertinoIcons.photo_on_rectangle,
            label: isPicking ? '打开中' : '相册上传',
            isLoading: isPicking,
            onTap: isDisabled || isPicking ? null : onAlbumTap,
          ),
        ],
      ),
    );
  }
}

class _AddImageAction extends StatelessWidget {
  const _AddImageAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.48,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: CupertinoColors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppPalette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const CupertinoActivityIndicator(radius: 8)
              else
                Icon(icon, color: AppPalette.brand, size: 16),
              const SizedBox(width: 6),
              Text(
                context.l10n.ui(label),
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
