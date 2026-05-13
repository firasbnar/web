package io.makewebsite.service;

import io.makewebsite.dto.request.SubscribeRequest;
import io.makewebsite.dto.response.PlanResponse;
import io.makewebsite.dto.response.SubscriptionResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PlanService {
    private final PlanRepository planRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final UserRepository userRepository;

    public List<PlanResponse> getPlans() {
        return planRepository.findAll().stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    public SubscriptionResponse getMySubscription(UUID userId) {
        return subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .map(this::mapToSubscriptionResponse).orElse(null);
    }

    public List<SubscriptionResponse> getSubscriptionHistory(UUID userId) {
        return subscriptionRepository.findByUserId(userId).stream()
                .map(this::mapToSubscriptionResponse).collect(Collectors.toList());
    }

    @Transactional
    public SubscriptionResponse subscribe(UUID userId, SubscribeRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Plan plan = planRepository.findById(request.getPlanId())
                .orElseThrow(() -> new RuntimeException("Plan non trouvé"));

        subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .ifPresent(s -> { s.setStatus("CANCELLED"); subscriptionRepository.save(s); });

        Subscription subscription = Subscription.builder()
                .user(user)
                .plan(plan)
                .status("ACTIVE")
                .startedAt(LocalDateTime.now())
                .expiresAt(LocalDateTime.now().plusDays(plan.getDurationDays()))
                .paymentMethod(request.getPaymentMethod())
                .build();
        subscription = subscriptionRepository.save(subscription);
        return mapToSubscriptionResponse(subscription);
    }

    private PlanResponse mapToResponse(Plan p) {
        return PlanResponse.builder()
                .id(p.getId()).name(p.getName())
                .priceDt(p.getPriceDt()).durationDays(p.getDurationDays())
                .maxProducts(p.getMaxProducts()).commissionPercent(p.getCommissionPercent())
                .features(p.getFeatures())
                .build();
    }

    private SubscriptionResponse mapToSubscriptionResponse(Subscription s) {
        return SubscriptionResponse.builder()
                .id(s.getId())
                .planId(s.getPlan().getId())
                .planName(s.getPlan().getName())
                .status(s.getStatus())
                .startedAt(s.getStartedAt())
                .expiresAt(s.getExpiresAt())
                .paymentMethod(s.getPaymentMethod())
                .paymentRef(s.getPaymentRef())
                .build();
    }
}
