import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class UserAddress {
  const UserAddress({
    required this.id,
    required this.name,
    required this.phone,
    required this.region,
    required this.detail,
    required this.tag,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String phone;
  final String region;
  final String detail;
  final String tag;
  final bool isDefault;

  factory UserAddress.fromFirestore(String id, Map<String, dynamic> data) {
    return UserAddress(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      region: data['region'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
      tag: data['tag'] as String? ?? '常用',
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }
}

class AddressRepository {
  AddressRepository._();

  static final instance = AddressRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserAddress>> watchAddresses() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<List<UserAddress>>.value(const []);
    }

    return _addresses(user.uid).snapshots().map((snapshot) {
      final addresses = snapshot.docs
          .map((doc) => UserAddress.fromFirestore(doc.id, doc.data()))
          .toList(growable: false);
      return addresses..sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
    });
  }

  Future<void> addAddress({
    required String name,
    required String phone,
    required String region,
    required String detail,
  }) async {
    final user = _requireUser();
    final addresses = _addresses(user.uid);
    final existing = await addresses.limit(1).get();
    final isDefault = existing.docs.isEmpty;

    await addresses.add({
      'name': name.trim(),
      'phone': phone.trim(),
      'region': region.trim(),
      'detail': detail.trim(),
      'tag': isDefault ? '默认' : '常用',
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setDefault(String addressId) async {
    final user = _requireUser();
    final addresses = _addresses(user.uid);
    final snapshot = await addresses.get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {
        'isDefault': doc.id == addressId,
        'tag': doc.id == addressId ? '默认' : '常用',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> deleteAddress(String addressId) async {
    final user = _requireUser();
    final addresses = _addresses(user.uid);
    final deletedRef = addresses.doc(addressId);
    final deletedSnapshot = await deletedRef.get();
    final wasDefault = deletedSnapshot.data()?['isDefault'] == true;

    await deletedRef.delete();

    if (!wasDefault) {
      return;
    }

    final remaining = await addresses.limit(1).get();
    if (remaining.docs.isNotEmpty) {
      await setDefault(remaining.docs.first.id);
    }
  }

  CollectionReference<Map<String, dynamic>> _addresses(String uid) {
    return _firestore.collection('users').doc(uid).collection('addresses');
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthActionException('请先登录，再管理地址。');
    }
    return user;
  }
}
