package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Review;
import io.makewebsite.entity.ReviewStatus;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.User;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.UserRepository;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.ReviewService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import org.springframework.transaction.annotation.Transactional;

@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class ReviewAdminController {
    private final ReviewService reviewService;
    private final BoutiqueRepository boutiqueRepository;
    private final UserRepository userRepository;

    private Boutique getOwnedBoutique(UUID boutiqueId, UUID userId) {
        return boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
    }

    @GetMapping("/boutique/{boutiqueId}")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBoutiqueReviews(
            @PathVariable UUID boutiqueId,
            @RequestParam(required = false) String status,
            Pageable pageable,
            @AuthenticationPrincipal UserPrincipal principal) {
        getOwnedBoutique(boutiqueId, principal.getUserId());
        ReviewStatus filter = status != null ? ReviewStatus.valueOf(status.toUpperCase()) : null;
        Page<Review> page = reviewService.getBoutiqueReviews(boutiqueId, filter, pageable);
        long pendingCount = reviewService.getPendingCount(boutiqueId);

        List<Map<String, Object>> list = page.getContent().stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", r.getId());
            m.put("productId", r.getProduct().getId());
            m.put("productName", r.getProduct().getName());
            m.put("customerName", r.getCustomerName());
            m.put("rating", r.getRating());
            m.put("comment", r.getComment());
            m.put("ownerReply", r.getOwnerReply());
            m.put("status", r.getStatus().name());
            m.put("createdAt", r.getCreatedAt());
            return m;
        }).toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", list);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        result.put("pendingCount", pendingCount);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/boutique/{boutiqueId}/pending-count")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getPendingCount(
            @PathVariable UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        getOwnedBoutique(boutiqueId, principal.getUserId());
        long count = reviewService.getPendingCount(boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("pendingCount", count)));
    }

    @PutMapping("/{id}/approve")
    public ResponseEntity<ApiResponse<Map<String, Object>>> approveReview(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (user.getActiveBoutiqueId() == null) {
            throw new RuntimeException("Aucune boutique active");
        }
        Review r = reviewService.approveReview(id, user.getActiveBoutiqueId());
        return ResponseEntity.ok(ApiResponse.ok("Avis approuvé", Map.of("status", r.getStatus().name())));
    }

    @PutMapping("/{id}/reject")
    public ResponseEntity<ApiResponse<Map<String, Object>>> rejectReview(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (user.getActiveBoutiqueId() == null) {
            throw new RuntimeException("Aucune boutique active");
        }
        Review r = reviewService.rejectReview(id, user.getActiveBoutiqueId());
        return ResponseEntity.ok(ApiResponse.ok("Avis rejeté", Map.of("status", r.getStatus().name())));
    }

    @PutMapping("/{id}/reply")
    public ResponseEntity<ApiResponse<Map<String, Object>>> replyToReview(
            @PathVariable UUID id,
            @RequestBody ReplyRequest req,
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (user.getActiveBoutiqueId() == null) {
            throw new RuntimeException("Aucune boutique active");
        }
        Review r = reviewService.replyToReview(id, user.getActiveBoutiqueId(), req.getOwnerReply());
        return ResponseEntity.ok(ApiResponse.ok("Réponse ajoutée", Map.of("ownerReply", r.getOwnerReply())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteReview(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (user.getActiveBoutiqueId() == null) {
            throw new RuntimeException("Aucune boutique active");
        }
        reviewService.deleteReview(id, user.getActiveBoutiqueId());
        return ResponseEntity.ok(ApiResponse.ok("Avis supprimé", null));
    }
}

@Data
class ReplyRequest {
    private String ownerReply;
}
