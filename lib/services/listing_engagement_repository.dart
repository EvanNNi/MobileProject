import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/market_item.dart';
import 'auth_service.dart';

class ListingEngagementRepository {
  ListingEngagementRepository._();

  static final instance = ListingEngagementRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Set<String>> watchFavoriteListingIds() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<Set<String>>.value({});
    }

    return _userDoc(user.uid)
        .collection('favorites')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Stream<bool> watchIsFavorite(String listingId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<bool>.value(false);
    }

    return _userDoc(user.uid)
        .collection('favorites')
        .doc(listingId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<List<String>> watchViewedListingIds() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<List<String>>.value(const []);
    }

    return _userDoc(user.uid).collection('viewHistory').snapshots().map((
      snapshot,
    ) {
      final docs = [...snapshot.docs];
      docs.sort((a, b) {
        final aTime = a.data()['viewedAt'];
        final bTime = b.data()['viewedAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return a.id.compareTo(b.id);
      });
      return docs.map((doc) => doc.id).toList(growable: false);
    });
  }

  Stream<bool> watchIsLiked(String listingId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<bool>.value(false);
    }

    return _userDoc(user.uid)
        .collection('likes')
        .doc(listingId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> toggleFavorite(MarketItem item) async {
    final user = _requireUser();
    final userRef = _userDoc(user.uid);
    final favoriteRef = userRef.collection('favorites').doc(item.id);

    await _firestore.runTransaction((transaction) async {
      final favoriteSnapshot = await transaction.get(favoriteRef);
      if (favoriteSnapshot.exists) {
        transaction.delete(favoriteRef);
        transaction.set(userRef, {
          'favoriteCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      transaction.set(favoriteRef, {
        'listingId': item.id,
        'sellerId': item.sellerId,
        'title': item.title,
        'titleEn': item.titleEn,
        'price': item.price,
        'imageUrls': item.imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'favoriteCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> toggleLike(MarketItem item) async {
    final user = _requireUser();
    final likeRef = _userDoc(user.uid).collection('likes').doc(item.id);
    final listingRef = _firestore.collection('listings').doc(item.id);

    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(listingRef, {
          'likes': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      transaction.set(likeRef, {
        'listingId': item.id,
        'sellerId': item.sellerId,
        'title': item.title,
        'titleEn': item.titleEn,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(listingRef, {
        'likes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> recordView(MarketItem item) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final userRef = _userDoc(user.uid);
    final historyRef = userRef.collection('viewHistory').doc(item.id);
    final listingRef = _firestore.collection('listings').doc(item.id);

    await _firestore.runTransaction((transaction) async {
      final historySnapshot = await transaction.get(historyRef);
      transaction.set(historyRef, {
        'listingId': item.id,
        'sellerId': item.sellerId,
        'title': item.title,
        'titleEn': item.titleEn,
        'price': item.price,
        'imageUrls': item.imageUrls,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!historySnapshot.exists) {
        transaction.set(userRef, {
          'viewedCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.update(listingRef, {
        'views': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthActionException('请先登录，再继续操作。');
    }
    return user;
  }
}
