package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Review;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.ReviewService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/products/{productId}/reviews")
@RequiredArgsConstructor
public class ReviewController {
    private final ReviewService reviewService;

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> getReviews(@PathVariable UUID productId, Pageable pageable) {
        Page<Review> page = reviewService.getProductReviews(productId, true, pageable);
        long count = page.getTotalElements();
        double avgRating = 0;
        if (count > 0 && !page.getContent().isEmpty()) {
            avgRating = page.getContent().stream().mapToInt(Review::getRating).average().orElse(0);
        }

        List<Map<String, Object>> list = page.getContent().stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", r.getId());
            m.put("customerName", r.getCustomerName());
            m.put("rating", r.getRating());
            m.put("comment", r.getComment());
            m.put("createdAt", r.getCreatedAt());
            return m;
        }).toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", list);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        result.put("totalReviews", count);
        result.put("averageRating", avgRating);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> createReview(
            @PathVariable UUID productId,
            @Valid @RequestBody ReviewRequest req,
            @AuthenticationPrincipal UserPrincipal principal) {
        UUID userId = principal != null ? principal.getUserId() : null;
        Review r = reviewService.createReview(productId, userId, req.getCustomerName(), req.getRating(), req.getComment());

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("customerName", r.getCustomerName());
        m.put("rating", r.getRating());
        m.put("comment", r.getComment());
        m.put("createdAt", r.getCreatedAt());
        return ResponseEntity.ok(ApiResponse.ok("Avis ajouté. En attente de modération.", m));
    }
}

@Data
class ReviewRequest {
    @NotBlank
    private String customerName;
    @NotNull @Min(1) @Max(5)
    private Integer rating;
    private String comment;
}
