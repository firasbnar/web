package io.makewebsite.controller;

import io.makewebsite.dto.request.AddToCartRequest;
import io.makewebsite.dto.request.UpdateCartItemRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.CartResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.CartService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/cart")
@RequiredArgsConstructor
public class CartController {
    private final CartService cartService;

    @GetMapping
    public ResponseEntity<ApiResponse<CartResponse>> getCart(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(cartService.getCart(principal.getUserId(), boutiqueId)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CartResponse>> addItem(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody AddToCartRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Ajouté au panier", cartService.addItem(principal.getUserId(), request)));
    }

    @PutMapping("/{itemId}")
    public ResponseEntity<ApiResponse<CartResponse>> updateItem(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID itemId,
            @Valid @RequestBody UpdateCartItemRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Quantité mise à jour", cartService.updateItem(principal.getUserId(), itemId, request)));
    }

    @DeleteMapping("/{itemId}")
    public ResponseEntity<ApiResponse<CartResponse>> removeItem(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID itemId) {
        return ResponseEntity.ok(ApiResponse.ok("Retiré du panier", cartService.removeItem(principal.getUserId(), itemId)));
    }

    @DeleteMapping
    public ResponseEntity<ApiResponse<Void>> clearCart(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam UUID boutiqueId) {
        cartService.clearCart(principal.getUserId(), boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok("Panier vidé", null));
    }
}
