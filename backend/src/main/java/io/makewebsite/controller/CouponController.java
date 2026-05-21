package io.makewebsite.controller;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.service.CouponService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/coupons")
@RequiredArgsConstructor
public class CouponController {
    private final CouponService couponService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CouponResponse>>> getCoupons(@RequestParam UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(couponService.getCoupons(boutiqueId)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CouponResponse>> createCoupon(@Valid @RequestBody CreateCouponRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Code promo créé", couponService.createCoupon(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CouponResponse>> updateCoupon(@PathVariable UUID id, @Valid @RequestBody CreateCouponRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Code promo mis à jour", couponService.updateCoupon(id, request)));
    }

    @PutMapping("/{id}/toggle-active")
    public ResponseEntity<ApiResponse<ToggleStatusResponse>> toggleActive(@PathVariable UUID id) {
        CouponResponse coupon = couponService.toggleActive(id);
        ToggleStatusResponse res = ToggleStatusResponse.builder()
                .id(coupon.getId()).active(coupon.getIsActive())
                .message(coupon.getIsActive() ? "Code promo activé" : "Code promo désactivé")
                .build();
        return ResponseEntity.ok(ApiResponse.ok(res.getMessage(), res));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteCoupon(@PathVariable UUID id) {
        couponService.deleteCoupon(id);
        return ResponseEntity.ok(ApiResponse.ok("Code promo supprimé", null));
    }

    @PostMapping("/validate")
    public ResponseEntity<ApiResponse<CouponValidationResponse>> validateCoupon(@Valid @RequestBody ValidateCouponRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(couponService.validateCoupon(request)));
    }
}
