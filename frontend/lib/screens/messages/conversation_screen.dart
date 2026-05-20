import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../models/conversation.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/messages_provider.dart';

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;
  const ConversationScreen({super.key, required this.conversation});
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagesProvider>().loadMessages(widget.conversation.id);
      context.read<MessagesProvider>().markAsRead(widget.conversation.id);
    });
  }

  @override
  void dispose() {
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.customerName, style: const TextStyle(fontSize: 16)),
            Text(widget.conversation.customerEmail, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MessagesProvider>(
              builder: (_, mp, __) {
                if (mp.loadingMessages) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (mp.messages.isEmpty) {
                  return Center(
                    child: Text('Aucun message', style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: mp.messages.length,
                  itemBuilder: (_, i) {
                    final msg = mp.messages[i];
                    final isMine = msg.senderType == 'BOUTIQUE';
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
                            Text(msg.content, style: TextStyle(color: isMine ? Colors.white : Colors.black87)),
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
                      decoration: const InputDecoration(
                        hintText: 'Écrivez votre réponse...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
