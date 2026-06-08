import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/storage.dart';
import '../theme/app_colors.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _featuresKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              _buildHeader(),
              _buildHero(isSmall),
              _buildBenefits(),
              _buildHowToUse(),
              _buildFeatures(isSmall),
              _buildPricing(),
              _buildTestimonials(),
              _buildBottomCta(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2710BF), Color(0xFF1E0B8E)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.store_outlined,
                        color: Color(0xFF2710BF), size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'app_name'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _buildLangButton(),
            const SizedBox(width: 6),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLangButton() {
    final code = context.locale.languageCode;
    final flag = code == 'en' ? '\u{1F1EC}\u{1F1E7}' : code == 'ar' ? '\u{1F1F8}\u{1F1E6}' : '\u{1F1EB}\u{1F1F7}';
    final label = code.toUpperCase();
    return GestureDetector(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('profile.english'.tr()),
                  onTap: () => Navigator.pop(ctx, 'en'),
                ),
                ListTile(
                  title: Text('profile.french'.tr()),
                  onTap: () => Navigator.pop(ctx, 'fr'),
                ),
                ListTile(
                  title: Text('profile.arabic'.tr()),
                  onTap: () => Navigator.pop(ctx, 'ar'),
                ),
              ],
            ),
          ),
        );
        if (selected == null) return;
        await AppStorage().saveLocaleCode(selected);
        if (!mounted) return;
        await context.setLocale(Locale(selected));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Icon(Icons.expand_more, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: () => context.push('/login'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'auth.login'.tr(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2710BF),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool isSmall) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, isSmall ? 20 : 32, 24, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2710BF), Color(0xFF3B22D4), Color(0xFF5A3EE8)],
        ),
      ),
      child: Column(
        children: [
          if (!isSmall) _buildHeroDecorativeCards(),
          if (!isSmall) const SizedBox(height: 20),
          Text(
            'Cr\u00E9ez votre boutique en ligne en 1 minute',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isSmall ? 24 : 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Lancez votre boutique en Tunisie sans code, g\u00E9rez vos produits, commandes et paiements depuis une seule application.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withAlpha(200),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryCta(),
          const SizedBox(height: 8),
          _buildSecondaryCta(),
        ],
      ),
    );
  }

  Widget _buildHeroDecorativeCards() {
    return SizedBox(
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 130,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha(60),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 5,
                            width: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(60),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 3,
                            width: 70,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 60,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEBFF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 3,
                        width: 34,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 0,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 56,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          3,
                          (_) => const Padding(
                            padding: EdgeInsets.only(right: 1),
                            child: Icon(Icons.star,
                                size: 8, color: Color(0xFFFBBF24)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F2FB),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCta() {
    return GestureDetector(
      onTap: () => context.push('/login'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Commencer gratuitement',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2710BF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCta() {
    return GestureDetector(
      onTap: _scrollToFeatures,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Voir les fonctionnalit\u00E9s',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(220),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.white.withAlpha(220)),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefits() {
    final items = [
      ('0%', 'Commission', Icons.percent, const Color(0xFF16A34A)),
      ('\uD83D\uDCB3', 'Direct', Icons.credit_card, const Color(0xFF2710BF)),
      ('\uD83E\uDD16', 'IA', Icons.smart_toy_outlined, const Color(0xFF7C3AED)),
      ('\uD83D\uDCE2', 'Telegram', Icons.telegram, const Color(0xFF2563EB)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: _buildSectionLabel('AVANTAGES EXPRESS'),
          ),
          SizedBox(
            height: 90,
            child: Row(
              children: items.map((item) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item.$3, size: 22, color: item.$4),
                              const SizedBox(height: 4),
                              Text(
                                item.$2,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHowToUse() {
    final steps = [
      ('Cr\u00E9ez votre compte',
       'Inscrivez-vous gratuitement en quelques secondes.',
       Icons.person_add_outlined),
      ('Configurez votre boutique',
       'Personnalisez couleurs, logo et informations.',
       Icons.palette_outlined),
      ('Ajoutez vos produits',
       'Importez avec photos, descriptions et prix.',
       Icons.inventory_2_outlined),
      ('Lancez vos ventes',
       'Partagez le lien et commencez \u00E0 vendre.',
       Icons.rocket_launch_outlined),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('COMMENT \u00C7A MARCHE'),
          const SizedBox(height: 8),
          Text(
            'Lancez votre boutique en 4 \u00E9tapes',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 20 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$1,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.$2,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatures(bool isSmall) {
    final features = [
      ('Gestion des\nproduits', Icons.inventory_2_outlined, const Color(0xFF2710BF)),
      ('Gestion des\ncommandes', Icons.receipt_long_outlined, const Color(0xFF059669)),
      ('Syst\u00E8me de\ncaisse', Icons.point_of_sale_outlined, const Color(0xFF7C3AED)),
      ('Analytics', Icons.analytics_outlined, const Color(0xFF2563EB)),
      ('SEO', Icons.travel_explore_outlined, const Color(0xFFD97706)),
      ('Domaine\npersonnalis\u00E9', Icons.language_outlined, const Color(0xFFDC2626)),
      ('Multi-\nlangues', Icons.translate_outlined, const Color(0xFF0891B2)),
      ('Assistant\nIA', Icons.smart_toy_outlined, const Color(0xFF7C3AED)),
    ];
    final crossAxisCount = isSmall ? 3 : 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: _buildSectionLabel('FONCTIONNALIT\u00C9S'),
          ),
          GridView.builder(
            key: _featuresKey,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final f = features[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: f.$3.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(f.$2, size: 18, color: f.$3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        f.$1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricing() {
    final plans = [
      ('Gratuit', 'DT 0', '2 jours', 'Commencer', const Color(0xFF6B7280)),
      ('Premium', 'DT 35', '/mois', 'Choisir', const Color(0xFF2710BF)),
      ('3 Mois', 'DT 99', '/3 mois', 'Choisir', const Color(0xFF7C3AED)),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A2E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('TARIFS'),
          const SizedBox(height: 4),
          Text(
            'Simple et transparent',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...plans.map((plan) {
            final isHighlighted = plan.$5 == const Color(0xFF2710BF);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isHighlighted ? Colors.white : Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: isHighlighted
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.$1,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isHighlighted
                                ? AppColors.textPrimary
                                : Colors.white.withAlpha(200),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan.$2,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: isHighlighted
                                    ? AppColors.textPrimary
                                    : Colors.white,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3, left: 2),
                              child: Text(
                                plan.$3,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isHighlighted
                                      ? AppColors.textSecondary
                                      : Colors.white.withAlpha(150),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      constraints: const BoxConstraints(minHeight: 36),
                      decoration: BoxDecoration(
                        color: plan.$5,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        plan.$4,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTestimonials() {
    final testimonials = [
      ('Marwa Ben A\u00EFssa',
          'Site pr\u00EAt, argent arrive direct, et design magnifique !',
          5),
      ('Nour El Houda Mzoughi',
          'Personnalise comme tu veux, plein de mod\u00E8les.',
          5),
      ('Slim Rekik',
          'Conversion excellente, site responsive.',
          5),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: _buildSectionLabel('T\u00C9MOIGNAGES'),
          ),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: testimonials.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              padding: const EdgeInsets.only(right: 8),
              itemBuilder: (_, i) {
                final t = testimonials[i];
                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          t.$3,
                          (_) => const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(Icons.star,
                                size: 14, color: Color(0xFFFBBF24)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          t.$2,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.$1,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2710BF), Color(0xFF5A3EE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'Pr\u00EAt \u00E0 lancer votre boutique ?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rejoignez les entrepreneurs tunisiens qui nous font confiance.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withAlpha(190),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.push('/login'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Cr\u00E9er ma boutique',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2710BF),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0A2E),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Center(
                  child: Icon(Icons.store_outlined,
                      color: Color(0xFF2710BF), size: 12),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'app_name'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'landing.copyright'.tr(),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }
}
