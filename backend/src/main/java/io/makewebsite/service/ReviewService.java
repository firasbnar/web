package io.makewebsite.service;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ReviewService {
    private final ReviewRepository reviewRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final UserRepository userRepository;
    private final TelegramNotificationService telegramNotificationService;

    public Page<Review> getBoutiqueReviews(UUID boutiqueId, ReviewStatus status, Pageable pageable) {
        if (status != null) {
            return reviewRepository.findByBoutiqueIdAndStatusOrderByCreatedAtDesc(boutiqueId, status, pageable);
        }
        return reviewRepository.findByBoutiqueIdOrderByCreatedAtDesc(boutiqueId, pageable);
    }

    public Page<Review> getProductReviews(UUID productId, boolean approvedOnly, Pageable pageable) {
        if (approvedOnly) {
            return reviewRepository.findByProductIdAndStatusOrderByCreatedAtDesc(productId, ReviewStatus.APPROVED, pageable);
        }
        return reviewRepository.findByProductIdOrderByCreatedAtDesc(productId, pageable);
    }

    public long getPendingCount(UUID boutiqueId) {
        return reviewRepository.countByBoutiqueIdAndStatus(boutiqueId, ReviewStatus.PENDING);
    }

    @Transactional
    public Review createReview(UUID productId, UUID userId, String customerName, Integer rating, String comment) {
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new RuntimeException("Produit non trouvé"));

        if (userId != null && reviewRepository.existsByProductIdAndUserId(productId, userId)) {
            throw new RuntimeException("Vous avez déjà donné un avis sur ce produit");
        }

        Review review = Review.builder()
                .product(product)
                .boutique(product.getBoutique())
                .user(userId != null ? userRepository.getReferenceById(userId) : null)
                .customerName(customerName)
                .rating(rating)
                .comment(comment)
                .status(ReviewStatus.PENDING)
                .build();
        review = reviewRepository.save(review);
        telegramNotificationService.notifyNewReview(review);
        return review;
    }

    @Transactional
    public Review approveReview(UUID reviewId, UUID boutiqueId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new RuntimeException("Avis non trouvé"));
        if (!review.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Vous n'êtes pas autorisé à modérer cet avis");
        }
        review.setStatus(ReviewStatus.APPROVED);
        return reviewRepository.save(review);
    }

    @Transactional
    public Review rejectReview(UUID reviewId, UUID boutiqueId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new RuntimeException("Avis non trouvé"));
        if (!review.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Vous n'êtes pas autorisé à modérer cet avis");
        }
        review.setStatus(ReviewStatus.REJECTED);
        return reviewRepository.save(review);
    }

    @Transactional
    public Review replyToReview(UUID reviewId, UUID boutiqueId, String ownerReply) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new RuntimeException("Avis non trouvé"));
        if (!review.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Vous n'êtes pas autorisé à répondre à cet avis");
        }
        review.setOwnerReply(ownerReply);
        return reviewRepository.save(review);
    }

    @Transactional
    public void deleteReview(UUID reviewId, UUID boutiqueId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new RuntimeException("Avis non trouvé"));
        if (!review.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Vous n'êtes pas autorisé à supprimer cet avis");
        }
        reviewRepository.delete(review);
    }
}
