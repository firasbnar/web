import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/storage.dart';

class AiChatWidget extends StatefulWidget {
  final String boutiqueId;
  final String boutiqueName;
  final String ownerId;

  const AiChatWidget({
    super.key,
    required this.boutiqueId,
    required this.boutiqueName,
    required this.ownerId,
  });

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget> {
  bool _isLoading = false;
  bool _quickRepliesVisible = true;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _sendDebounce;

  String get _storageKey =>
      'merchant_ai_chat_${widget.ownerId}_${widget.boutiqueId}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _sendDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = (jsonDecode(data) as List).cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() {
            _messages.addAll(list.map((m) => _ChatMessage.fromJson(m)));
          });
          _scrollDown();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addBotMessage(_ChatMessage msg) {
    setState(() => _messages.add(msg));
    _saveHistory();
    _scrollDown();
  }

  void _addUserMessage(_ChatMessage msg) {
    setState(() => _messages.add(msg));
    _saveHistory();
    _scrollDown();
  }

  void _scrollDown() {
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

  Future<void> _onClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer l\u2019historique'),
        content:
            const Text('Voulez-vous vraiment effacer l\u2019historique du chat ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _messages.clear();
        _quickRepliesVisible = true;
      });
      await _saveHistory();
    }
  }

  Future<void> _sendMessage(String text, {bool isQuick = false}) async {
    final t = text.trim();
    if (t.isEmpty || _isLoading) return;

    if (isQuick) _quickRepliesVisible = false;
    _addUserMessage(_ChatMessage(role: 'user', content: t));
    _inputController.clear();
    setState(() => _isLoading = true);

    try {
      final storage = AppStorage();
      final token = await storage.getAccessToken();
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));

      final response = await dio.post('/ai/merchant-chat', data: {
        'message': t,
        'boutiqueId': widget.boutiqueId,
      });

      final data = response.data;
      final payload = data is Map ? data['data'] : null;
      final reply = payload is Map ? (payload['answer'] as String?) ?? '' : '';

      _addBotMessage(_ChatMessage(
        role: 'assistant',
        content: reply.isNotEmpty
            ? reply
            : "Desole, je n'ai pas pu obtenir une reponse. Reessayez.",
      ));
    } catch (_) {
      _addBotMessage(_ChatMessage(
        role: 'assistant',
        content: "Erreur de connexion. Veuillez reessayer.",
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onQuickReply(String label) {
    _quickRepliesVisible = false;
    _submitMessage(label, isQuick: true);
  }

  void _submitMessage(String text, {bool isQuick = false}) {
    _sendDebounce?.cancel();
    _sendDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _sendMessage(text, isQuick: isQuick);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 200),
      child: Column(
        children: [
          _buildPanelHeader(),
          Expanded(child: _buildMessagesArea()),
          if (_quickRepliesVisible) _buildQuickReplies(),
          _buildInputRow(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x1AFFFFFF),
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merchant Copilot',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4ADE80),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x664ADE80),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'En ligne',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xCCC8B4FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
              tooltip: 'Effacer l\u2019historique',
              onPressed: _onClearHistory,
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: _messages.isEmpty && !_isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined,
                        size: 48, color: const Color(0xFF7C3AED).withAlpha(60)),
                    const SizedBox(height: 12),
                    const Text(
                      'Posez une question sur votre boutique',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isLoading && i == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[i];
                return _buildMessageBubble(msg);
              },
            ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isBot = msg.role == 'assistant';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED),
              ),
              child: const Center(
                  child: Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 16)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0FF),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: const Color(0xFFE8D8FF),
                  ),
                ),
                child: _buildAssistantContent(msg),
              ),
            ),
          ] else ...[
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x667C3AED),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssistantContent(_ChatMessage msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRichText(msg.content),
      ],
    );
  }

  Widget _buildRichText(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            color: Color(0xFF2D2D3A),
            fontSize: 14,
            height: 1.5,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          color: Color(0xFF2D2D3A),
          fontSize: 14,
          height: 1.5,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7C3AED),
            ),
            child: const Center(
                child: Icon(Icons.smart_toy_outlined,
                    color: Colors.white, size: 16)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0FF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: const Color(0xFFE8D8FF),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7C3AED).withAlpha(150),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    final chips = [
      ('Best sellers', 'best'),
      ('Revenue today', 'revenue'),
      ('Low stock', 'stock'),
      ('Traffic today', 'traffic'),
      ('Orders today', 'orders'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips.map((c) {
          return GestureDetector(
            onTap: () => _onQuickReply(c.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE8D8FF),
                ),
              ),
              child: Text(
                c.$1,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLength: 500,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF2D2D3A),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Posez votre question...',
                hintStyle:
                    const TextStyle(color: Color(0xFFB0B0B0)),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
              onSubmitted: (_) => _submitMessage(_inputController.text),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isLoading
                    ? null
                    : () => _submitMessage(_inputController.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x667C3AED),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          )
                        : const Text('\u27A4',
                            style: TextStyle(
                                fontSize: 16, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8)),
        ),
      ),
      child: const Center(
        child: Text(
          'Propuls\u00E9 par MakeWebsite.io AI',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFFB0B0B0),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
