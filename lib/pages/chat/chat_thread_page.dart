import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_repository.dart';
import '../../widgets/app_components.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage>
    with WidgetsBindingObserver {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final FocusNode _messageFocusNode;
  String? _latestRenderedMessageId;
  bool _pendingScrollToLatest = true;

  String get _currentUserId =>
      AuthService.instance.currentUser?.uid ?? currentChatUser.id;

  ChatParticipant get _currentParticipant {
    final user = AuthService.instance.currentUser;
    final name =
        user?.displayName ??
        user?.email?.split('@').first ??
        currentChatUser.name;
    return ChatParticipant(
      id: _currentUserId,
      name: name,
      avatarLabel: _avatarLabelFor(name),
      roleLabel: '我',
      creditScore: currentChatUser.creditScore,
      rating: currentChatUser.rating,
    );
  }

  ChatParticipant get _other =>
      widget.conversation.otherParticipant(_currentUserId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _messageFocusNode = FocusNode()
      ..addListener(() {
        if (_messageFocusNode.hasFocus) {
          _pendingScrollToLatest = true;
          _scrollToLatestForKeyboard();
        }
      });
    ChatRepository.instance
        .markConversationRead(widget.conversation.id)
        .catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_messageFocusNode.hasFocus) {
      _scrollToLatestForKeyboard();
    }
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    _pendingScrollToLatest = true;
    try {
      await ChatRepository.instance.sendText(
        conversation: widget.conversation,
        currentParticipant: _currentParticipant,
        otherParticipant: _other,
        text: text,
      );
      _scrollToLatest();
    } catch (error) {
      _pendingScrollToLatest = false;
      await _showError(error);
    }
  }

  Future<void> _sendQuickOffer() async {
    final price = widget.conversation.item.price;
    _pendingScrollToLatest = true;
    try {
      await ChatRepository.instance.sendText(
        conversation: widget.conversation,
        currentParticipant: _currentParticipant,
        otherParticipant: _other,
        text: context.l10n.text(
          '我想以 £$price 购买，可以今天当面交易吗？',
          'I would like to buy it for £$price. Could we meet today?',
        ),
        kind: ChatMessageKind.offer,
      );
      _scrollToLatest();
    } catch (error) {
      _pendingScrollToLatest = false;
      await _showError(error);
    }
  }

  Future<void> _sendImage() async {
    try {
      final pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (pickedImage == null) {
        return;
      }
      _pendingScrollToLatest = true;
      await ChatRepository.instance.sendImage(
        conversation: widget.conversation,
        currentParticipant: _currentParticipant,
        otherParticipant: _other,
        imageFile: File(pickedImage.path),
      );
      _scrollToLatest();
    } catch (error) {
      _pendingScrollToLatest = false;
      await _showError(error);
    }
  }

  Future<void> _showError(Object error) async {
    if (!mounted) {
      return;
    }

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.ui('发送失败')),
        content: Text(authErrorMessage(error)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ui('知道了')),
          ),
        ],
      ),
    );
  }

  List<ChatMessage> _mergedMessages(List<ChatMessage> remoteMessages) {
    final currentUserId = _currentUserId;
    final baselineMessages = widget.conversation.messages.map((message) {
      if (message.senderId != currentChatUser.id) {
        return message;
      }
      return ChatMessage(
        id: message.id,
        conversationId: message.conversationId,
        senderId: currentUserId,
        text: message.text,
        sentAt: message.sentAt,
        isRead: message.isRead,
        kind: message.kind,
        imageUrl: message.imageUrl,
      );
    });

    final localBaseline = remoteMessages.isEmpty
        ? baselineMessages.where((message) => !message.id.endsWith('-preview'))
        : baselineMessages.where(
            (message) =>
                !message.id.endsWith('-preview') &&
                !remoteMessages.any((remote) => remote.id == message.id),
          );

    return [...localBaseline, ...remoteMessages]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  void _syncMessageViewport(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return;
    }

    final latestMessage = messages.last;
    if (_latestRenderedMessageId == latestMessage.id) {
      return;
    }

    final wasNearBottom = _isNearBottom();
    final shouldFollowLatest =
        _latestRenderedMessageId == null ||
        _pendingScrollToLatest ||
        latestMessage.senderId == _currentUserId ||
        wasNearBottom;

    _latestRenderedMessageId = latestMessage.id;
    if (shouldFollowLatest) {
      _pendingScrollToLatest = false;
      _scrollToLatest();
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 120;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollToLatestForKeyboard() {
    _scrollToLatest();
    for (final delay in const [
      Duration(milliseconds: 120),
      Duration(milliseconds: 280),
      Duration(milliseconds: 420),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || !_messageFocusNode.hasFocus) {
          return;
        }
        _scrollToLatest();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: _other.name,
      previousPageTitle: '消息',
      trailing: AppTag(label: _other.roleLabel),
      child: AppBackdrop(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                children: [
                  _ListingContextCard(conversation: widget.conversation),
                  const SizedBox(height: 18),
                  StreamBuilder<List<ChatMessage>>(
                    stream: ChatRepository.instance.watchMessages(
                      widget.conversation.id,
                    ),
                    builder: (context, snapshot) {
                      final messages = _mergedMessages(snapshot.data ?? []);
                      _syncMessageViewport(messages);
                      return Column(
                        children: [
                          for (final message in messages) ...[
                            _MessageBubble(
                              message: message,
                              isMine: message.senderId == _currentUserId,
                              participant: message.senderId == _currentUserId
                                  ? _currentParticipant
                                  : _other,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            _MessageComposer(
              controller: _messageController,
              focusNode: _messageFocusNode,
              onSend: _sendText,
              onImageTap: _sendImage,
              onOfferTap: _sendQuickOffer,
            ),
          ],
        ),
      ),
    );
  }
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

class _ListingContextCard extends StatelessWidget {
  const _ListingContextCard({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final item = conversation.item;

    return AppSectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(item.icon, color: AppPalette.ink, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppTag(label: conversation.statusLabel),
                    const Spacer(),
                    Text(
                      '£${item.price}',
                      style: const TextStyle(
                        color: AppPalette.brand,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  context.l10n.listingText(item.title, item.titleEn),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.strongText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.l10n.ui(item.condition)} · ${item.location} · ${item.distance.toStringAsFixed(1)}km',
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.participant,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.system) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppPalette.surfaceWarm,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppPalette.border.withValues(alpha: 0.72),
            ),
          ),
          child: Text(
            context.l10n.ui(message.text),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    final bubbleColor = isMine
        ? AppPalette.ink
        : message.kind == ChatMessageKind.offer
        ? AppPalette.brandLight
        : AppPalette.surface;
    final textColor = isMine ? CupertinoColors.white : AppPalette.strongText;

    return Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          _Avatar(participant: participant, compact: true),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isMine ? 22 : 7),
                    bottomRight: Radius.circular(isMine ? 7 : 22),
                  ),
                  border: isMine
                      ? null
                      : Border.all(
                          color: AppPalette.border.withValues(alpha: 0.75),
                        ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D0F1915),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child:
                    message.kind == ChatMessageKind.image &&
                        message.imageUrl != null
                    ? _MessageImage(url: message.imageUrl!)
                    : Text(
                        message.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: message.kind == ChatMessageKind.offer
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                _messageTime(message.sentAt),
                style: const TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 8),
          _Avatar(participant: participant, compact: true),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.participant, this.compact = false});

  final ChatParticipant participant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppPalette.ink,
        borderRadius: BorderRadius.circular(compact ? 13 : 18),
      ),
      alignment: Alignment.center,
      child: Text(
        participant.avatarLabel,
        style: TextStyle(
          color: AppPalette.mint,
          fontSize: compact ? 11 : 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: 210,
        height: 170,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const SizedBox(
            width: 210,
            height: 170,
            child: Center(child: CupertinoActivityIndicator(radius: 11)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: 210,
            height: 120,
            child: Center(
              child: Text(
                context.l10n.ui('图片加载失败'),
                style: const TextStyle(color: AppPalette.mutedText),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onImageTap,
    required this.onOfferTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onImageTap;
  final VoidCallback onOfferTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: AppPalette.background.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(color: AppPalette.border.withValues(alpha: 0.7)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ComposerToolButton(
                  icon: CupertinoIcons.photo_fill,
                  label: '图片',
                  onTap: onImageTap,
                ),
                const SizedBox(width: 8),
                _ComposerToolButton(
                  icon: CupertinoIcons.money_pound_circle_fill,
                  label: '按标价',
                  onTap: onOfferTap,
                ),
                const Spacer(),
                Text(
                  context.l10n.ui('实时消息'),
                  style: const TextStyle(
                    color: AppPalette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    placeholder: context.l10n.ui('输入消息，询问成色、配件或取货时间'),
                    placeholderStyle: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 14,
                    ),
                    style: const TextStyle(
                      color: AppPalette.strongText,
                      fontSize: 15,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppPalette.border.withValues(alpha: 0.78),
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onSend,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppPalette.brand,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.brand.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.paperplane_fill,
                      color: CupertinoColors.white,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerToolButton extends StatelessWidget {
  const _ComposerToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppPalette.surfaceWarm,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppPalette.border.withValues(alpha: 0.75)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppPalette.brand, size: 16),
            const SizedBox(width: 5),
            Text(
              context.l10n.ui(label),
              style: const TextStyle(
                color: AppPalette.strongText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _messageTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
