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
    public ResponseEntity<ApiResponse<SubscriptionResponse>> getMySubscription(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(planService.getMySubscription(principal.getUserId())));
    }

    @PostMapping("/subscriptions/subscribe")
    public ResponseEntity<ApiResponse<SubscriptionResponse>> subscribe(@Valid @RequestBody SubscribeRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Abonnement activé", planService.subscribe(principal.getUserId(), request)));
    }
}
