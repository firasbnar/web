package io.makewebsite.controller;

import io.makewebsite.dto.request.SubscribeRequest;
import io.makewebsite.dto.response.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.PlanService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class PlanController {
    private final PlanService planService;

    @GetMapping("/plans")
    public ResponseEntity<ApiResponse<List<PlanResponse>>> getPlans() {
        return ResponseEntity.ok(ApiResponse.ok(planService.getPlans()));
    }

    @GetMapping("/subscriptions/mine")
    public ResponseEntity<ApiResponse<SubscriptionResponse>> getMySubscription(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(planService.getMySubscription(principal.getUserId())));
    }

    @GetMapping("/subscriptions/history")
    public ResponseEntity<ApiResponse<List<SubscriptionResponse>>> getSubscriptionHistory(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(planService.getSubscriptionHistory(principal.getUserId())));
    }

    @GetMapping("/subscriptions/{id}")
    public ResponseEntity<ApiResponse<SubscriptionResponse>> getSubscriptionDetails(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(planService.getSubscriptionDetails(id, principal.getUserId())));
    }

    @PostMapping("/subscriptions/subscribe")
    public ResponseEntity<ApiResponse<SubscriptionResponse>> subscribe(
            @Valid @RequestBody SubscribeRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Abonnement activé",
                planService.subscribe(principal.getUserId(), request)));
    }

    @PostMapping("/subscriptions/checkout-session")
    public ResponseEntity<ApiResponse<SubscriptionCheckoutResponse>> createStripeCheckoutSession(
            @Valid @RequestBody SubscribeRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(
                "Session Stripe créée",
                planService.createStripeCheckoutSession(principal.getUserId(), request)
        ));
    }

    @GetMapping("/subscriptions/checkout-status")
    public ResponseEntity<ApiResponse<SubscriptionCheckoutStatusResponse>> getCheckoutStatus(
            @RequestParam String sessionId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(
                planService.getCheckoutStatus(principal.getUserId(), sessionId)
        ));
    }

    @PostMapping("/subscriptions/upgrade")
    public ResponseEntity<ApiResponse<SubscriptionResponse>> upgrade(
            @Valid @RequestBody SubscribeRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Abonnement mis à niveau",
                planService.upgradeSubscription(principal.getUserId(), request)));
    }

    @PostMapping("/subscriptions/cancel")
    public ResponseEntity<ApiResponse<Void>> cancelSubscription(
            @AuthenticationPrincipal UserPrincipal principal) {
        planService.cancelSubscription(principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Abonnement résilié", null));
    }

    @GetMapping("/invoices")
    public ResponseEntity<ApiResponse<List<InvoiceResponse>>> getInvoices(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(planService.getInvoices(principal.getUserId())));
    }

    @GetMapping("/subscriptions/invoices")
    public ResponseEntity<ApiResponse<List<InvoiceResponse>>> getSubscriptionInvoices(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(planService.getInvoices(principal.getUserId())));
    }
}
