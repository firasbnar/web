package io.makewebsite.controller;

import io.makewebsite.dto.request.ToggleWishlistRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.WishlistItemResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.WishlistService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/wishlist")
@RequiredArgsConstructor
public class WishlistController {
    private final WishlistService wishlistService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<WishlistItemResponse>>> getWishlist(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(wishlistService.getWishlist(principal.getUserId())));
    }

    @GetMapping("/check")
    public ResponseEntity<ApiResponse<Boolean>> check(@AuthenticationPrincipal UserPrincipal principal, @RequestParam UUID productId) {
        return ResponseEntity.ok(ApiResponse.ok(wishlistService.isInWishlist(principal.getUserId(), productId)));
    }

    @GetMapping("/count")
    public ResponseEntity<ApiResponse<Long>> count(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(wishlistService.getCount(principal.getUserId())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<WishlistItemResponse>> toggle(@AuthenticationPrincipal UserPrincipal principal, @Valid @RequestBody ToggleWishlistRequest request) {
        WishlistItemResponse result = wishlistService.toggle(principal.getUserId(), request.getProductId());
        if (result == null) {
            return ResponseEntity.ok(ApiResponse.ok("Retiré des favoris", null));
        }
        return ResponseEntity.ok(ApiResponse.ok("Ajouté aux favoris", result));
    }

    @DeleteMapping("/{productId}")
    public ResponseEntity<ApiResponse<Void>> remove(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID productId) {
        wishlistService.remove(principal.getUserId(), productId);
        return ResponseEntity.ok(ApiResponse.ok("Retiré des favoris", null));
    }
}
