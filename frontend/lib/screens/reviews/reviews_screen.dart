import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/reviews_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/review_card.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      final bp = context.read<BoutiqueProvider>();
      final boutiqueId = bp.activeBoutiqueId;
      if (boutiqueId != null) {
        context.read<ReviewsProvider>().loadReviews(boutiqueId);
      }
    }
  }

  Future<void> _load() async {
    final bp = context.read<BoutiqueProvider>();
    await bp.ensureActiveBoutique();
    if (!mounted) return;
    final boutiqueId = bp.activeBoutiqueId;
    if (boutiqueId != null) {
      context.read<ReviewsProvider>().loadReviews(boutiqueId, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BoutiqueProvider>();
    final boutiqueId = bp.activeBoutiqueId;

    if (boutiqueId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Avis')),
        body: const Center(child: Text('Aucune boutique sélectionnée')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Consumer<ReviewsProvider>(
          builder: (_, rp, __) => Text('Avis${rp.pendingCount > 0 ? ' (${rp.pendingCount})' : ''}'),
        ),
        centerTitle: true,
      ),
      body: Consumer<ReviewsProvider>(
        builder: (context, rp, _) {
          if (rp.loading && rp.reviews.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildFilterBar(rp),
              Expanded(
                child: rp.reviews.isEmpty && !rp.loading
                    ? _buildEmptyState(rp)
                    : RefreshIndicator(
                        onRefresh: () async => context.read<ReviewsProvider>().loadReviews(boutiqueId, refresh: true),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: rp.reviews.length + (rp.loading ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= rp.reviews.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            final review = rp.reviews[i];
                            return ReviewCard(
                              review: review,
                              onApprove: () => _approve(rp, review.id),
                              onReject: () => _reject(rp, review.id),
                              onDelete: () => _delete(rp, review.id),
                              onReply: (reply) => rp.replyToReview(review.id, reply),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(ReviewsProvider rp) {
    final filters = [
      ('ALL', 'Tous'),
      ('PENDING', 'En attente'),
      ('APPROVED', 'Approuvés'),
      ('REJECTED', 'Rejetés'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = rp.statusFilter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.$2, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
                selected: selected,
                onSelected: (_) => rp.setStatusFilter(f.$1),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceAlt,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ReviewsProvider rp) {
    final msg = rp.statusFilter == 'ALL'
        ? 'Aucun avis pour le moment'
        : 'Aucun avis ${rp.statusFilter == 'PENDING' ? 'en attente' : rp.statusFilter == 'APPROVED' ? 'approuvé' : 'rejeté'}';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(msg, style: AppTypography.body1),
        ],
      ),
    );
  }

  void _approve(ReviewsProvider rp, String id) async {
    final ok = await rp.approveReview(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Avis approuvé' : 'Erreur'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  void _reject(ReviewsProvider rp, String id) async {
    final ok = await rp.rejectReview(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Avis rejeté' : 'Erreur'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  void _delete(ReviewsProvider rp, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet avis ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await rp.deleteReview(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Avis supprimé' : 'Erreur'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}
