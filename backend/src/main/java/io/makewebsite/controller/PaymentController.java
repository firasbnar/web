package io.makewebsite.controller;

import com.fasterxml.jackson.databind.JsonNode;
import io.makewebsite.dto.request.CreatePaymentRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {
    private final PaymentService paymentService;

    @PostMapping("/stripe/create-intent")
    public ResponseEntity<ApiResponse<JsonNode>> createStripeIntent(@Valid @RequestBody CreatePaymentRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.createStripePaymentIntent(request)));
    }

    @PostMapping("/stripe/confirm")
    public ResponseEntity<ApiResponse<JsonNode>> confirmStripe(@RequestParam String paymentIntentId) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.confirmStripePayment(paymentIntentId)));
    }

    @PostMapping("/stripe/create-checkout-session")
    public ResponseEntity<ApiResponse<JsonNode>> createCheckoutSession(
            @Valid @RequestBody CreatePaymentRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        if (request.getOrderNumber() != null && principal != null) {
            paymentService.validateUserOwnsOrder(request.getOrderNumber(), principal.getUserId());
        }
        return ResponseEntity.ok(ApiResponse.ok(paymentService.createStripeCheckoutSession(request)));
    }
}
