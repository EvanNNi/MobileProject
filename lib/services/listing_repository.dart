import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/listing_draft.dart';
import 'auth_service.dart';

class ListingPublishResult {
  const ListingPublishResult({
    required this.listingId,
    required this.imageUrls,
  });

  final String listingId;
  final List<String> imageUrls;
}

class ListingRepository {
  ListingRepository._();

  static final ListingRepository instance = ListingRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<ListingPublishResult> publishListing(
    ListingDraft draft, {
    void Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthActionException('请先登录，再发布商品。');
    }

    final listingRef = _firestore.collection('listings').doc();
    final imageUrls = <String>[];
    final uploadableImages = draft.images
        .where((image) => image.path != null && image.path!.isNotEmpty)
        .toList();

    for (var index = 0; index < uploadableImages.length; index++) {
      final image = uploadableImages[index];
      final path = image.path!;
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }

      final ref = _storage
          .ref()
          .child('listing_images')
          .child(user.uid)
          .child(listingRef.id)
          .child('${index + 1}_${image.id}.jpg');
      await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'listingId': listingRef.id,
            'ownerId': user.uid,
            'label': image.label,
          },
        ),
      );
      imageUrls.add(await ref.getDownloadURL());
      onProgress?.call((index + 1) / uploadableImages.length);
    }

    await listingRef.set({
      'sellerId': user.uid,
      'sellerName': user.displayName ?? user.email ?? user.phoneNumber ?? '新用户',
      'title': draft.title,
      'titleEn': draft.titleEn,
      'description': draft.description,
      'descriptionEn': draft.descriptionEn,
      'category': draft.category,
      'condition': draft.condition,
      'brand': draft.brand,
      'model': draft.model,
      'price': draft.suggestedPrice,
      'estimatedLow': draft.estimatedLow,
      'estimatedHigh': draft.estimatedHigh,
      'originalPrice': draft.originalPrice,
      'originalPriceNote': draft.originalPriceNote,
      'confidence': draft.confidence,
      'tags': draft.tags,
      'tagsEn': draft.tagsEn,
      'analysisId': draft.analysisId,
      'aiReasoningBrief': draft.reasoningBrief,
      'aiWarnings': draft.warnings,
      'imageUrls': imageUrls,
      'imageLabels': draft.images.map((image) => image.label).toList(),
      'imageCount': draft.images.length,
      'locationLabel': draft.locationLabel,
      'geo': {'lat': draft.latitude, 'lng': draft.longitude},
      'status': 'active',
      'views': 0,
      'likes': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final userRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final userData = userSnapshot.data();
      final currentCount =
          _intValue(userData, 'listingCount') ??
          _intValue(userData, 'sellerListingCount') ??
          0;
      final nextData = <String, Object?>{
        'listingCount': currentCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (userData?.containsKey('sellerListingCount') ?? false) {
        nextData['sellerListingCount'] = FieldValue.delete();
      }
      transaction.set(userRef, nextData, SetOptions(merge: true));
    });

    return ListingPublishResult(listingId: listingRef.id, imageUrls: imageUrls);
  }

  Future<void> updateListingStatus({
    required String listingId,
    required String status,
  }) async {
    if (!['active', 'inactive', 'sold'].contains(status)) {
      throw const AuthActionException('商品状态不正确。');
    }

    final user = _requireUser();
    final listingRef = _firestore.collection('listings').doc(listingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(listingRef);
      final data = snapshot.data();
      if (data == null) {
        throw const AuthActionException('没有找到这个商品。');
      }
      if (data['sellerId'] != user.uid) {
        throw const AuthActionException('只能管理自己发布的商品。');
      }

      transaction.update(listingRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == 'sold') 'soldAt': FieldValue.serverTimestamp(),
        if (status == 'inactive') 'inactiveAt': FieldValue.serverTimestamp(),
        if (status == 'active') ...{
          'relistedAt': FieldValue.serverTimestamp(),
          'soldAt': FieldValue.delete(),
          'inactiveAt': FieldValue.delete(),
        },
      });
    });
  }

  Future<void> updateListingDetails({
    required String listingId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String brand,
    required String model,
    required int price,
    required String locationLabel,
    required double latitude,
    required double longitude,
  }) async {
    if (title.trim().isEmpty) {
      throw const AuthActionException('商品标题不能为空。');
    }
    if (price <= 0) {
      throw const AuthActionException('商品价格需要大于 0。');
    }

    final user = _requireUser();
    final listingRef = _firestore.collection('listings').doc(listingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(listingRef);
      final data = snapshot.data();
      if (data == null) {
        throw const AuthActionException('没有找到这个商品。');
      }
      if (data['sellerId'] != user.uid) {
        throw const AuthActionException('只能修改自己发布的商品。');
      }

      transaction.update(listingRef, {
        'title': title.trim(),
        'titleEn': FieldValue.delete(),
        'description': description.trim(),
        'descriptionEn': FieldValue.delete(),
        'category': category.trim().isEmpty ? '其他' : category.trim(),
        'condition': condition.trim().isEmpty ? '无法判断' : condition.trim(),
        'brand': brand.trim().isEmpty ? '未知' : brand.trim(),
        'model': model.trim().isEmpty ? '未知' : model.trim(),
        'tagsEn': FieldValue.delete(),
        'price': price,
        'locationLabel': locationLabel.trim(),
        'geo': {'lat': latitude, 'lng': longitude},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthActionException('请先登录，再管理商品。');
    }
    return user;
  }
}

int? _intValue(Map<String, dynamic>? data, String key) {
  final value = data?[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
