package io.makewebsite.service;

import io.makewebsite.dto.request.CreateCouponRequest;
import io.makewebsite.dto.request.ValidateCouponRequest;
import io.makewebsite.dto.response.CouponResponse;
import io.makewebsite.dto.response.CouponValidationResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CouponService {
    private final CouponRepository couponRepository;
    private final BoutiqueRepository boutiqueRepository;

    public List<CouponResponse> getCoupons(UUID boutiqueId) {
        return couponRepository.findByBoutiqueId(boutiqueId).stream()
                .map(this::mapToResponse).collect(Collectors.toList());
    }

    @Transactional
    public CouponResponse createCoupon(CreateCouponRequest request) {
        Boutique boutique = boutiqueRepository.findById(request.getBoutiqueId())
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        Coupon coupon = Coupon.builder()
                .boutique(boutique)
                .code(request.getCode().toUpperCase())
                .discountType(request.getDiscountType())
                .discountValue(request.getDiscountValue())
                .minOrderAmount(request.getMinOrderAmount())
                .maxUses(request.getMaxUses())
                .usedCount(0)
                .expiresAt(request.getExpiresAt())
                .isActive(true)
                .build();
        coupon = couponRepository.save(coupon);
        return mapToResponse(coupon);
    }

    @Transactional
    public CouponResponse updateCoupon(UUID id, CreateCouponRequest request) {
        Coupon coupon = couponRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Code promo non trouvé"));
        if (request.getCode() != null) coupon.setCode(request.getCode().toUpperCase());
        if (request.getDiscountType() != null) coupon.setDiscountType(request.getDiscountType());
        if (request.getDiscountValue() != null) coupon.setDiscountValue(request.getDiscountValue());
        if (request.getMinOrderAmount() != null) coupon.setMinOrderAmount(request.getMinOrderAmount());
        if (request.getMaxUses() != null) coupon.setMaxUses(request.getMaxUses());
        if (request.getExpiresAt() != null) coupon.setExpiresAt(request.getExpiresAt());
        if (request.getIsActive() != null) coupon.setIsActive(request.getIsActive());
        coupon = couponRepository.save(coupon);
        return mapToResponse(coupon);
    }

    @Transactional
    public CouponResponse toggleActive(UUID id) {
        Coupon coupon = couponRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Code promo non trouvé"));
        boolean previous = coupon.getIsActive() != null && coupon.getIsActive();
        coupon.setIsActive(!previous);
        coupon = couponRepository.save(coupon);
        log.info("Coupon toggleActive: id={}, code={}, boutiqueId={}, previous={}, new={}",
                id, coupon.getCode(), coupon.getBoutique().getId(), previous, coupon.getIsActive());
        return mapToResponse(coupon);
    }

    @Transactional
    public void deleteCoupon(UUID id) {
        couponRepository.deleteById(id);
    }

    public CouponValidationResponse validateCoupon(ValidateCouponRequest request) {
        Coupon coupon = couponRepository.findByBoutiqueIdAndCode(request.getBoutiqueId(), request.getCode())
                .orElse(null);
        if (coupon == null || !coupon.getIsActive()) {
            return CouponValidationResponse.builder()
                    .valid(false).discountAmount(BigDecimal.ZERO)
                    .finalAmount(request.getOrderAmount())
                    .message("Code promo invalide ou expiré").build();
        }
        if (coupon.getExpiresAt() != null && coupon.getExpiresAt().isBefore(LocalDateTime.now())) {
            return CouponValidationResponse.builder()
                    .valid(false).discountAmount(BigDecimal.ZERO)
                    .finalAmount(request.getOrderAmount())
                    .message("Code promo expiré").build();
        }
        if (coupon.getMaxUses() != null && coupon.getUsedCount() >= coupon.getMaxUses()) {
            return CouponValidationResponse.builder()
                    .valid(false).discountAmount(BigDecimal.ZERO)
                    .finalAmount(request.getOrderAmount())
                    .message("Code promo épuisé").build();
        }
        if (coupon.getMinOrderAmount() != null && request.getOrderAmount().compareTo(coupon.getMinOrderAmount()) < 0) {
            return CouponValidationResponse.builder()
                    .valid(false).discountAmount(BigDecimal.ZERO)
                    .finalAmount(request.getOrderAmount())
                    .message("Montant minimum non atteint (" + coupon.getMinOrderAmount() + " TND)").build();
        }

        BigDecimal discount;
        if ("PERCENT".equals(coupon.getDiscountType())) {
            discount = request.getOrderAmount().multiply(coupon.getDiscountValue()).divide(BigDecimal.valueOf(100));
        } else {
            discount = coupon.getDiscountValue();
        }

        BigDecimal finalAmount = request.getOrderAmount().subtract(discount);
        if (finalAmount.compareTo(BigDecimal.ZERO) < 0) finalAmount = BigDecimal.ZERO;

        coupon.setUsedCount(coupon.getUsedCount() + 1);
        couponRepository.save(coupon);

        return CouponValidationResponse.builder()
                .valid(true).discountAmount(discount)
                .finalAmount(finalAmount)
                .message("Code promo appliqué!").build();
    }

    private CouponResponse mapToResponse(Coupon c) {
        return CouponResponse.builder()
                .id(c.getId()).boutiqueId(c.getBoutique().getId())
                .code(c.getCode()).discountType(c.getDiscountType())
                .discountValue(c.getDiscountValue()).minOrderAmount(c.getMinOrderAmount())
                .maxUses(c.getMaxUses()).usedCount(c.getUsedCount())
                .expiresAt(c.getExpiresAt()).isActive(c.getIsActive())
                .build();
    }
}
