class MapboxConfig {
  const MapboxConfig._();

  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
}
