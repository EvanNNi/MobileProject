import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'location_service.dart';

class BrowseLocation {
  const BrowseLocation({
    required this.id,
    required this.name,
    required this.detail,
    required this.latitude,
    required this.longitude,
    this.updatedAtMillis = 0,
  });

  const BrowseLocation.pending()
    : id = 'pending',
      name = '选位置',
      detail = '使用当前定位或选择常用位置',
      latitude = 0,
      longitude = 0,
      updatedAtMillis = 0;

  final String id;
  final String name;
  final String detail;
  final double latitude;
  final double longitude;
  final int updatedAtMillis;

  factory BrowseLocation.fromCurrentLocation(AppLocation location) {
    return BrowseLocation(
      id: _idForCoordinates(location.latitude, location.longitude),
      name: location.name,
      detail: location.detail,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  factory BrowseLocation.fromFirestore(String id, Map<String, dynamic> data) {
    final geoPoint = _geoPoint(data['geo']);
    return BrowseLocation(
      id: id,
      name: _stringValue(data['name']) ?? '常用位置',
      detail: _stringValue(data['detail']) ?? '已保存的位置',
      latitude: geoPoint.$1,
      longitude: geoPoint.$2,
      updatedAtMillis: _timestampMillis(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'detail': detail,
      'geo': {'lat': latitude, 'lng': longitude},
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String _idForCoordinates(double latitude, double longitude) {
    final latitudeKey = (latitude * 1000).round().toString().replaceAll(
      '-',
      'm',
    );
    final longitudeKey = (longitude * 1000).round().toString().replaceAll(
      '-',
      'm',
    );
    return 'loc_${latitudeKey}_$longitudeKey';
  }

  static (double, double) _geoPoint(Object? value) {
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

  static double? _doubleValue(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _timestampMillis(Object? value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    return 0;
  }
}

class BrowseLocationRepository {
  BrowseLocationRepository._();

  static final instance = BrowseLocationRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BrowseLocation>> watchLocations() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<List<BrowseLocation>>.value(const []);
    }

    return _locations(user.uid).limit(20).snapshots().map((snapshot) {
      final locations = snapshot.docs
          .map((doc) => BrowseLocation.fromFirestore(doc.id, doc.data()))
          .where(
            (location) => location.latitude != 0 || location.longitude != 0,
          )
          .toList(growable: false);

      return locations
        ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    });
  }

  Future<BrowseLocation> saveCurrentLocation(AppLocation location) async {
    return saveLocation(location);
  }

  Future<BrowseLocation> saveLocation(AppLocation location) async {
    final browseLocation = BrowseLocation.fromCurrentLocation(location);
    final user = _auth.currentUser;
    if (user == null) {
      return browseLocation;
    }

    final ref = _locations(user.uid).doc(browseLocation.id);
    final snapshot = await ref.get();
    final payload = browseLocation.toFirestore();
    if (!snapshot.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(payload, SetOptions(merge: true));
    return browseLocation;
  }

  Future<void> touchLocation(String locationId) async {
    final user = _auth.currentUser;
    if (user == null || locationId.isEmpty) {
      return;
    }

    await _locations(user.uid).doc(locationId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> _locations(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('browseLocations');
  }
}
