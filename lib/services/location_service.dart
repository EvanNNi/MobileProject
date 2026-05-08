import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'mapbox_config.dart';

class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.detail,
  });

  final double latitude;
  final double longitude;
  final String name;
  final String detail;
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;
}

class LocationService {
  const LocationService._();

  static const instance = LocationService._();

  Future<AppLocation> getCurrentLocation({
    String language = 'zh-Hans',
    String fallbackName = '当前位置',
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('请先在 iPhone 设置中开启定位服务');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('需要允许定位权限，才能查看附近商品');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException('定位权限已被关闭，请到系统设置中重新允许');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    final fallback = _fallbackLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      name: fallbackName,
    );
    final resolved = await _reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
      fallbackName: fallbackName,
      language: language,
    );
    return resolved ?? fallback;
  }

  Future<AppLocation> resolveCoordinates({
    required double latitude,
    required double longitude,
    String fallbackName = '地图选择位置',
    String language = 'zh-Hans',
  }) async {
    final resolved = await _reverseGeocode(
      latitude: latitude,
      longitude: longitude,
      fallbackName: fallbackName,
      language: language,
    );
    return resolved ??
        _fallbackLocation(
          latitude: latitude,
          longitude: longitude,
          name: fallbackName,
        );
  }

  AppLocation _fallbackLocation({
    required double latitude,
    required double longitude,
    required String name,
  }) {
    final latitudeText = latitude.toStringAsFixed(4);
    final longitudeText = longitude.toStringAsFixed(4);
    return AppLocation(
      latitude: latitude,
      longitude: longitude,
      name: name,
      detail: '$latitudeText, $longitudeText',
    );
  }

  Future<AppLocation?> _reverseGeocode({
    required double latitude,
    required double longitude,
    required String fallbackName,
    required String language,
  }) async {
    final token = MapboxConfig.accessToken;
    if (token.isEmpty) {
      return null;
    }

    final uri = Uri.https('api.mapbox.com', '/search/geocode/v6/reverse', {
      'longitude': longitude.toString(),
      'latitude': latitude.toString(),
      'access_token': token,
      'language': language,
      'limit': '1',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final features = payload['features'];
      if (features is! List || features.isEmpty) {
        return null;
      }

      final feature = features.first;
      if (feature is! Map<String, dynamic>) {
        return null;
      }

      final properties = feature['properties'];
      if (properties is! Map<String, dynamic>) {
        return null;
      }

      final name =
          _stringValue(properties['name_preferred']) ??
          _stringValue(properties['name']) ??
          fallbackName;
      final fullAddress =
          _stringValue(properties['full_address']) ??
          _stringValue(properties['place_formatted']) ??
          _stringValue(properties['address']) ??
          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

      return AppLocation(
        latitude: latitude,
        longitude: longitude,
        name: name,
        detail: fullAddress,
      );
    } catch (_) {
      return null;
    }
  }

  String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
