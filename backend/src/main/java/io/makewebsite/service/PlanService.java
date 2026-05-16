package io.makewebsite.service;

import io.makewebsite.dto.request.SubscribeRequest;
import io.makewebsite.dto.response.PlanResponse;
import io.makewebsite.dto.response.SubscriptionResponse;
import io.makewebsite.dto.response.InvoiceResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PlanService {
    private final PlanRepository planRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final InvoiceRepository invoiceRepository;
    private final UserRepository userRepository;

    public List<PlanResponse> getPlans() {
        return planRepository.findAll().stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public SubscriptionResponse getMySubscription(UUID userId) {
        Subscription sub = subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE").orElse(null);
        if (sub == null) {
            return SubscriptionResponse.builder()
                    .planName("Free")
                    .status("FREE")
                    .build();
        }
        return mapToSubscriptionResponse(sub);
    }

    public List<SubscriptionResponse> getSubscriptionHistory(UUID userId) {
        return subscriptionRepository.findByUserId(userId).stream()
                .map(this::mapToSubscriptionResponse)
                .collect(Collectors.toList());
    }

    public List<InvoiceResponse> getInvoices(UUID userId) {
        return invoiceRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::mapToInvoiceResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public SubscriptionResponse subscribe(UUID userId, SubscribeRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Plan plan = planRepository.findById(request.getPlanId())
                .orElseThrow(() -> new RuntimeException("Plan non trouvé"));

        // Deactivate any existing active subscription
        subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .ifPresent(s -> { s.setStatus("CANCELLED"); subscriptionRepository.save(s); });

        Subscription sub = Subscription.builder()
                .user(user)
                .plan(plan)
                .status("ACTIVE")
                .startedAt(LocalDateTime.now())
                .expiresAt(LocalDateTime.now().plusDays(plan.getDurationDays()))
                .paymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "BANK")
                .build();
        sub = subscriptionRepository.save(sub);

        // Create invoice
        Invoice invoice = Invoice.builder()
                .user(user)
                .subscription(sub)
                .amount(plan.getPriceDt())
                .currency("TND")
                .status("PENDING")
                .paymentMethod(sub.getPaymentMethod())
                .build();
        invoiceRepository.save(invoice);

        return mapToSubscriptionResponse(sub);
    }

    @Transactional
    public void cancelSubscription(UUID userId) {
        Subscription sub = subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .orElseThrow(() -> new RuntimeException("Aucun abonnement actif"));
        sub.setStatus("CANCELLED");
        subscriptionRepository.save(sub);
    }

    @Transactional
    public SubscriptionResponse upgradeSubscription(UUID userId, SubscribeRequest request) {
        // Cancel current, then subscribe to new
        subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .ifPresent(s -> { s.setStatus("UPGRADED"); subscriptionRepository.save(s); });
        return subscribe(userId, request);
    }

    public SubscriptionResponse getSubscriptionDetails(UUID subscriptionId, UUID userId) {
        Subscription sub = subscriptionRepository.findById(subscriptionId)
                .orElseThrow(() -> new RuntimeException("Abonnement non trouvé"));
        if (!sub.getUser().getId().equals(userId)) {
            throw new RuntimeException("Accès refusé");
        }
        return mapToSubscriptionResponse(sub);
    }

    private PlanResponse mapToResponse(Plan plan) {
        return PlanResponse.builder()
                .id(plan.getId())
                .name(plan.getName())
                .priceDt(plan.getPriceDt())
                .durationDays(plan.getDurationDays())
                .maxProducts(plan.getMaxProducts())
                .commissionPercent(plan.getCommissionPercent())
                .features(plan.getFeatures())
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

    private InvoiceResponse mapToInvoiceResponse(Invoice inv) {
        return InvoiceResponse.builder()
                .id(inv.getId())
                .userId(inv.getUser().getId())
                .subscriptionId(inv.getSubscription() != null ? inv.getSubscription().getId() : null)
                .amount(inv.getAmount())
                .currency(inv.getCurrency())
                .status(inv.getStatus())
                .paymentMethod(inv.getPaymentMethod())
                .paymentRef(inv.getPaymentRef())
                .createdAt(inv.getCreatedAt())
                .build();
    }
}
