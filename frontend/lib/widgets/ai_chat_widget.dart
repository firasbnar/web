import 'dart:async';
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
  bool _eyesClosed = false;
  bool _isPressed = false;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _sendDebounce;

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _startBlinking();

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
    _blinkTimer?.cancel();
    _sendDebounce?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(seconds: 2 + Random().nextInt(4)), () {
      if (!mounted) return;
      setState(() => _eyesClosed = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _eyesClosed = false);
      });
      _scheduleBlink();
    });
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
            content: 'Bonjour ! Je suis votre assistant business pour **${widget.boutiqueName}**. Je peux analyser ventes, stock, trafic et clients.',
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

      final endpoint = '/ai/owner/chat';
      final response = await dio.post(endpoint, data: {
        'boutiqueId': widget.boutiqueId,
        'message': t,
        'sessionId': 'owner-${widget.boutiqueId}',
        'messages': history,
      });

      final data = response.data;
      final payload = data is Map && data['data'] is Map ? data['data'] as Map : data as Map?;
      String reply = '';
      List<Map<String, dynamic>> products = [];
      Map<String, dynamic>? analytics;

      if (payload is Map) {
        final content = payload['content'];
        if (content is List && content.isNotEmpty) {
          reply = (content[0]?['text'] as String?) ?? '';
        }
        if (reply.isEmpty) {
          reply = (payload['reply'] as String?) ?? '';
        }
        final rawProducts = payload['products'];
        if (rawProducts is List) {
          products = rawProducts
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        final rawAnalytics = payload['analytics'];
        if (rawAnalytics is Map) {
          analytics = Map<String, dynamic>.from(rawAnalytics);
        }
      }

      if (reply.isEmpty) {
        reply = "Desole, je n'ai pas pu obtenir une reponse. Reessayez.";
      }

      _addBotMessage(_ChatMessage(
        role: 'assistant',
        content: reply,
        products: products,
        analytics: analytics,
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 480;
    final panelWidth = isMobile ? size.width - 24 : 370.0;
    final panelHeight = size.height > 600 ? 540.0 : size.height * 0.7;

    return SizedBox(
      width: _isOpen ? panelWidth : 56,
      height: _isOpen ? panelHeight + 84 : 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_isOpen) _buildChatPanel(panelWidth, panelHeight),
          _buildFloatingRobotAssistant(),
        ],
      ),
    );
  }

  Widget _buildFloatingRobotAssistant() {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tooltipVisible) _buildHelpBubble(),
          GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: _togglePanel,
            child: AnimatedScale(
              scale: _isPressed ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedBuilder(
                animation: Listenable.merge([_floatController, _pulseController]),
                builder: (_, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    ),
                  );
                },
                child: _buildRobotMascot(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Besoin d\'aide ?',
              style: TextStyle(
                color: Color(0xFF5B21B6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            child: Transform.rotate(
              angle: 45 * pi / 180,
              child: Container(
                width: 9,
                height: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRobotMascot() {
    return SizedBox(
      width: 56,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft shadow behind
          Positioned(
            bottom: 4,
            left: 10,
            right: 10,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (_, __) {
                final lift = -_floatAnim.value / 4;
                final opac = 0.18 - lift * 0.08;
                final scale = 1.0 - lift * 0.25;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: const Color(0xFF6D28D9).withAlpha(
                          (opac * 255).round()),
                    ),
                  ),
                );
              },
            ),
          ),
          // Rocket glow
          Positioned(
            left: 17,
            right: 17,
            bottom: 10,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final p = _pulseAnim.value;
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF38BDF8), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8)
                            .withAlpha((40 * p).round()),
                        blurRadius: 10 * p,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Left arm
          Positioned(
            left: 2,
            top: 42,
            child: Container(
              width: 7,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          // Right arm
          Positioned(
            right: 2,
            top: 42,
            child: Container(
              width: 7,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          // Body
          Positioned(
            left: 8,
            right: 8,
            top: 34,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFCFCFF),
                    Color(0xFFF5F3FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D28D9).withAlpha(12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          // Left ear
          Positioned(
            left: -2,
            top: 12,
            child: Container(
              width: 10,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x306D28D9),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Right ear
          Positioned(
            right: -2,
            top: 12,
            child: Container(
              width: 10,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x306D28D9),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Antenna
          Positioned(
            top: -1,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 2,
                    height: 8,
                    color: const Color(0xFF6D28D9),
                  ),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6D28D9),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x556D28D9),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Head
          Positioned(
            left: 4,
            right: 4,
            top: 3,
            child: _buildRobotHead(),
          ),
          // Close badge
          if (_isOpen)
            Positioned(
              top: 5,
              right: 6,
              child: GestureDetector(
                onTap: _togglePanel,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D28D9),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x306D28D9),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('\u2715',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRobotHead() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFCFCFF),
            Color(0xFFF8F6FF),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withAlpha(16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy shine
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 16,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x40FFFFFF),
                      Color(0x10FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Face screen
          Positioned(
            left: 6,
            right: 6,
            top: 5,
            bottom: 5,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1F2937),
                  width: 0.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEye(),
                      const SizedBox(width: 12),
                      _buildEye(),
                    ],
                  ),
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 12,
                      height: 2,
                      decoration: BoxDecoration(
                        color: _eyesClosed
                            ? Colors.transparent
                            : const Color(0xFF4ADE80),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEye() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final glow = _pulseAnim.value;
        return Container(
          width: 6,
          height: _eyesClosed ? 1 : 6,
          margin: EdgeInsets.only(top: _eyesClosed ? 9 : 0),
          decoration: BoxDecoration(
            shape: _eyesClosed ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: _eyesClosed ? BorderRadius.circular(0.5) : null,
            gradient: const RadialGradient(
              center: Alignment(0.3, -0.3),
              colors: [Color(0xFF7DD3FC), Color(0xFF38BDF8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withAlpha((80 * glow).round()),
                blurRadius: 5 * glow,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatPanel(double width, double height) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: 0,
      bottom: 84 + bottomPadding,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(248),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withAlpha(200),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 48,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 16,
              offset: Offset(0, 4),
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
      color: const Color(0xFFFAFAFA),
      child: _messages.isEmpty && !_isLoading
          ? const SizedBox.shrink()
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
        if (msg.analytics != null && msg.analytics!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildAnalyticsSummary(msg.analytics!),
        ],
        if (msg.products.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...msg.products.take(4).map(_buildProductResult),
        ],
      ],
    );
  }

  Widget _buildAnalyticsSummary(Map<String, dynamic> analytics) {
    final items = analytics.entries
        .where((e) => e.value is num || e.value is String)
        .take(4)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8D8FF)),
          ),
          child: Text(
            '${e.key}: ${e.value}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5B21B6)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductResult(Map<String, dynamic> product) {
    final image = product['image'] as String?;
    final price = product['price'];
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8D8FF)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image != null && image.isNotEmpty
                ? Image.network(
                    image,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _productPlaceholder(),
                  )
                : _productPlaceholder(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product['name'] ?? 'Produit'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price == null ? 'Prix non disponible' : '$price TND',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      width: 42,
      height: 42,
      color: const Color(0xFFF5F0FF),
      child: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF7C3AED)),
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
                    color: const Color(0xFF7C3AED).withAlpha(150),
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
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic>? analytics;

  _ChatMessage({
    required this.role,
    required this.content,
    this.products = const [],
    this.analytics,
  });
}
