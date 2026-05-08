import 'package:flutter/cupertino.dart';

import '../app_theme.dart';

class ListingImage {
  const ListingImage({
    required this.id,
    required this.label,
    this.path,
    this.icon = CupertinoIcons.cube_box_fill,
    this.color = AppPalette.mint,
    this.cropped = false,
    this.compressed = false,
  });

  final String id;
  final String label;
  final String? path;
  final IconData icon;
  final Color color;
  final bool cropped;
  final bool compressed;

  ListingImage copyWith({
    String? id,
    String? label,
    String? path,
    IconData? icon,
    Color? color,
    bool? cropped,
    bool? compressed,
  }) {
    return ListingImage(
      id: id ?? this.id,
      label: label ?? this.label,
      path: path ?? this.path,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      cropped: cropped ?? this.cropped,
      compressed: compressed ?? this.compressed,
    );
  }
}

class RecognizedListingItem {
  const RecognizedListingItem({
    required this.category,
    required this.condition,
    required this.brand,
    required this.model,
    required this.title,
    required this.description,
    this.titleEn = '',
    this.descriptionEn = '',
    required this.confidence,
    this.tags = const [],
    this.tagsEn = const [],
    this.reasoningBrief = '',
    this.warnings = const [],
  });

  final String category;
  final String condition;
  final String brand;
  final String model;
  final String title;
  final String description;
  final String titleEn;
  final String descriptionEn;
  final int confidence;
  final List<String> tags;
  final List<String> tagsEn;
  final String reasoningBrief;
  final List<String> warnings;

  ListingDraft applyToDraft(ListingDraft draft) {
    return draft.copyWith(
      category: category,
      condition: condition,
      brand: brand,
      model: model,
      title: title,
      description: description,
      titleEn: titleEn,
      descriptionEn: descriptionEn,
      confidence: confidence,
      tags: tags,
      tagsEn: tagsEn,
      reasoningBrief: reasoningBrief,
      warnings: warnings,
      recognizedItems: const [],
    );
  }
}

class ListingDraft {
  const ListingDraft({
    this.images = const [],
    this.category = '',
    this.condition = '',
    this.brand = '',
    this.model = '',
    this.title = '',
    this.description = '',
    this.titleEn = '',
    this.descriptionEn = '',
    this.aiSupplement = '',
    this.locationLabel = '',
    this.latitude = 0,
    this.longitude = 0,
    this.estimatedLow = 0,
    this.estimatedHigh = 0,
    this.suggestedPrice = 0,
    this.originalPrice = 0,
    this.originalPriceNote = '',
    this.confidence = 0,
    this.tags = const [],
    this.tagsEn = const [],
    this.analysisId,
    this.reasoningBrief = '',
    this.warnings = const [],
    this.recognizedItems = const [],
  });

  final List<ListingImage> images;
  final String category;
  final String condition;
  final String brand;
  final String model;
  final String title;
  final String description;
  final String titleEn;
  final String descriptionEn;
  final String aiSupplement;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final int estimatedLow;
  final int estimatedHigh;
  final int suggestedPrice;
  final int originalPrice;
  final String originalPriceNote;
  final int confidence;
  final List<String> tags;
  final List<String> tagsEn;
  final String? analysisId;
  final String reasoningBrief;
  final List<String> warnings;
  final List<RecognizedListingItem> recognizedItems;

  ListingDraft copyWith({
    List<ListingImage>? images,
    String? category,
    String? condition,
    String? brand,
    String? model,
    String? title,
    String? description,
    String? titleEn,
    String? descriptionEn,
    String? aiSupplement,
    String? locationLabel,
    double? latitude,
    double? longitude,
    int? estimatedLow,
    int? estimatedHigh,
    int? suggestedPrice,
    int? originalPrice,
    String? originalPriceNote,
    int? confidence,
    List<String>? tags,
    List<String>? tagsEn,
    String? analysisId,
    String? reasoningBrief,
    List<String>? warnings,
    List<RecognizedListingItem>? recognizedItems,
  }) {
    return ListingDraft(
      images: images ?? this.images,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      title: title ?? this.title,
      description: description ?? this.description,
      titleEn: titleEn ?? this.titleEn,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      aiSupplement: aiSupplement ?? this.aiSupplement,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      estimatedLow: estimatedLow ?? this.estimatedLow,
      estimatedHigh: estimatedHigh ?? this.estimatedHigh,
      suggestedPrice: suggestedPrice ?? this.suggestedPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      originalPriceNote: originalPriceNote ?? this.originalPriceNote,
      confidence: confidence ?? this.confidence,
      tags: tags ?? this.tags,
      tagsEn: tagsEn ?? this.tagsEn,
      analysisId: analysisId ?? this.analysisId,
      reasoningBrief: reasoningBrief ?? this.reasoningBrief,
      warnings: warnings ?? this.warnings,
      recognizedItems: recognizedItems ?? this.recognizedItems,
    );
  }
}
