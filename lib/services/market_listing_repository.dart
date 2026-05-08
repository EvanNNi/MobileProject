import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../models/market_item.dart';

class MarketListingRepository {
  MarketListingRepository._();

  static final instance = MarketListingRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west2',
  );
  final Set<String> _translationRequests = <String>{};

  Stream<List<MarketItem>> watchActiveListings() {
    return _firestore
        .collection('listings')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(_fromDocument)
              .whereType<MarketItem>()
              .toList(growable: false);
        });
  }

  Stream<MarketItem?> watchListing(String listingId) {
    return _firestore.collection('listings').doc(listingId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return _fromData(snapshot.id, data);
    });
  }

  Stream<List<MarketItem>> watchMyListings() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <MarketItem>[]);
    }

    return _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((document) {
                return _fromData(
                  document.id,
                  document.data(),
                  includeInactive: true,
                );
              })
              .whereType<MarketItem>()
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  MarketItem? _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return _fromData(document.id, document.data());
  }

  MarketItem? _fromData(
    String documentId,
    Map<String, dynamic> data, {
    bool includeInactive = false,
  }) {
    final status = _stringValue(data['status']) ?? 'active';
    if (!includeInactive && status != 'active') {
      return null;
    }

    final geo = data['geo'];
    final geoPoint = _geoPoint(geo);
    final category = _stringValue(data['category']) ?? '推荐';
    final title = _stringValue(data['title']) ?? '未命名商品';
    final description = _stringValue(data['description']) ?? '';

    _maybeRequestEnglishBackfill(
      listingId: documentId,
      title: title,
      description: description,
      titleEn: _stringValue(data['titleEn']) ?? '',
      descriptionEn: _stringValue(data['descriptionEn']) ?? '',
    );

    return MarketItem(
      id: documentId,
      title: title,
      titleEn: _stringValue(data['titleEn']) ?? '',
      category: category,
      brand: _stringValue(data['brand']) ?? '未知品牌',
      model: _stringValue(data['model']) ?? '未知型号',
      condition: _stringValue(data['condition']) ?? '轻微使用',
      price: _intValue(data['price']) ?? 0,
      distance: 0,
      seller: _stringValue(data['sellerName']) ?? '卖家',
      sellerId: _stringValue(data['sellerId']) ?? '',
      location: _stringValue(data['locationLabel']) ?? '未知位置',
      latitude: geoPoint.$1,
      longitude: geoPoint.$2,
      mapX: 0.5,
      mapY: 0.5,
      description: description,
      descriptionEn: _stringValue(data['descriptionEn']) ?? '',
      views: _intValue(data['views']) ?? 0,
      likes: _intValue(data['likes']) ?? 0,
      icon: _iconForCategory(category),
      color: _colorForCategory(category),
      imageUrls: _stringList(data['imageUrls']),
      tags: _stringList(data['tags']),
      tagsEn: _stringList(data['tagsEn']),
      status: status,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  void _maybeRequestEnglishBackfill({
    required String listingId,
    required String title,
    required String description,
    required String titleEn,
    required String descriptionEn,
  }) {
    if (titleEn.isNotEmpty && descriptionEn.isNotEmpty) {
      return;
    }
    if (!_containsCjk(title) && !_containsCjk(description)) {
      return;
    }
    if (!_translationRequests.add(listingId)) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _translationRequests.remove(listingId);
      return;
    }

    unawaited(_requestEnglishBackfill(listingId: listingId, user: user));
  }

  Future<void> _requestEnglishBackfill({
    required String listingId,
    required User user,
  }) async {
    try {
      final authToken = await _refreshIdToken(user);
      await _functions
          .httpsCallable(
            'translateListingText',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call<Map<dynamic, dynamic>>({
            'listingId': listingId,
            'authToken': authToken,
          });
    } catch (_) {
      _translationRequests.remove(listingId);
    }
  }

  Future<String> _refreshIdToken(User user) async {
    final token = await user.getIdToken();
    return token ?? '';
  }

  bool _containsCjk(String value) {
    return RegExp('[\u3400-\u9fff]').hasMatch(value);
  }

  (double, double) _geoPoint(Object? value) {
    if (value is GeoPoint) {
      return (value.latitude, value.longitude);
    }
    if (value is Map) {
      final latitude = _doubleValue(value['lat'] ?? value['latitude']);
      final longitude = _doubleValue(value['lng'] ?? value['longitude']);
      if (latitude != null && longitude != null) {
        return (latitude, longitude);
      }
    }
    return (0, 0);
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
  }

  String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double? _doubleValue(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime? _dateValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  IconData _iconForCategory(String category) {
    if (category.contains('数码') || category.contains('耳机')) {
      return CupertinoIcons.headphones;
    }
    if (category.contains('相机') || category.contains('摄影')) {
      return CupertinoIcons.camera_fill;
    }
    if (category.contains('鞋')) {
      return CupertinoIcons.tag_fill;
    }
    if (category.contains('包') || category.contains('箱')) {
      return CupertinoIcons.bag_fill;
    }
    if (category.contains('家具')) {
      return CupertinoIcons.house_fill;
    }
    return CupertinoIcons.cube_box_fill;
  }

  Color _colorForCategory(String category) {
    if (category.contains('数码') || category.contains('相机')) {
      return AppPalette.mint;
    }
    if (category.contains('家具') || category.contains('包')) {
      return AppPalette.yellow;
    }
    return AppPalette.warmAccent;
  }
}
