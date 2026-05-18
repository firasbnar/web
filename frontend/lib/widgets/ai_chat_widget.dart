import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/storage.dart';

class AiChatWidget extends StatefulWidget {
  final String boutiqueId;
  final String boutiqueName;

  const AiChatWidget({
    super.key,
    required this.boutiqueId,
    required this.boutiqueName,
  });

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  bool _isLoading = false;
  bool _tooltipVisible = true;
  bool _quickRepliesVisible = true;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _tooltipVisible = false);
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() {
      _isOpen = !_isOpen;
      _tooltipVisible = false;
    });
    if (_isOpen && _messages.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _addBotMessage(_ChatMessage(
            role: 'assistant',
            content:
                'Bonjour ! Bienvenue chez **${widget.boutiqueName}**. Comment puis-je vous aider aujourd\'hui ?',
          ));
        }
      });
    }
  }

  void _addBotMessage(_ChatMessage msg) {
    setState(() => _messages.add(msg));
    _scrollDown();
  }

  void _addUserMessage(_ChatMessage msg) {
    setState(() => _messages.add(msg));
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

  Future<void> _sendMessage(String text, {bool isQuick = false}) async {
    final t = text.trim();
    if (t.isEmpty || _isLoading) return;

    if (isQuick) _quickRepliesVisible = false;
    _addUserMessage(_ChatMessage(role: 'user', content: t));
    _inputController.clear();
    setState(() => _isLoading = true);

    final history = _messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

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

      final response = await dio.post('/public/chat', data: {
        'boutiqueId': widget.boutiqueId,
        'messages': history,
      });

      final data = response.data;
      String reply = '';

      if (data is Map) {
        final content = data['content'];
        if (content is List && content.isNotEmpty) {
          reply = (content[0]?['text'] as String?) ?? '';
        }
        if (reply.isEmpty) {
          reply = (data['reply'] as String?) ?? '';
        }
      }

      if (reply.isEmpty) {
        reply = "Desole, je n'ai pas pu obtenir une reponse. Reessayez.";
      }

      _addBotMessage(_ChatMessage(role: 'assistant', content: reply));
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
    _sendMessage(label, isQuick: true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width > 480 ? 370.0 : size.width - 24;
    final panelHeight = size.height > 600 ? 540.0 : size.height * 0.7;

    return SizedBox(
      width: _isOpen ? panelWidth : 64,
      height: _isOpen ? panelHeight + 80 : 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_isOpen) _buildChatPanel(panelWidth, panelHeight),
          _buildOrbButton(),
        ],
      ),
    );
  }

  Widget _buildOrbButton() {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tooltip
          if (_tooltipVisible)
            GestureDetector(
              onTap: _togglePanel,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Besoin d\'aide ?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: _togglePanel,
            child: AnimatedBuilder(
              animation: Listenable.merge([_floatController, _pulseController]),
              builder: (_, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: child,
                );
              },
              child: SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ring ripple
                    AnimatedBuilder(
                      animation: _ringController,
                      builder: (_, __) {
                        final value = _ringController.value;
                        return Opacity(
                          opacity: (1 - value) * 0.4,
                          child: Transform.scale(
                            scale: 1 + value * 0.7,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFB464FF).withAlpha(100),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Orb glow
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) {
                        return Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(0.3, -0.3),
                              colors: [
                                Color(0x80FFFFFF),
                                Color(0xB3B464FF),
                                Color(0xF25A00B4),
                                Color(0xFF280050),
                              ],
                              stops: [0.0, 0.3, 0.65, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB464FF).withAlpha(80),
                                blurRadius: 20 * _pulseAnim.value,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(0xFF7800FF).withAlpha(60),
                                blurRadius: 45 * _pulseAnim.value,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: const Color(0xFF6400C8).withAlpha(40),
                                blurRadius: 80 * _pulseAnim.value,
                              ),
                              const BoxShadow(
                                color: Color(0x80000000),
                                blurRadius: 20,
                                offset: Offset(0, -8),
                                blurStyle: BlurStyle.inner,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '\u2726',
                              style: TextStyle(
                                fontSize: 26,
                                color: Color(0xEBFFFFFF),
                                shadows: [
                                  Shadow(
                                    color: Color(0x99FFFFFF),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Shine highlight
                    Positioned(
                      top: 10,
                      left: 14,
                      child: Container(
                        width: 22,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                    // Orbiting particles
                    ...List.generate(3, (i) => _orbParticle(i)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orbParticle(int index) {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (_, __) {
        final t = _ringController.value;
        final angle = t * 2 * pi + [0.0, 2.094, 4.189][index];
        final radius = [38.0, 42.0, 35.0][index];
        final x = 32 + radius * cos(angle) - 2.5;
        final y = 32 + radius * sin(angle) - 2.5;
        return Positioned(
          left: x,
          top: y,
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xCCC896FF),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatPanel(double width, double height) {
    return Positioned(
      right: 0,
      bottom: 80,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFB464FF).withAlpha(50),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7800FF).withAlpha(25),
              blurRadius: 40,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Color(0x99000000),
              blurRadius: 60,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildPanelHeader(),
            Expanded(child: _buildMessagesArea()),
            if (_quickRepliesVisible) _buildQuickReplies(),
            _buildInputRow(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xCC6400C8), Color(0xE63C008C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0.3, -0.3),
                colors: [
                  Color(0x80FFFFFF),
                  Color(0xCCA050FF),
                  Color(0xFF5000A0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB464FF).withAlpha(100),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Center(
              child: Text('\u2726', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant ${widget.boutiqueName}',
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
                      'En ligne \u00B7 Respond instantanement',
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
          GestureDetector(
            onTap: _togglePanel,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0x1AFFFFFF),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('\u2715',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xB3FFFFFF))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: _messages.isEmpty && !_isLoading
          ? const SizedBox.shrink()
          : ListView.builder(
              controller: _scrollController,
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
                gradient: const RadialGradient(
                  center: Alignment(0.3, -0.3),
                  colors: [
                    Color(0x66FFFFFF),
                    Color(0xCC8C3CF0),
                    Color(0xFF46008C),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB464FF).withAlpha(65),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                  child: Text('\u2726', style: TextStyle(fontSize: 12))),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x12FFFFFF),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: const Color(0xFFB464FF).withAlpha(35),
                  ),
                ),
                child: _buildRichText(msg.content),
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

  Widget _buildRichText(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 14,
            height: 1.5,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          color: Colors.white,
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
          color: Color(0xE6FFFFFF),
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
              gradient: const RadialGradient(
                center: Alignment(0.3, -0.3),
                colors: [
                  Color(0x66FFFFFF),
                  Color(0xCC8C3CF0),
                  Color(0xFF46008C),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB464FF).withAlpha(65),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
                child: Text('\u2726', style: TextStyle(fontSize: 12))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x12FFFFFF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: const Color(0xFFB464FF).withAlpha(35),
              ),
            ),
            child: _buildAnimatedDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = [0.0, 0.2, 0.4][i];
            final t = (_ringController.value + delay) % 1.0;
            final y = (t < 0.5 ? t * 12 : (1 - t) * 12) - 3;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB464FF).withAlpha(180),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    final chips = [
      ('Voir les produits', 'products'),
      ('Livraison', 'delivery'),
      ('Paiement', 'payment'),
      ('Contact', 'contact'),
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
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFB464FF).withAlpha(50),
                ),
              ),
              child: Text(
                c.$1,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xCCE6C8FF),
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
        color: Color(0x0AFFFFFF),
        border: Border(
          top: BorderSide(color: Color(0x26B464FF)),
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
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Posez votre question...',
                hintStyle:
                    const TextStyle(color: Color(0x4DFFFFFF)),
                counterText: '',
                filled: true,
                fillColor: const Color(0x14FFFFFF),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: const Color(0xFFB464FF).withAlpha(35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: const Color(0xFFB464FF).withAlpha(100),
                  ),
                ),
              ),
              onSubmitted: (_) => _sendMessage(_inputController.text),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => _sendMessage(_inputController.text),
            child: Container(
              width: 38,
              height: 38,
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
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      child: const Center(
        child: Text(
          'Propuls\u00E9 par MakeWebsite.io AI',
          style: TextStyle(
            fontSize: 11,
            color: Color(0x33FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;

  _ChatMessage({required this.role, required this.content});
}
