package io.makewebsite.controller;

import com.stripe.model.Event;
import com.stripe.model.EventDataObjectDeserializer;
import com.stripe.model.PaymentIntent;
import com.stripe.model.checkout.Session;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Order;
import io.makewebsite.repository.OrderRepository;
import io.makewebsite.service.PaymentService;
import io.makewebsite.service.TelegramNotificationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentWebhookController {

    private final OrderRepository orderRepository;
    private final PaymentService paymentService;
    private final TelegramNotificationService telegramNotificationService;

    @PostMapping("/stripe/webhook")
    public ResponseEntity<String> handleStripeWebhook(HttpServletRequest request) {
        String payload;
        String sigHeader;
        try {
            payload = new String(request.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
            sigHeader = request.getHeader("Stripe-Signature");
        } catch (IOException e) {
            log.error("Stripe webhook: failed to read request body: {}", e.getMessage());
            return ResponseEntity.status(400).body("Invalid payload");
        }

        if (sigHeader == null || sigHeader.isBlank()) {
            log.warn("Stripe webhook: missing Stripe-Signature header");
            return ResponseEntity.status(400).body("Missing signature");
        }

        Event event;
        try {
            event = paymentService.parseStripeWebhook(payload, sigHeader);
        } catch (Exception e) {
            log.warn("Stripe webhook: signature verification failed: {}", e.getMessage());
            return ResponseEntity.status(400).body("Invalid signature");
        }

        log.info("Stripe webhook received: type={}", event.getType());

        String eventType = event.getType();

        switch (eventType) {
            case "checkout.session.completed" -> handleCheckoutCompleted(event);
            case "payment_intent.succeeded" -> handlePaymentIntentSucceeded(event);
            case "payment_intent.payment_failed" -> handlePaymentIntentFailed(event);
            default -> log.info("Stripe webhook: unhandled event type={}", eventType);
        }

        return ResponseEntity.ok("OK");
    }

    private void handleCheckoutCompleted(Event event) {
        EventDataObjectDeserializer deserializer = event.getDataObjectDeserializer();
        Session session = (Session) deserializer.getObject().orElse(null);
        if (session == null) {
            log.warn("Stripe webhook: failed to deserialize session from checkout.session.completed event");
            return;
        }
        String orderNumber = session.getMetadata().get("orderNumber");
        String paymentRef = session.getId();
        if (orderNumber == null || orderNumber.isBlank()) {
            log.warn("Stripe webhook: no orderNumber in session metadata (session={})", session.getId());
            return;
        }
        log.info("Stripe webhook: checkout.session.completed for order {} (session={})", orderNumber, paymentRef);
        markOrderPaid(orderNumber, paymentRef);
    }

    private void handlePaymentIntentSucceeded(Event event) {
        EventDataObjectDeserializer deserializer = event.getDataObjectDeserializer();
        PaymentIntent paymentIntent = (PaymentIntent) deserializer.getObject().orElse(null);
        if (paymentIntent == null) {
            log.warn("Stripe webhook: failed to deserialize payment_intent from event");
            return;
        }
        String orderNumber = paymentIntent.getMetadata().get("orderNumber");
        String paymentRef = paymentIntent.getId();
        if (orderNumber == null || orderNumber.isBlank()) {
            log.warn("Stripe webhook: no orderNumber in payment_intent metadata (pi={})", paymentIntent.getId());
            return;
        }
        log.info("Stripe webhook: payment_intent.succeeded for order {} (pi={})", orderNumber, paymentRef);
        markOrderPaid(orderNumber, paymentRef);
    }

    private void handlePaymentIntentFailed(Event event) {
        EventDataObjectDeserializer deserializer = event.getDataObjectDeserializer();
        PaymentIntent paymentIntent = (PaymentIntent) deserializer.getObject().orElse(null);
        if (paymentIntent == null) {
            log.warn("Stripe webhook: failed to deserialize payment_intent from payment_failed event");
            return;
        }
        String orderNumber = paymentIntent.getMetadata().get("orderNumber");
        log.warn("Stripe webhook: payment_intent.payment_failed for order {}", orderNumber);
        if (orderNumber == null || orderNumber.isBlank()) return;

        orderRepository.findByOrderNumber(orderNumber).ifPresent(order -> {
            order.setPaymentStatus("FAILED");
            order.setPaymentMethod("STRIPE");
            orderRepository.save(order);
            log.info("Stripe webhook: order {} marked FAILED", orderNumber);
        });
    }

    private void markOrderPaid(String orderNumber, String paymentRef) {
        orderRepository.findByOrderNumber(orderNumber).ifPresentOrElse(order -> {
            if ("PAID".equals(order.getPaymentStatus())) {
                log.info("Stripe webhook: order {} already PAID, skipping duplicate webhook (ref={})",
                        orderNumber, order.getPaymentRef());
                return;
            }
            order.setPaymentStatus("PAID");
            order.setPaymentRef(paymentRef);
            order.setPaymentMethod("STRIPE");
            orderRepository.save(order);
            log.info("Stripe webhook: order {} marked PAID (ref={})", orderNumber, paymentRef);
            telegramNotificationService.notifyPaymentValidated(order, "STRIPE", paymentRef);
        }, () -> log.warn("Stripe webhook: order {} not found in database", orderNumber));
    }

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
                telegramNotificationService.notifyPaymentValidated(order, "D17", paymentRef);
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
                telegramNotificationService.notifyPaymentValidated(order, "Konnect", null);
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
