import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<AppUser?> watchCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<AppUser?>.value(null);
    }
    return watchUser(user.uid);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return AppUser.fromFirestore(snapshot.id, data);
    });
  }

  Future<void> ensureUserDocument(User? user, {String? displayName}) async {
    if (user == null) {
      return;
    }

    final docRef = _users.doc(user.uid);
    final snapshot = await docRef.get();
    final now = FieldValue.serverTimestamp();
    final name = _bestDisplayName(user, displayName);
    final authData = <String, Object?>{
      'uid': user.uid,
      'displayName': name,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'photoUrl': user.photoURL,
      'providerIds': user.providerData
          .map((provider) => provider.providerId)
          .toSet()
          .toList(),
      'updatedAt': now,
    };

    if (snapshot.exists) {
      await docRef.set(authData, SetOptions(merge: true));
      return;
    }

    await docRef.set({
      ...authData,
      'bio': '',
      'location': '',
      'favoriteCount': 0,
      'viewedCount': 0,
      'listingCount': 0,
      'createdAt': now,
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? location,
    String? phoneNumber,
    String? email,
  }) {
    return _users.doc(uid).set({
      if (displayName != null) 'displayName': displayName.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (location != null) 'location': location.trim(),
      if (phoneNumber != null) 'phoneNumber': phoneNumber.trim(),
      if (email != null) 'email': email.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

String _bestDisplayName(User user, String? preferredName) {
  final cleanedPreferredName = preferredName?.trim();
  if (cleanedPreferredName != null && cleanedPreferredName.isNotEmpty) {
    return cleanedPreferredName;
  }

  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }

  final email = user.email;
  if (email != null && email.isNotEmpty) {
    return email.split('@').first;
  }

  final phone = user.phoneNumber;
  if (phone != null && phone.isNotEmpty) {
    return phone;
  }

  return '新用户';
}
