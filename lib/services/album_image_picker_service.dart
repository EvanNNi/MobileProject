import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app_theme.dart';
import '../models/listing_draft.dart';

class AlbumPickerException implements Exception {
  const AlbumPickerException(this.message);

  final String message;
}

class AlbumImagePickerService {
  AlbumImagePickerService._();

  static final instance = AlbumImagePickerService._();

  final ImagePicker _picker = ImagePicker();

  Future<List<ListingImage>> pickListingImages({
    required int remainingSlots,
    required int startIndex,
  }) async {
    if (remainingSlots <= 0) {
      return const [];
    }

    try {
      final pickedImages = await _picker.pickMultiImage(
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 82,
        limit: remainingSlots,
        requestFullMetadata: false,
      );

      if (pickedImages.isEmpty) {
        return const [];
      }

      final savedImages = <ListingImage>[];
      final directory = await _albumDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (
        var index = 0;
        index < pickedImages.length && index < remainingSlots;
        index++
      ) {
        final picked = pickedImages[index];
        final savedFile = await _copyImageToAppDirectory(
          picked,
          directory,
          timestamp,
          index,
        );
        savedImages.add(
          ListingImage(
            id: 'album-$timestamp-$index',
            label: _labelForIndex(startIndex + index),
            path: savedFile.path,
            icon: CupertinoIcons.photo_fill,
            color: _colorForIndex(startIndex + index),
            compressed: true,
          ),
        );
      }

      return savedImages;
    } on AlbumPickerException {
      rethrow;
    } on PlatformException catch (error) {
      throw AlbumPickerException(_mapPlatformError(error));
    } catch (error) {
      throw AlbumPickerException('读取相册失败：$error');
    }
  }

  Future<Directory> _albumDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory('${documentsDirectory.path}/listing_album');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _copyImageToAppDirectory(
    XFile image,
    Directory directory,
    int timestamp,
    int index,
  ) async {
    final sourceFile = File(image.path);
    if (!await sourceFile.exists()) {
      throw const AlbumPickerException('没有找到选中的照片文件');
    }

    final fileName = 'album_${timestamp}_$index.jpg';
    return sourceFile.copy('${directory.path}/$fileName');
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

  Color _colorForIndex(int index) {
    const colors = [AppPalette.mint, AppPalette.yellow, AppPalette.warmAccent];
    return colors[index % colors.length];
  }

  String _mapPlatformError(PlatformException error) {
    switch (error.code) {
      case 'photo_access_denied':
      case 'photo_access_restricted':
      case 'permission_denied':
        return '相册权限未开启，请前往设置允许访问照片。';
      case 'multiple_request':
        return '相册正在打开，请稍等一下。';
      default:
        return error.message ?? '无法打开相册，请稍后再试。';
    }
  }
}
