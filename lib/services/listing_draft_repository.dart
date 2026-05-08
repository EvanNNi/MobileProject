import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/listing_draft.dart';

enum ListingDraftResumeStage { camera, preview, info, price }

class SavedListingDraft {
  const SavedListingDraft({
    required this.id,
    required this.savedAt,
    required this.draft,
    required this.stage,
  });

  final String id;
  final DateTime savedAt;
  final ListingDraft draft;
  final ListingDraftResumeStage stage;
}

class ListingDraftRepository {
  ListingDraftRepository._();

  static final instance = ListingDraftRepository._();

  Future<String> saveDraft(
    ListingDraft draft, {
    required ListingDraftResumeStage stage,
  }) async {
    final rootDirectory = await _draftRootDirectory();
    final now = DateTime.now();
    final id = 'draft_${now.millisecondsSinceEpoch}';
    final draftDirectory = Directory('${rootDirectory.path}/$id');
    await draftDirectory.create(recursive: true);

    final savedImages = <ListingImage>[];
    for (var index = 0; index < draft.images.length; index++) {
      savedImages.add(
        await _copyImageIntoDraftDirectory(
          draft.images[index],
          draftDirectory,
          index,
        ),
      );
    }

    final savedDraft = draft.copyWith(images: savedImages);
    final file = File('${draftDirectory.path}/draft.json');
    await file.writeAsString(
      jsonEncode({
        'id': id,
        'savedAt': now.toIso8601String(),
        'stage': stage.name,
        'draft': _draftToJson(savedDraft),
      }),
    );

    return id;
  }

  Future<List<SavedListingDraft>> loadDrafts() async {
    final rootDirectory = await _draftRootDirectory();
    if (!await rootDirectory.exists()) {
      return const [];
    }

    final drafts = <SavedListingDraft>[];
    await for (final entity in rootDirectory.list()) {
      if (entity is! Directory) {
        continue;
      }

      final file = File('${entity.path}/draft.json');
      if (!await file.exists()) {
        continue;
      }

      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) {
          continue;
        }
        final data = Map<String, dynamic>.from(decoded);
        final draftData = data['draft'];
        if (draftData is! Map) {
          continue;
        }
        drafts.add(
          SavedListingDraft(
            id: _stringValue(
              data['id'],
              entity.path.split(Platform.pathSeparator).last,
            ),
            savedAt:
                DateTime.tryParse(_stringValue(data['savedAt'], '')) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            draft: _draftFromJson(Map<String, dynamic>.from(draftData)),
            stage: _stageFromJson(data['stage']),
          ),
        );
      } catch (_) {
        // A corrupt local draft should not break the draft box.
      }
    }

    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }

  Future<void> deleteDraft(String id) async {
    final rootDirectory = await _draftRootDirectory();
    final directory = Directory('${rootDirectory.path}/$id');
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> deleteWorkingFiles(ListingDraft draft) async {
    final draftRootDirectory = await _draftRootDirectory();
    final draftRootPath = '${draftRootDirectory.path}/';

    for (final image in draft.images) {
      final path = image.path;
      if (path == null || path.isEmpty || path.startsWith(draftRootPath)) {
        continue;
      }

      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best effort cleanup only. Navigation should not be blocked by this.
      }
    }
  }

  Future<Directory> _draftRootDirectory() async {
    final directory = await getApplicationSupportDirectory();
    final draftsDirectory = Directory('${directory.path}/listing_drafts');
    if (!await draftsDirectory.exists()) {
      await draftsDirectory.create(recursive: true);
    }
    return draftsDirectory;
  }

  Future<ListingImage> _copyImageIntoDraftDirectory(
    ListingImage image,
    Directory draftDirectory,
    int index,
  ) async {
    final path = image.path;
    if (path == null || path.isEmpty) {
      return image;
    }

    try {
      final sourceFile = File(path);
      if (!await sourceFile.exists()) {
        return image;
      }

      final savedFile = await sourceFile.copy(
        '${draftDirectory.path}/image_$index.jpg',
      );
      return image.copyWith(path: savedFile.path);
    } catch (_) {
      return image;
    }
  }

  Map<String, dynamic> _draftToJson(ListingDraft draft) {
    return {
      'images': draft.images.map(_imageToJson).toList(),
      'category': draft.category,
      'condition': draft.condition,
      'brand': draft.brand,
      'model': draft.model,
      'title': draft.title,
      'titleEn': draft.titleEn,
      'description': draft.description,
      'descriptionEn': draft.descriptionEn,
      'aiSupplement': draft.aiSupplement,
      'locationLabel': draft.locationLabel,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'estimatedLow': draft.estimatedLow,
      'estimatedHigh': draft.estimatedHigh,
      'suggestedPrice': draft.suggestedPrice,
      'originalPrice': draft.originalPrice,
      'originalPriceNote': draft.originalPriceNote,
      'confidence': draft.confidence,
      'tags': draft.tags,
      'tagsEn': draft.tagsEn,
      'analysisId': draft.analysisId,
      'reasoningBrief': draft.reasoningBrief,
      'warnings': draft.warnings,
    };
  }

  Map<String, dynamic> _imageToJson(ListingImage image) {
    return {
      'id': image.id,
      'label': image.label,
      'path': image.path,
      'cropped': image.cropped,
      'compressed': image.compressed,
    };
  }

  ListingDraft _draftFromJson(Map<String, dynamic> json) {
    return ListingDraft(
      images: _imageListValue(json['images']),
      category: _stringValue(json['category'], ''),
      condition: _stringValue(json['condition'], ''),
      brand: _stringValue(json['brand'], ''),
      model: _stringValue(json['model'], ''),
      title: _stringValue(json['title'], ''),
      titleEn: _stringValue(json['titleEn'], ''),
      description: _stringValue(json['description'], ''),
      descriptionEn: _stringValue(json['descriptionEn'], ''),
      aiSupplement: _stringValue(json['aiSupplement'], ''),
      locationLabel: _stringValue(json['locationLabel'], ''),
      latitude: _doubleValue(json['latitude'], 0),
      longitude: _doubleValue(json['longitude'], 0),
      estimatedLow: _intValue(json['estimatedLow'], 0),
      estimatedHigh: _intValue(json['estimatedHigh'], 0),
      suggestedPrice: _intValue(json['suggestedPrice'], 0),
      originalPrice: _intValue(json['originalPrice'], 0),
      originalPriceNote: _stringValue(json['originalPriceNote'], ''),
      confidence: _intValue(json['confidence'], 0),
      tags: _stringListValue(json['tags']),
      tagsEn: _stringListValue(json['tagsEn']),
      analysisId: json['analysisId'] is String
          ? json['analysisId'] as String
          : null,
      reasoningBrief: _stringValue(json['reasoningBrief'], ''),
      warnings: _stringListValue(json['warnings']),
    );
  }

  List<ListingImage> _imageListValue(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => _imageFromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  ListingImage _imageFromJson(Map<String, dynamic> json) {
    return ListingImage(
      id: _stringValue(json['id'], 'draft-image'),
      label: _stringValue(json['label'], '图片'),
      path: json['path'] as String?,
      cropped: _boolValue(json['cropped']),
      compressed: _boolValue(json['compressed']),
    );
  }

  List<String> _stringListValue(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().toList();
  }

  String _stringValue(Object? value, String fallback) {
    if (value is String) {
      return value;
    }
    return fallback;
  }

  int _intValue(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return fallback;
  }

  double _doubleValue(Object? value, double fallback) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    return false;
  }

  ListingDraftResumeStage _stageFromJson(Object? value) {
    if (value is String) {
      for (final stage in ListingDraftResumeStage.values) {
        if (stage.name == value) {
          return stage;
        }
      }
    }
    return ListingDraftResumeStage.preview;
  }
}
