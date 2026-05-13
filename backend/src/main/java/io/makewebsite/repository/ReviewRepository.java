package io.makewebsite.repository;

import io.makewebsite.entity.Review;
import io.makewebsite.entity.ReviewStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ReviewRepository extends JpaRepository<Review, UUID> {
    Page<Review> findByProductIdOrderByCreatedAtDesc(UUID productId, Pageable pageable);

    Page<Review> findByProductIdAndStatusOrderByCreatedAtDesc(UUID productId, ReviewStatus status, Pageable pageable);

    Page<Review> findByBoutiqueIdOrderByCreatedAtDesc(UUID boutiqueId, Pageable pageable);

    Page<Review> findByBoutiqueIdAndStatusOrderByCreatedAtDesc(UUID boutiqueId, ReviewStatus status, Pageable pageable);

    long countByProductId(UUID productId);

    long countByBoutiqueIdAndStatus(UUID boutiqueId, ReviewStatus status);

    boolean existsByProductIdAndUserId(UUID productId, UUID userId);

    @Query("SELECT COALESCE(AVG(r.rating), 0) FROM Review r WHERE r.product.id = :productId AND r.status = 'APPROVED'")
    double avgRatingByProductId(@Param("productId") UUID productId);

    @Query("SELECT COALESCE(AVG(r.rating), 0) FROM Review r WHERE r.boutique.id = :boutiqueId AND r.status = 'APPROVED'")
    double avgRatingByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);
}
