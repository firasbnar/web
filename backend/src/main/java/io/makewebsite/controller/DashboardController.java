package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.BoutiqueSummaryResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Plan;
import io.makewebsite.entity.Subscription;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.ProductRepository;
import io.makewebsite.repository.StoreViewRepository;
import io.makewebsite.repository.SubscriptionRepository;
import io.makewebsite.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final StoreViewRepository storeViewRepository;

    @GetMapping("/boutique-summary")
    public ResponseEntity<ApiResponse<BoutiqueSummaryResponse>> boutiqueSummary(
            @AuthenticationPrincipal UserPrincipal principal) {
        UUID ownerId = principal.getUserId();
        log.info("=== Dashboard boutique-summary for ownerId={} ===", ownerId);

        // Find the boutique owned by this user
        List<Boutique> boutiques = boutiqueRepository.findByUserId(ownerId);
        if (boutiques.isEmpty()) {
            log.warn("No boutique found for ownerId={}", ownerId);
            return ResponseEntity.ok(ApiResponse.error("Aucune boutique trouvée"));
        }
        Boutique boutique = boutiques.get(0);
        UUID boutiqueId = boutique.getId();
        log.info("boutiqueId={} boutiqueName={}", boutiqueId, boutique.getName());

        // Count products
        long productCount = productRepository.countByBoutiqueId(boutiqueId);
        log.info("productCount={}", productCount);

        // Count visits from StoreView records (each public store page open = 1 view)
        long views = storeViewRepository.countByBoutiqueId(boutiqueId);
        log.info("viewsCount={} (from store_views table)", views);

        // Calculate remaining subscription days
        long remainingDays = -1;
        String planName = "Free";
        String subscriptionStatus = "FREE";
        String subscriptionEndDate = null;
        try {
            List<Subscription> subscriptions = subscriptionRepository.findByUserId(ownerId);
            log.info("Found {} subscriptions for ownerId={}", subscriptions.size(), ownerId);
            if (!subscriptions.isEmpty()) {
                Subscription sub = subscriptions.get(0);
                UUID subId = sub.getId();
                String rawStatus = sub.getStatus();
                Plan plan = sub.getPlan();
                String rawPlanName = plan.getName();
                Integer durationDays = plan.getDurationDays();
                LocalDateTime startDt = sub.getStartedAt();
                LocalDateTime endDt = sub.getExpiresAt();
                log.info("subscriptionId={} planName={} durationDays={} status={} startDate={} endDate={}",
                        subId, rawPlanName, durationDays, rawStatus, startDt, endDt);

                planName = rawPlanName;
                subscriptionEndDate = endDt != null ? endDt.toLocalDate().toString() : null;

                if ("ACTIVE".equals(rawStatus)) {
                    subscriptionStatus = "ACTIVE";
                    if (endDt != null) {
                        LocalDate expiresDate = endDt.toLocalDate();
                        long days = ChronoUnit.DAYS.between(LocalDate.now(), expiresDate);
                        if (days > 36500) {
                            remainingDays = -1;
                            log.info("Plan is unlimited (days>36500), setting remainingDays=-1");
                        } else if (days < 0) {
                            remainingDays = 0;
                            subscriptionStatus = "EXPIRED";
                            log.info("Subscription expired, days={}", days);
                        } else {
                            remainingDays = days;
                            log.info("Active subscription, remainingDays={}", days);
                        }
                    }
                } else if ("TRIAL".equals(rawStatus)) {
                    subscriptionStatus = "TRIAL";
                    planName = "Essai gratuit";
                    if (endDt != null) {
                        long days = ChronoUnit.DAYS.between(LocalDate.now(), endDt.toLocalDate());
                        remainingDays = days < 0 ? 0 : days;
                    }
                    log.info("Trial subscription, remainingDays={}", remainingDays);
                } else if ("EXPIRED".equals(rawStatus) || "CANCELLED".equals(rawStatus)) {
                    subscriptionStatus = "EXPIRED";
                    remainingDays = 0;
                    log.info("Subscription is expired/cancelled");
                } else {
                    subscriptionStatus = rawStatus;
                    log.info("Unknown subscription status={}, treating as active", rawStatus);
                    if (endDt != null) {
                        long days = ChronoUnit.DAYS.between(LocalDate.now(), endDt.toLocalDate());
                        remainingDays = days < 0 ? 0 : days;
                    }
                }
            } else {
                log.info("No subscriptions found for ownerId={}, user is on Free plan", ownerId);
            }
        } catch (Exception e) {
            log.error("Failed to load subscription for ownerId={}: {}", ownerId, e.getMessage(), e);
            subscriptionStatus = "ERROR";
            planName = "Erreur";
            remainingDays = 0;
        }
        log.info("Calculated: remainingDays={} planName={} subscriptionStatus={} subscriptionEndDate={}",
                remainingDays, planName, subscriptionStatus, subscriptionEndDate);

        // Publication status
        String publicationStatus;
        if ("FROZEN".equals(boutique.getStoreStatus())) publicationStatus = "FROZEN";
        else if ("SUSPENDED".equals(boutique.getStoreStatus())) publicationStatus = "SUSPENDED";
        else if (Boolean.FALSE.equals(boutique.getIsPublished())) publicationStatus = "DRAFT";
        else publicationStatus = "PUBLISHED";

        BoutiqueSummaryResponse response = BoutiqueSummaryResponse.builder()
                .boutiqueId(boutiqueId)
                .boutiqueName(boutique.getName())
                .publicUrl("/store/" + boutique.getSlug())
                .views(views)
                .products(productCount)
                .remainingDays(remainingDays)
                .planName(planName)
                .subscriptionStatus(subscriptionStatus)
                .subscriptionEndDate(subscriptionEndDate)
                .publicationStatus(publicationStatus)
                .build();

        log.info("=== Dashboard response: boutiqueId={} views={} products={} remainingDays={} planName={} status={} endDate={} ===",
                response.getBoutiqueId(), response.getViews(), response.getProducts(),
                response.getRemainingDays(), response.getPlanName(), response.getSubscriptionStatus(), response.getSubscriptionEndDate());

        return ResponseEntity.ok(ApiResponse.ok(response));
    }
}