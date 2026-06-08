import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/websocket_provider.dart';
import '../../widgets/app_back_arrow.dart';

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;
  const ConversationScreen({super.key, required this.conversation});
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _startPolling();
    });
  }

  void _load() {
    final mp = context.read<MessagesProvider>();
    mp.loadMessages(widget.conversation.id).then((_) {
      _lastMessageCount = mp.messages.length;
      _scrollToBottom();
    });
    mp.markAsRead(widget.conversation.id);
    context.read<WebSocketProvider>().subscribeToConversation(widget.conversation.id);
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final wsp = context.read<WebSocketProvider>();
      if (!wsp.isConnected) {
        dev.log('[ConversationScreen] WS not connected, polling messages');
        context.read<MessagesProvider>().loadMessages(widget.conversation.id);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    context.read<WebSocketProvider>().unsubscribeConversation();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  static bool isMerchantMessage(Message msg) {
    return msg.senderType == 'MERCHANT' || msg.senderType == 'BOUTIQUE';
  }

  Future<void> _sendReply() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    _controller.clear();

    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique == null) return;

    final mp = context.read<MessagesProvider>();
    await mp.replyToConversation(
      boutiqueId: bp.activeBoutique!.id,
      conversationId: widget.conversation.id,
      content: content,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.customerName, style: const TextStyle(fontSize: 16)),
            if (widget.conversation.customerEmail.isNotEmpty)
              Text(widget.conversation.customerEmail, style: const TextStyle(fontSize: 12, color: AppColors.textHint))
            else if (widget.conversation.customerPhone != null && widget.conversation.customerPhone!.isNotEmpty)
              Text(widget.conversation.customerPhone!, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MessagesProvider>(
              builder: (_, mp, __) {
                if (mp.messages.length > _lastMessageCount) {
                  _lastMessageCount = mp.messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
                if (mp.loadingMessages) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (mp.messages.isEmpty) {
                  return Center(
                    child: Text('messages.no_messages'.tr(), style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: mp.messages.length,
                  itemBuilder: (_, i) {
                    final msg = mp.messages[i];
                    final isMine = isMerchantMessage(msg);
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                          ),
                          border: !isMine ? Border.all(color: const Color(0xFFE5E7EB)) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg.content, style: TextStyle(color: isMine ? Colors.white : Colors.black87), softWrap: true, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            if (msg.createdAt != null)
                              Text(_formatTime(msg.createdAt!), style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : AppColors.textHint)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'messages.type_message'.tr(),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _sendReply,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
