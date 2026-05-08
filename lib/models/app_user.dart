class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    this.bio = '',
    this.location = '',
    this.creditScore,
    this.rating,
    this.favoriteCount = 0,
    this.viewedCount = 0,
    this.listingCount = 0,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;
  final String bio;
  final String location;
  final int? creditScore;
  final double? rating;
  final int favoriteCount;
  final int viewedCount;
  final int listingCount;

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      displayName: _stringValue(data, 'displayName') ?? '新用户',
      email: _stringValue(data, 'email'),
      phoneNumber: _stringValue(data, 'phoneNumber'),
      photoUrl: _stringValue(data, 'photoUrl'),
      bio: _stringValue(data, 'bio') ?? '',
      location: _stringValue(data, 'location') ?? '',
      creditScore: _intValue(data, 'creditScore'),
      rating: _doubleValue(data, 'rating'),
      favoriteCount: _intValue(data, 'favoriteCount') ?? 0,
      viewedCount: _intValue(data, 'viewedCount') ?? 0,
      listingCount:
          _intValue(data, 'listingCount') ??
          _intValue(data, 'sellerListingCount') ??
          0,
    );
  }
}

String? _stringValue(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

int? _intValue(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _doubleValue(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
