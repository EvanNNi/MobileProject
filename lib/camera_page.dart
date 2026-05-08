import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

class CameraPreviewPage extends StatefulWidget {
  const CameraPreviewPage({super.key});

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  bool _isCapturing = false;
  bool _isLoadingCamera = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoadingCamera = true;
      _errorMessage = null;
    });

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _initializeControllerFuture = null;
        _isLoadingCamera = false;
        _errorMessage = '当前设备没有可用摄像头。';
      });
      return;
    }

    final previousController = _controller;
    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    setState(() {
      _controller = controller;
      _initializeControllerFuture = controller.initialize();
    });

    await previousController?.dispose();

    try {
      await _initializeControllerFuture;
      if (!mounted) {
        return;
      }
      setState(() {});
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _errorMessage = _mapCameraError(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _errorMessage = '读取摄像头失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCamera = false;
        });
      }
    }
  }

  String _mapCameraError(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return '相机权限未开启，请前往 iPhone 设置中允许访问摄像头。';
      default:
        return '相机初始化失败：${error.description ?? error.code}';
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    final initializeFuture = _initializeControllerFuture;
    if (controller == null || initializeFuture == null || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      await initializeFuture;
      final temporaryImage = await controller.takePicture();
      final savedImage = await _persistImage(temporaryImage);

      if (!mounted) {
        return;
      }
      setState(() {
        _capturedImage = savedImage;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '拍照失败：${error.description ?? error.code}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '保存照片失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<XFile> _persistImage(XFile image) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final picturesDirectory = Directory(
      '${documentsDirectory.path}/captured_photos',
    );

    if (!await picturesDirectory.exists()) {
      await picturesDirectory.create(recursive: true);
    }

    final fileName =
        'photo_${DateTime.now().millisecondsSinceEpoch}${_fileExtensionFromMime(image.mimeType)}';
    final savedPath = '${picturesDirectory.path}/$fileName';
    await image.saveTo(savedPath);

    return XFile(savedPath, mimeType: image.mimeType, name: fileName);
  }

  String _fileExtensionFromMime(String? mimeType) {
    if (mimeType == 'image/png') {
      return '.png';
    }
    return '.jpg';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
      _initializeControllerFuture = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('CameraPreviewPage'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: CupertinoColors.black,
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isCapturing ? null : _takePhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CupertinoColors.white,
                    border: Border.all(
                      color: CupertinoColors.systemGrey4,
                      width: 4,
                    ),
                  ),
                  child: _isCapturing
                      ? const CupertinoActivityIndicator()
                      : const Icon(
                          CupertinoIcons.camera_fill,
                          color: CupertinoColors.black,
                          size: 32,
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCapturedImage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final initializeFuture = _initializeControllerFuture;
    final controller = _controller;

    if (_errorMessage != null && controller == null) {
      return _buildCenteredText(_errorMessage!);
    }

    if (_isLoadingCamera) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (initializeFuture == null || controller == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            controller.value.isInitialized) {
          return CameraPreview(controller);
        }

        if (snapshot.hasError) {
          return _buildCenteredText('无法打开摄像头');
        }

        return const Center(child: CupertinoActivityIndicator());
      },
    );
  }

  Widget _buildCapturedImage() {
    if (_capturedImage == null) {
      return Container(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Text(
          '拍照后会在这里显示照片',
          style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 15),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  _capturedImage!.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredText(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.white),
        ),
      ),
    );
  }
}
