import 'package:flutter/cupertino.dart';

class MarketItem {
  const MarketItem({
    required this.id,
    required this.title,
    this.titleEn = '',
    required this.category,
    required this.brand,
    required this.model,
    required this.condition,
    required this.price,
    required this.distance,
    required this.seller,
    this.sellerId = '',
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.mapX,
    required this.mapY,
    required this.description,
    this.descriptionEn = '',
    required this.views,
    required this.likes,
    required this.icon,
    required this.color,
    this.imageUrls = const [],
    this.tags = const [],
    this.tagsEn = const [],
    this.isFavorite = false,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String titleEn;
  final String category;
  final String brand;
  final String model;
  final String condition;
  final int price;
  final double distance;
  final String seller;
  final String sellerId;
  final String location;
  final double latitude;
  final double longitude;
  final double mapX;
  final double mapY;
  final String description;
  final String descriptionEn;
  final int views;
  final int likes;
  final IconData icon;
  final Color color;
  final List<String> imageUrls;
  final List<String> tags;
  final List<String> tagsEn;
  final bool isFavorite;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MarketItem copyWith({
    bool? isFavorite,
    int? likes,
    int? views,
    double? distance,
    List<String>? imageUrls,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MarketItem(
      id: id,
      title: title,
      titleEn: titleEn,
      category: category,
      brand: brand,
      model: model,
      condition: condition,
      price: price,
      distance: distance ?? this.distance,
      seller: seller,
      sellerId: sellerId,
      location: location,
      latitude: latitude,
      longitude: longitude,
      mapX: mapX,
      mapY: mapY,
      description: description,
      descriptionEn: descriptionEn,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      icon: icon,
      color: color,
      imageUrls: imageUrls ?? this.imageUrls,
      tags: tags,
      tagsEn: tagsEn,
      isFavorite: isFavorite ?? this.isFavorite,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const List<String> marketCategories = ['推荐', '数码', '球鞋', '箱包', '相机', '家具'];
const List<String> marketConditions = ['全部', '全新', '几乎全新', '轻微使用', '明显使用'];
const List<String> marketBrands = [
  '全部',
  'Apple',
  'Sony',
  'Nike',
  'Canon',
  'IKEA',
];
