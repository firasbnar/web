package io.makewebsite.controller;

import com.fasterxml.jackson.databind.JsonNode;
import io.makewebsite.dto.request.CreatePaymentRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {
    private final PaymentService paymentService;

    @PostMapping("/paypal/create-order")
    public ResponseEntity<ApiResponse<JsonNode>> createPayPalOrder(@Valid @RequestBody CreatePaymentRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.createPayPalOrder(request)));
    }

    @PostMapping("/paypal/capture")
    public ResponseEntity<ApiResponse<JsonNode>> capturePayPalOrder(@RequestParam String orderId) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.capturePayPalOrder(orderId)));
    }

    @PostMapping("/d17/webhook")
    public ResponseEntity<String> handleD17Webhook(@RequestBody String payload) {
        return ResponseEntity.ok(paymentService.handleD17Webhook(payload));
    }

    @PostMapping("/stripe/create-intent")
    public ResponseEntity<ApiResponse<JsonNode>> createStripeIntent(@Valid @RequestBody CreatePaymentRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.createStripePaymentIntent(request)));
    }

    @PostMapping("/stripe/confirm")
    public ResponseEntity<ApiResponse<JsonNode>> confirmStripe(@RequestParam String paymentIntentId) {
        return ResponseEntity.ok(ApiResponse.ok(paymentService.confirmStripePayment(paymentIntentId)));
    }
}
