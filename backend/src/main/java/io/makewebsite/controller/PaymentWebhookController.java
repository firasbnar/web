package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Order;
import io.makewebsite.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentWebhookController {

    private final OrderRepository orderRepository;

    @PostMapping("/d17/webhook")
    public ResponseEntity<ApiResponse<Void>> handleD17Webhook(@RequestBody Map<String, Object> payload) {
        log.info("D17 webhook received: {}", payload);
        String orderRef = (String) payload.get("order_ref");
        String status = (String) payload.get("status");
        String paymentRef = (String) payload.get("payment_ref");

        if (orderRef != null && "completed".equalsIgnoreCase(status)) {
            Optional<Order> orderOpt = orderRepository.findByOrderNumber(orderRef);
            orderOpt.ifPresent(order -> {
                order.setPaymentStatus("PAID");
                order.setPaymentRef(paymentRef);
                order.setPaymentMethod("D17");
                orderRepository.save(order);
                log.info("D17 payment confirmed for order {}", orderRef);
            });
        }
        return ResponseEntity.ok(ApiResponse.ok("OK", null));
    }

    @PostMapping("/konnect/webhook")
    public ResponseEntity<ApiResponse<Void>> handleKonnectWebhook(@RequestBody Map<String, Object> payload) {
        log.info("Konnect webhook received: {}", payload);
        String orderRef = (String) payload.get("order_ref");
        String status = (String) payload.get("status");

        if (orderRef != null && "completed".equalsIgnoreCase(status)) {
            Optional<Order> orderOpt = orderRepository.findByOrderNumber(orderRef);
            orderOpt.ifPresent(order -> {
                order.setPaymentStatus("PAID");
                order.setPaymentMethod("Konnect");
                orderRepository.save(order);
                log.info("Konnect payment confirmed for order {}", orderRef);
            });
        }
        return ResponseEntity.ok(ApiResponse.ok("OK", null));
    }

    @PostMapping("/konnect/init")
    public ResponseEntity<ApiResponse<Map<String, String>>> initKonnectPayment(@RequestBody Map<String, Object> request) {
        String orderNumber = (String) request.get("order_number");
        Double amount = (Double) request.get("amount");

        log.info("Konnect payment initiation for order {} amount {}", orderNumber, amount);

        String paymentUrl = "https://sandbox.konnect.network/checkout/"
                + orderNumber + "/" + (amount != null ? String.format("%.3f", amount) : "0");

        return ResponseEntity.ok(ApiResponse.ok(Map.of(
                "payment_url", paymentUrl,
                "order_ref", orderNumber
        )));
    }
}
