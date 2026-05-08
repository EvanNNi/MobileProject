import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/listing_draft.dart';

class AiListingAnalysisException implements Exception {
  const AiListingAnalysisException(this.message);

  final String message;
}

enum AiListingAnalysisStage {
  recognition,
  pricing;

  String get wireName {
    switch (this) {
      case AiListingAnalysisStage.recognition:
        return 'recognition';
      case AiListingAnalysisStage.pricing:
        return 'pricing';
    }
  }
}

class AiListingAnalysisService {
  AiListingAnalysisService._();

  static final instance = AiListingAnalysisService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );

  Future<ListingDraft> analyzeDraft(
    ListingDraft draft, {
    AiListingAnalysisStage stage = AiListingAnalysisStage.pricing,
    String? userConditionHint,
    void Function(double progress)? onProgress,
  }) async {
    final user = await _requireAuthenticatedUser();

    final uploadableImages = draft.images
        .where((image) => image.path != null && image.path!.isNotEmpty)
        .take(4)
        .toList();
    if (uploadableImages.isEmpty) {
      throw const AiListingAnalysisException('请先拍照或从相册选择至少一张商品图片。');
    }

    final imagePaths = <String>[];
    final analysisFolder = 'analysis_${DateTime.now().millisecondsSinceEpoch}';

    for (var index = 0; index < uploadableImages.length; index++) {
      final image = uploadableImages[index];
      final file = File(image.path!);
      if (!await file.exists()) {
        continue;
      }

      final ref = _storage
          .ref()
          .child('listing_images')
          .child(user.uid)
          .child(analysisFolder)
          .child('${index + 1}_${_safeFileName(image.id)}.jpg');
      final snapshot = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'purpose': 'ai_listing_analysis',
            'ownerId': user.uid,
            'label': image.label,
          },
        ),
      );
      imagePaths.add(snapshot.ref.fullPath);
      onProgress?.call((index + 1) / uploadableImages.length * 0.55);
    }

    if (imagePaths.isEmpty) {
      throw const AiListingAnalysisException('没有找到可上传的商品图片。');
    }

    try {
      final authToken = await _refreshIdToken(user);
      final response = await _callAnalyzeListing(
        imagePaths: imagePaths,
        draft: draft,
        stage: stage,
        userConditionHint: userConditionHint,
        authToken: authToken,
      );
      onProgress?.call(1);
      return _applyAnalysisResult(draft, response.data, stage: stage);
    } on AiListingAnalysisException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        final refreshedUser = await _requireAuthenticatedUser();
        final authToken = await _refreshIdToken(refreshedUser);
        try {
          final response = await _callAnalyzeListing(
            imagePaths: imagePaths,
            draft: draft,
            stage: stage,
            userConditionHint: userConditionHint,
            authToken: authToken,
          );
          onProgress?.call(1);
          return _applyAnalysisResult(draft, response.data, stage: stage);
        } on FirebaseFunctionsException catch (retryError) {
          throw AiListingAnalysisException(_functionsErrorMessage(retryError));
        }
      }
      throw AiListingAnalysisException(_functionsErrorMessage(error));
    } catch (error) {
      throw AiListingAnalysisException('AI 估价失败：$error');
    }
  }

  Future<User> _requireAuthenticatedUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      throw const AiListingAnalysisException('请先登录，再使用 AI 识别和估价。');
    }

    try {
      await user.reload();
      user = _auth.currentUser;
    } on FirebaseAuthException catch (error) {
      throw AiListingAnalysisException(_authErrorMessage(error));
    }

    if (user == null) {
      throw const AiListingAnalysisException('登录状态已失效，请重新登录后再试。');
    }
    return user;
  }

  Future<String> _refreshIdToken(User user) async {
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const AiListingAnalysisException('登录凭证为空，请重新登录后再试。');
      }
      return token;
    } on FirebaseAuthException catch (error) {
      throw AiListingAnalysisException(_authErrorMessage(error));
    }
  }

  Future<HttpsCallableResult<Map<dynamic, dynamic>>> _callAnalyzeListing({
    required List<String> imagePaths,
    required ListingDraft draft,
    required AiListingAnalysisStage stage,
    required String? userConditionHint,
    required String authToken,
  }) {
    final callable = _functions.httpsCallable(
      'analyzeListing',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    return callable.call<Map<dynamic, dynamic>>({
      'imagePaths': imagePaths,
      'currency': 'GBP',
      'locationLabel': draft.locationLabel,
      'analysisStage': stage.wireName,
      'authToken': authToken,
      if (stage == AiListingAnalysisStage.pricing) ...{
        'userConditionHint': userConditionHint ?? draft.condition,
        'userEditedFields': {
          'category': draft.category,
          'brand': draft.brand,
          'model': draft.model,
          'condition': draft.condition,
          'title': draft.title,
          'description': draft.description,
          'titleEn': draft.titleEn,
          'descriptionEn': draft.descriptionEn,
        },
      },
    });
  }

  String _functionsErrorMessage(FirebaseFunctionsException error) {
    if (error.code == 'unauthenticated') {
      return '登录状态没有传给 AI 后端。请退出账号后重新登录，再试一次 AI 识别。';
    }
    if (error.code == 'permission-denied') {
      return '当前账号没有权限使用 AI 估价，请确认已经登录。';
    }
    if (error.code == 'not-found') {
      return error.message ?? 'AI 估价使用的图片没有上传成功，请重新选择图片。';
    }
    if (error.code == 'invalid-argument') {
      return error.message ?? '图片参数不正确，请重新选择 1-4 张商品图片。';
    }
    if (error.code == 'deadline-exceeded') {
      return 'AI 估价超时了，请减少图片数量或稍后再试。';
    }
    if (error.code == 'unavailable') {
      return 'AI 后端暂时不可用，请稍后再试。';
    }
    return error.message ?? 'AI 估价失败，请稍后再试。';
  }

  String _authErrorMessage(FirebaseAuthException error) {
    if (error.code == 'user-token-expired') {
      return '登录状态已过期，请重新登录后再试。';
    }
    if (error.code == 'user-disabled') {
      return '该账号已被禁用，无法使用 AI 估价。';
    }
    if (error.code == 'network-request-failed') {
      return '网络连接失败，无法刷新登录状态。';
    }
    return error.message ?? '登录状态异常，请重新登录后再试。';
  }

  ListingDraft _applyAnalysisResult(
    ListingDraft draft,
    Map<dynamic, dynamic> rawData, {
    required AiListingAnalysisStage stage,
  }) {
    final data = Map<String, dynamic>.from(rawData);
    final low = _intValue(data['estimatedLow'], draft.estimatedLow);
    final high = _intValue(data['estimatedHigh'], draft.estimatedHigh);
    final normalizedLow = low <= high ? low : high;
    final normalizedHigh = high >= low ? high : low;
    final suggested = _intValue(
      data['suggestedPrice'],
      draft.suggestedPrice,
    ).clamp(normalizedLow, normalizedHigh).toInt();

    final recognizedDraft = draft.copyWith(
      category: _stringValue(data['category'], draft.category),
      brand: _stringValue(data['brand'], draft.brand),
      model: _stringValue(data['model'], draft.model),
      condition: _stringValue(data['condition'], draft.condition),
      confidence: _confidencePercent(data['confidence'], draft.confidence),
      title: _stringValue(data['title'], draft.title),
      description: _stringValue(data['description'], draft.description),
      titleEn: _stringValue(data['titleEn'], draft.titleEn),
      descriptionEn: _stringValue(data['descriptionEn'], draft.descriptionEn),
      originalPrice: _intValue(data['originalPrice'], draft.originalPrice),
      originalPriceNote: _stringValue(
        data['originalPriceNote'],
        draft.originalPriceNote,
      ),
      tags: _stringList(data['tags'], draft.tags),
      tagsEn: _stringList(data['tagsEn'], draft.tagsEn),
      reasoningBrief: _stringValue(
        data['reasoningBrief'],
        draft.reasoningBrief,
      ),
      warnings: _stringList(data['warnings'], draft.warnings),
      recognizedItems: _recognizedItems(data['recognizedItems']),
    );

    if (stage == AiListingAnalysisStage.recognition) {
      return recognizedDraft;
    }

    return recognizedDraft.copyWith(
      estimatedLow: normalizedLow,
      estimatedHigh: normalizedHigh,
      suggestedPrice: suggested,
      analysisId: _stringValue(data['analysisId'], draft.analysisId ?? ''),
    );
  }

  String _safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return safe.isEmpty ? 'image' : safe;
  }

  String _stringValue(Object? value, String fallback) {
    if (value is! String) {
      return fallback;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  List<String> _stringList(Object? value, List<String> fallback) {
    if (value is! List) {
      return fallback;
    }
    final values = value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? fallback : values;
  }

  List<RecognizedListingItem> _recognizedItems(Object? value) {
    if (value is! List) {
      return const [];
    }

    final items = <RecognizedListingItem>[];
    for (final rawItem in value) {
      if (rawItem is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(rawItem);
      final title = _stringValue(item['title'], '');
      final brand = _stringValue(item['brand'], '未知');
      final model = _stringValue(item['model'], '未知');
      final category = _stringValue(item['category'], '其他');
      final hasUsefulIdentity =
          title.isNotEmpty ||
          (brand != '未知' && brand.isNotEmpty) ||
          (model != '未知' && model.isNotEmpty);
      if (!hasUsefulIdentity) {
        continue;
      }

      items.add(
        RecognizedListingItem(
          category: category,
          condition: _stringValue(item['condition'], '无法判断'),
          brand: brand,
          model: model,
          title: title.isEmpty ? '$brand $model'.trim() : title,
          description: _stringValue(item['description'], ''),
          titleEn: _stringValue(item['titleEn'], ''),
          descriptionEn: _stringValue(item['descriptionEn'], ''),
          confidence: _confidencePercent(item['confidence'], 0),
          tags: _stringList(item['tags'], const []),
          tagsEn: _stringList(item['tagsEn'], const []),
          reasoningBrief: _stringValue(item['reasoningBrief'], ''),
          warnings: _stringList(item['warnings'], const []),
        ),
      );
    }

    return items;
  }

  int _intValue(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _confidencePercent(Object? value, int fallback) {
    if (value is num) {
      final percent = value <= 1 ? value * 100 : value;
      return percent.round().clamp(0, 100).toInt();
    }
    return fallback.clamp(0, 100).toInt();
  }
}
