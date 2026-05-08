import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../models/chat_models.dart';
import '../models/market_item.dart';
import 'auth_service.dart';

class ChatRepository {
  ChatRepository._();

  static final ChatRepository instance = ChatRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  Stream<List<ChatConversation>> watchConversations() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<List<ChatConversation>>.value(const []);
    }

    return _conversations
        .where('participantIds', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => _conversationFromDocument(doc, user.uid))
              .whereType<ChatConversation>()
              .toList();
          conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return conversations;
        });
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ChatMessage(
              id: doc.id,
              conversationId: conversationId,
              senderId: data['senderId'] as String? ?? '',
              text: data['text'] as String? ?? '',
              sentAt: _dateValue(data['sentAt']) ?? DateTime.now(),
              isRead: data['isRead'] as bool? ?? false,
              kind: _messageKind(data['kind'] as String?),
              imageUrl: data['imageUrl'] as String?,
            );
          }).toList();
        });
  }

  Future<void> markConversationRead(String conversationId) async {
    final user = _auth.currentUser;
    if (user == null || conversationId.isEmpty) {
      return;
    }

    final conversationRef = _conversations.doc(conversationId);
    final snapshot = await conversationRef.get();
    if (!snapshot.exists) {
      return;
    }

    await conversationRef.set({
      'unreadCounts': {user.uid: 0},
    }, SetOptions(merge: true));
  }

  Future<void> sendText({
    required ChatConversation conversation,
    required ChatParticipant currentParticipant,
    required ChatParticipant otherParticipant,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthActionException('请先登录，再发送消息。');
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final conversationRef = _conversations.doc(conversation.id);
    final messageRef = conversationRef.collection('messages').doc();
    final now = FieldValue.serverTimestamp();
    final buyerId = _resolvedParticipantId(
      conversation.buyer.id,
      currentParticipant.id,
    );
    final sellerId = _resolvedParticipantId(
      conversation.seller.id,
      currentParticipant.id,
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(conversationRef, {
        'id': conversation.id,
        'participantIds': [currentParticipant.id, otherParticipant.id],
        'participantNames': {
          currentParticipant.id: currentParticipant.name,
          otherParticipant.id: otherParticipant.name,
        },
        'buyerId': buyerId,
        'sellerId': sellerId,
        'item': {
          'id': conversation.item.id,
          'title': conversation.item.title,
          'titleEn': conversation.item.titleEn,
          'price': conversation.item.price,
          'category': conversation.item.category,
          'condition': conversation.item.condition,
          'descriptionEn': conversation.item.descriptionEn,
          'location': conversation.item.location,
          'seller': conversation.item.seller,
          'sellerId': conversation.item.sellerId,
          'imageUrls': conversation.item.imageUrls,
        },
        'statusLabel': conversation.statusLabel,
        'unreadCounts': {
          currentParticipant.id: 0,
          otherParticipant.id: FieldValue.increment(1),
        },
        'lastMessage': trimmedText,
        'lastSenderId': currentParticipant.id,
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      transaction.set(messageRef, {
        'senderId': currentParticipant.id,
        'senderName': currentParticipant.name,
        'text': trimmedText,
        'kind': kind.name,
        'isRead': false,
        'sentAt': now,
      });
    });
  }

  Future<void> sendImage({
    required ChatConversation conversation,
    required ChatParticipant currentParticipant,
    required ChatParticipant otherParticipant,
    required File imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthActionException('请先登录，再发送图片。');
    }
    if (!await imageFile.exists()) {
      throw const AuthActionException('图片文件不存在，请重新选择。');
    }

    final conversationRef = _conversations.doc(conversation.id);
    final messageRef = conversationRef.collection('messages').doc();
    final storageRef = _storage
        .ref()
        .child('chat_images')
        .child(conversation.id)
        .child(user.uid)
        .child('${messageRef.id}.jpg');

    await storageRef.putFile(
      imageFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'conversationId': conversation.id,
          'senderId': user.uid,
        },
      ),
    );
    final imageUrl = await storageRef.getDownloadURL();
    final now = FieldValue.serverTimestamp();
    final buyerId = _resolvedParticipantId(
      conversation.buyer.id,
      currentParticipant.id,
    );
    final sellerId = _resolvedParticipantId(
      conversation.seller.id,
      currentParticipant.id,
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(conversationRef, {
        'id': conversation.id,
        'participantIds': [currentParticipant.id, otherParticipant.id],
        'participantNames': {
          currentParticipant.id: currentParticipant.name,
          otherParticipant.id: otherParticipant.name,
        },
        'buyerId': buyerId,
        'sellerId': sellerId,
        'item': {
          'id': conversation.item.id,
          'title': conversation.item.title,
          'titleEn': conversation.item.titleEn,
          'price': conversation.item.price,
          'category': conversation.item.category,
          'condition': conversation.item.condition,
          'descriptionEn': conversation.item.descriptionEn,
          'location': conversation.item.location,
          'seller': conversation.item.seller,
          'sellerId': conversation.item.sellerId,
          'imageUrls': conversation.item.imageUrls,
        },
        'statusLabel': conversation.statusLabel,
        'unreadCounts': {
          currentParticipant.id: 0,
          otherParticipant.id: FieldValue.increment(1),
        },
        'lastMessage': '[图片]',
        'lastSenderId': currentParticipant.id,
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      transaction.set(messageRef, {
        'senderId': currentParticipant.id,
        'senderName': currentParticipant.name,
        'text': '图片消息',
        'kind': ChatMessageKind.image.name,
        'imageUrl': imageUrl,
        'storagePath': storageRef.fullPath,
        'isRead': false,
        'sentAt': now,
      });
    });
  }

  ChatConversation? _conversationFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data();
    final participantIds =
        (data['participantIds'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];
    if (!participantIds.contains(currentUserId)) {
      return null;
    }

    final itemData = data['item'] is Map ? data['item'] as Map : const {};
    final buyerId = data['buyerId'] as String? ?? currentUserId;
    final sellerId =
        data['sellerId'] as String? ??
        (itemData['sellerId'] as String? ?? _otherId(participantIds, buyerId));
    final participantNames = data['participantNames'] is Map
        ? data['participantNames'] as Map
        : const {};
    final buyerName = participantNames[buyerId] as String? ?? '买家';
    final sellerName =
        participantNames[sellerId] as String? ??
        itemData['seller'] as String? ??
        '卖家';
    final updatedAt = _dateValue(data['updatedAt']) ?? DateTime.now();
    final lastMessage = data['lastMessage'] as String? ?? '暂无消息';
    final unreadCounts = data['unreadCounts'] is Map
        ? data['unreadCounts'] as Map
        : const {};
    final unreadCount = _intValue(unreadCounts[currentUserId]) ?? 0;

    return ChatConversation(
      id: doc.id,
      item: _itemFromData(itemData),
      buyer: ChatParticipant(
        id: buyerId,
        name: buyerName,
        avatarLabel: _avatarLabelFor(buyerName),
        roleLabel: buyerId == currentUserId ? '我' : '买家',
        creditScore: 98,
        rating: 4.9,
      ),
      seller: ChatParticipant(
        id: sellerId,
        name: sellerName,
        avatarLabel: _avatarLabelFor(sellerName),
        roleLabel: sellerId == currentUserId ? '我' : '卖家',
        creditScore: 98,
        rating: 4.9,
      ),
      messages: [
        ChatMessage(
          id: '${doc.id}-preview',
          conversationId: doc.id,
          senderId: data['lastSenderId'] as String? ?? '',
          text: lastMessage,
          sentAt: updatedAt,
          isRead: true,
        ),
      ],
      updatedAt: updatedAt,
      unreadCount: unreadCount,
      statusLabel: data['statusLabel'] as String? ?? '咨询中',
    );
  }

  MarketItem _itemFromData(Map itemData) {
    final title = itemData['title'] as String? ?? '咨询商品';
    final category = itemData['category'] as String? ?? '其他';
    final imageUrls =
        (itemData['imageUrls'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    return MarketItem(
      id: itemData['id'] as String? ?? 'unknown',
      title: title,
      titleEn: itemData['titleEn'] as String? ?? '',
      category: category,
      brand: itemData['brand'] as String? ?? '未知品牌',
      model: itemData['model'] as String? ?? '未知型号',
      condition: itemData['condition'] as String? ?? '轻微使用',
      price: _intValue(itemData['price']) ?? 0,
      distance: 0,
      seller: itemData['seller'] as String? ?? '卖家',
      sellerId: itemData['sellerId'] as String? ?? '',
      location: itemData['location'] as String? ?? '未知位置',
      latitude: 0,
      longitude: 0,
      mapX: 0.5,
      mapY: 0.5,
      description: '',
      descriptionEn: itemData['descriptionEn'] as String? ?? '',
      views: 0,
      likes: 0,
      icon: _iconForCategory(category),
      color: AppPalette.mint,
      imageUrls: imageUrls,
    );
  }
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

ChatMessageKind _messageKind(String? value) {
  return ChatMessageKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => ChatMessageKind.text,
  );
}

String _otherId(List<String> ids, String currentId) {
  return ids.firstWhere((id) => id != currentId, orElse: () => currentId);
}

String _resolvedParticipantId(String originalId, String currentUserId) {
  return originalId == currentChatUser.id ? currentUserId : originalId;
}

String _avatarLabelFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  if (trimmed.length == 1) {
    return trimmed.toUpperCase();
  }
  return trimmed.substring(0, 2).toUpperCase();
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
