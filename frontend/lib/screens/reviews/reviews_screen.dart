import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/reviews_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/review_card.dart';
import '../../widgets/app_back_arrow.dart';

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
        appBar: AppBar(title: Text('reviews.title'.tr())),
        body: Center(child: Text('common.no_data'.tr())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Consumer<ReviewsProvider>(
          builder: (_, rp, __) => Text('${'reviews.title'.tr()}${rp.pendingCount > 0 ? ' (${rp.pendingCount})' : ''}'),
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
      ('ALL', 'common.all'.tr()),
      ('PENDING', 'reviews.pending'.tr()),
      ('APPROVED', 'reviews.approved'.tr()),
      ('REJECTED', 'reviews.rejected'.tr()),
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
        ? 'reviews.no_reviews'.tr()
        : 'reviews.no_reviews'.tr();
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
        content: Text(ok ? 'reviews.review_approved'.tr() : 'common.error'.tr()),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  void _reject(ReviewsProvider rp, String id) async {
    final ok = await rp.rejectReview(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'reviews.review_rejected'.tr() : 'common.error'.tr()),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  void _delete(ReviewsProvider rp, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('reviews.delete'.tr()),
        content: Text('common.confirm_delete'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: Text('common.delete'.tr())),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await rp.deleteReview(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'reviews.review_deleted'.tr() : 'common.error'.tr()),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ));
      }
    }
  }
}
