import 'package:flutter/cupertino.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_repository.dart';
import '../../widgets/app_components.dart';
import 'chat_thread_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  String _filter = '全部';

  String get _currentUserId =>
      AuthService.instance.currentUser?.uid ?? currentChatUser.id;

  List<ChatConversation> _visibleConversations(
    List<ChatConversation> conversations,
  ) {
    return conversations.where((conversation) {
      if (_filter == '全部') {
        return true;
      }
      if (_filter == '买家') {
        return conversation.seller.id == _currentUserId;
      }
      return conversation.buyer.id == _currentUserId;
    }).toList();
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ChatThreadPage(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '消息',
      child: AppBackdrop(
        child: StreamBuilder<List<ChatConversation>>(
          stream: ChatRepository.instance.watchConversations(),
          builder: (context, snapshot) {
            final conversations = snapshot.data ?? const <ChatConversation>[];
            final visibleConversations = _visibleConversations(conversations);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _ConversationSummary(
                  conversations: conversations,
                  currentUserId: _currentUserId,
                ),
                const SizedBox(height: 18),
                _FilterChips(
                  selected: _filter,
                  onChanged: (value) {
                    setState(() {
                      _filter = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    conversations.isEmpty)
                  const AppSectionCard(
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  )
                else if (snapshot.hasError)
                  AppSectionCard(
                    child: AppSectionTitle(
                      title: '消息加载失败',
                      subtitle: '${snapshot.error}',
                    ),
                  )
                else if (visibleConversations.isEmpty)
                  const _EmptyState()
                else
                  for (final conversation in visibleConversations) ...[
                    _ConversationTile(
                      conversation: conversation,
                      currentUserId: _currentUserId,
                      onTap: () => _openConversation(conversation),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationSummary extends StatelessWidget {
  const _ConversationSummary({
    required this.conversations,
    required this.currentUserId,
  });

  final List<ChatConversation> conversations;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final unreadTotal = conversations.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );
    final sellingCount = conversations
        .where((item) => item.seller.id == currentUserId)
        .length;

    return AppSectionCard(
      child: Row(
        children: [
          AppMetricTile(
            label: '未读消息',
            value: '$unreadTotal',
            caption: unreadTotal == 0 ? '暂无待处理' : '需要及时回复',
            highlight: unreadTotal > 0,
          ),
          const SizedBox(width: 12),
          AppMetricTile(
            label: '卖家咨询',
            value: '$sellingCount',
            caption: '来自买家的询价',
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in const ['全部', '买家', '卖家']) ...[
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 42,
                decoration: BoxDecoration(
                  color: selected == label
                      ? AppPalette.ink
                      : AppPalette.surfaceWarm,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected == label
                        ? AppPalette.ink
                        : AppPalette.border.withValues(alpha: 0.75),
                  ),
                ),
                child: Center(
                  child: Text(
                    context.l10n.ui(label),
                    style: TextStyle(
                      color: selected == label
                          ? CupertinoColors.white
                          : AppPalette.strongText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (label != '卖家') const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherParticipant(currentUserId);
    final last = conversation.lastMessage;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppSectionCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppPalette.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    other.avatarLabel,
                    style: const TextStyle(
                      color: AppPalette.mint,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (conversation.unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppPalette.warmAccent,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppPalette.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          other.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.strongText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.ui(_relativeTime(conversation.updatedAt)),
                        style: const TextStyle(
                          color: AppPalette.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    last.kind == ChatMessageKind.system
                        ? context.l10n.ui('系统提醒')
                        : last.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: conversation.unreadCount > 0
                          ? AppPalette.strongText
                          : AppPalette.mutedText,
                      fontSize: 14,
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: conversation.item.color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          conversation.item.icon,
                          color: AppPalette.ink,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.listingText(
                            conversation.item.title,
                            conversation.item.titleEn,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AppTag(
                        label: conversation.statusLabel,
                        color: AppPalette.brandLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppSectionCard(
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.chat_bubble_2,
            color: AppPalette.mutedText,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.ui('这里还没有会话'),
            style: const TextStyle(
              color: AppPalette.strongText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ui('去商品详情页点击“联系卖家”，就能开启一条商品会话。'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} 小时前';
  }
  return '${diff.inDays} 天前';
}
