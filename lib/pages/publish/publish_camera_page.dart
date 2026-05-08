import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/listing_draft.dart';
import '../../services/album_image_picker_service.dart';
import '../../widgets/app_components.dart';
import 'image_preview_page.dart';

class PublishCameraPage extends StatefulWidget {
  const PublishCameraPage({
    super.key,
    required this.draft,
    this.returnDraftOnComplete = false,
  });

  final ListingDraft draft;
  final bool returnDraftOnComplete;

  @override
  State<PublishCameraPage> createState() => _PublishCameraPageState();
}

class _PublishCameraPageState extends State<PublishCameraPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isOpeningCamera = false;
  bool _isPickingAlbum = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openNativeCamera(popWhenCancelled: true);
      }
    });
  }

  Future<void> _openNativeCamera({bool popWhenCancelled = false}) async {
    if (_isOpeningCamera) {
      return;
    }

    setState(() {
      _isOpeningCamera = true;
      _errorMessage = null;
    });

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
        requestFullMetadata: false,
      );

      if (!mounted) {
        return;
      }

      if (image == null) {
        if (popWhenCancelled) {
          Navigator.of(context).maybePop();
        }
        return;
      }

      final savedImage = await _persistImage(image);
      if (!mounted) {
        return;
      }

      final index = widget.draft.images.length;
      _completeWithImages([
        ...widget.draft.images,
        ListingImage(
          id: 'camera-${DateTime.now().millisecondsSinceEpoch}',
          label: _labelForIndex(index),
          path: savedImage.path,
          icon: CupertinoIcons.camera_fill,
          color: AppPalette.mint,
          compressed: false,
        ),
      ]);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.text(
            '无法打开相机：$error',
            'Could not open camera: $error',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningCamera = false;
        });
      }
    }
  }

  Future<XFile> _persistImage(XFile image) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final picturesDirectory = Directory(
      '${documentsDirectory.path}/listing_photos',
    );
    if (!await picturesDirectory.exists()) {
      await picturesDirectory.create(recursive: true);
    }

    final fileName = 'listing_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = '${picturesDirectory.path}/$fileName';
    await image.saveTo(savedPath);
    return XFile(savedPath, mimeType: image.mimeType, name: fileName);
  }

  void _completeWithImages(List<ListingImage> images) {
    final draft = widget.draft.copyWith(images: images);
    if (widget.returnDraftOnComplete) {
      Navigator.of(context).pop(draft);
      return;
    }

    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(builder: (_) => ImagePreviewPage(draft: draft)),
    );
  }

  Future<void> _pickFromAlbum() async {
    if (_isPickingAlbum) {
      return;
    }

    setState(() {
      _isPickingAlbum = true;
      _errorMessage = null;
    });

    try {
      final images = await AlbumImagePickerService.instance.pickListingImages(
        remainingSlots: 6 - widget.draft.images.length,
        startIndex: widget.draft.images.length,
      );
      if (!mounted || images.isEmpty) {
        return;
      }

      _completeWithImages([...widget.draft.images, ...images]);
    } on AlbumPickerException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAlbum = false;
        });
      }
    }
  }

  String _labelForIndex(int index) {
    if (index == 0) {
      return '主图';
    }
    if (index == 1) {
      return '细节';
    }
    if (index == 2) {
      return '配件';
    }
    return '补充';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '拍照',
      previousPageTitle: widget.returnDraftOnComplete ? '图片预览' : '卖闲置',
      child: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: '系统全屏相机',
                    subtitle: '打开 iPhone 全屏拍照界面，拍完后会回到这里继续发布。',
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppPalette.ink,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: CupertinoColors.white.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: _isOpeningCamera
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                )
                              : const Icon(
                                  CupertinoIcons.camera_viewfinder,
                                  color: CupertinoColors.white,
                                  size: 38,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.ui(
                            _isOpeningCamera ? '正在打开相机...' : '全屏原生拍摄',
                          ),
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.ui('近距离拍摄时请在系统相机里点按商品主体对焦'),
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: _isPickingAlbum ? '打开中' : '相册上传',
                    onPressed: _isPickingAlbum ? null : _pickFromAlbum,
                    leading: const Icon(
                      CupertinoIcons.photo_on_rectangle,
                      color: AppPalette.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    label: _isOpeningCamera ? '打开中' : '打开相机',
                    onPressed: _isOpeningCamera
                        ? null
                        : () => _openNativeCamera(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.ui('近距离拍摄时，可以在相机里点按商品主体对焦；拍完后可继续补拍细节图。'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.mutedText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
