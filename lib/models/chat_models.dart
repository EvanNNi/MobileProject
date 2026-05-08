import 'market_item.dart';

enum ChatMessageKind { text, system, offer, image }

class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.name,
    required this.avatarLabel,
    required this.roleLabel,
    required this.creditScore,
    required this.rating,
  });

  final String id;
  final String name;
  final String avatarLabel;
  final String roleLabel;
  final int creditScore;
  final double rating;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.isRead,
    this.kind = ChatMessageKind.text,
    this.imageUrl,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isRead;
  final ChatMessageKind kind;
  final String? imageUrl;
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.item,
    required this.buyer,
    required this.seller,
    required this.messages,
    required this.updatedAt,
    required this.unreadCount,
    required this.statusLabel,
  });

  final String id;
  final MarketItem item;
  final ChatParticipant buyer;
  final ChatParticipant seller;
  final List<ChatMessage> messages;
  final DateTime updatedAt;
  final int unreadCount;
  final String statusLabel;

  ChatParticipant otherParticipant(String currentUserId) {
    return seller.id == currentUserId ? buyer : seller;
  }

  ChatMessage get lastMessage => messages.last;

  ChatConversation copyWith({
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    int? unreadCount,
    String? statusLabel,
  }) {
    return ChatConversation(
      id: id,
      item: item,
      buyer: buyer,
      seller: seller,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      statusLabel: statusLabel ?? this.statusLabel,
    );
  }
}

const currentChatUser = ChatParticipant(
  id: 'user-current',
  name: '我',
  avatarLabel: '我',
  roleLabel: '我',
  creditScore: 98,
  rating: 4.9,
);

ChatParticipant participantForSeller(String sellerName) {
  return ChatParticipant(
    id: 'seller-${sellerName.toLowerCase()}',
    name: sellerName,
    avatarLabel: _avatarLabelFor(sellerName),
    roleLabel: '卖家',
    creditScore: _sellerCreditFor(sellerName),
    rating: _sellerRatingFor(sellerName),
  );
}

ChatConversation buildConversationForItem(MarketItem item) {
  final seller = item.sellerId.isEmpty
      ? participantForSeller(item.seller)
      : ChatParticipant(
          id: item.sellerId,
          name: item.seller,
          avatarLabel: _avatarLabelFor(item.seller),
          roleLabel: '卖家',
          creditScore: _sellerCreditFor(item.seller),
          rating: _sellerRatingFor(item.seller),
        );
  final conversationId = 'listing-${item.id}';
  final now = DateTime.now();

  return ChatConversation(
    id: conversationId,
    item: item,
    buyer: currentChatUser,
    seller: seller,
    updatedAt: now,
    unreadCount: 0,
    statusLabel: '咨询中',
    messages: [
      ChatMessage(
        id: '$conversationId-system',
        conversationId: conversationId,
        senderId: 'system',
        text: '你正在咨询「${item.title}」，交易前建议先确认成色、配件和取货方式。',
        sentAt: now,
        isRead: true,
        kind: ChatMessageKind.system,
      ),
    ],
  );
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

int _sellerCreditFor(String name) {
  final seed = name.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return 88 + seed % 12;
}

double _sellerRatingFor(String name) {
  final seed = name.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return 4.6 + (seed % 4) / 10;
}
