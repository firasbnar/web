package io.makewebsite.controller;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.stripe.Stripe;
import com.stripe.model.Event;
import com.stripe.model.Invoice;
import com.stripe.model.PaymentIntent;
import com.stripe.model.checkout.Session;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Order;
import io.makewebsite.repository.InvoiceRepository;
import io.makewebsite.repository.OrderRepository;
import io.makewebsite.service.PlanService;
import io.makewebsite.service.PaymentService;
import io.makewebsite.service.TelegramNotificationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
@Slf4j
public class PaymentWebhookController {

    private final OrderRepository orderRepository;
    private final InvoiceRepository invoiceRepository;
    private final PaymentService paymentService;
    private final PlanService planService;
    private final TelegramNotificationService telegramNotificationService;

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    @PostMapping("/payments/stripe/webhook")
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
            case "checkout.session.completed" -> handleCheckoutCompleted(event, payload);
            case "payment_intent.succeeded" -> handlePaymentIntentSucceeded(event, payload);
            case "charge.succeeded" -> log.info("Stripe webhook: charge.succeeded acknowledged");
            case "payment_intent.payment_failed" -> handlePaymentIntentFailed(event, payload);
            case "invoice.payment_succeeded" -> handleInvoicePaymentSucceeded(event, payload);
            case "invoice.payment_failed" -> handleInvoicePaymentFailed(event, payload);
            default -> log.info("Stripe webhook: unhandled event type={}", eventType);
        }

        return ResponseEntity.ok("OK");
    }

    private void handleCheckoutCompleted(Event event, String payload) {
        try {
            String objectId = getStripeObjectIdFromPayload(payload);
            Stripe.apiKey = resolveSecretKey();
            Session session = Session.retrieve(objectId);
            log.info("checkout.session.completed: objectId={}, sessionId={}, paymentStatus={}, metadata={}",
                    objectId, session.getId(), session.getPaymentStatus(), session.getMetadata());

            if (isSubscriptionStripeEvent(session.getMetadata()) || isSubscriptionCheckoutSession(session.getId())) {
                if ("paid".equalsIgnoreCase(session.getPaymentStatus())) {
                    log.info("Activating subscription via checkout.session.completed: sessionId={}", session.getId());
                    planService.handleStripeCheckoutCompleted(session);
                } else {
                    log.warn("Checkout session {} has paymentStatus={}, not activating", session.getId(), session.getPaymentStatus());
                }
                return;
            }
            if (!isOrderStripeEvent(session.getMetadata()) && orderRepository.findByPaymentRef(session.getId()).isEmpty()) {
                log.info("Stripe webhook: ignoring checkout session {} with non-order billingType={}",
                        session.getId(), session.getMetadata() != null ? session.getMetadata().get("billingType") : null);
                return;
            }
            String orderNumber = session.getMetadata() != null ? session.getMetadata().get("orderNumber") : null;
            String paymentRef = session.getId();
            if (orderNumber == null || orderNumber.isBlank()) {
                Order order = orderRepository.findByPaymentRef(session.getId()).orElse(null);
                if (order == null) {
                    log.warn("Stripe webhook: no orderNumber in session metadata (session={})", session.getId());
                    return;
                }
                orderNumber = order.getOrderNumber();
            }
            log.info("Stripe webhook: checkout.session.completed for order {} (session={})", orderNumber, paymentRef);
            markOrderPaid(orderNumber, paymentRef);
        } catch (Exception e) {
            log.error("Failed to handle checkout.session.completed: {}", e.getMessage(), e);
        }
    }

    private void handlePaymentIntentSucceeded(Event event, String payload) {
        try {
            String objectId = getStripeObjectIdFromPayload(payload);
            Stripe.apiKey = resolveSecretKey();
            PaymentIntent paymentIntent = PaymentIntent.retrieve(objectId);
            log.info("payment_intent.succeeded: objectId={}, piId={}, status={}, metadata={}",
                    objectId, paymentIntent.getId(), paymentIntent.getStatus(), paymentIntent.getMetadata());

            if (isSubscriptionStripeEvent(paymentIntent.getMetadata())) {
                planService.handleStripePaymentSucceeded(
                        paymentIntent.getMetadata(),
                        null,
                        paymentIntent.getId(),
                        paymentIntent.getCustomer(),
                        paymentIntent.getInvoice(),
                        "payment_intent.succeeded"
                );
                return;
            }
            if (!isOrderStripeEvent(paymentIntent.getMetadata())) {
                log.info("Stripe webhook: ignoring payment intent {} with non-order billingType={}",
                        paymentIntent.getId(), paymentIntent.getMetadata() != null ? paymentIntent.getMetadata().get("billingType") : null);
                return;
            }
            String orderNumber = paymentIntent.getMetadata().get("orderNumber");
            String paymentRef = paymentIntent.getId();
            if (orderNumber == null || orderNumber.isBlank()) {
                log.warn("Stripe webhook: no orderNumber in payment_intent metadata (pi={})", paymentIntent.getId());
                return;
            }
            log.info("Stripe webhook: payment_intent.succeeded for order {} (pi={})", orderNumber, paymentRef);
            markOrderPaidByPaymentIntent(orderNumber, paymentRef);
        } catch (Exception e) {
            log.error("Failed to handle payment_intent.succeeded: {}", e.getMessage(), e);
        }
    }

    private void handlePaymentIntentFailed(Event event, String payload) {
        try {
            String objectId = getStripeObjectIdFromPayload(payload);
            Stripe.apiKey = resolveSecretKey();
            PaymentIntent paymentIntent = PaymentIntent.retrieve(objectId);
            log.info("payment_intent.payment_failed: objectId={}, piId={}, status={}, metadata={}",
                    objectId, paymentIntent.getId(), paymentIntent.getStatus(), paymentIntent.getMetadata());

            if (isSubscriptionStripeEvent(paymentIntent.getMetadata())) {
                planService.handleStripePaymentFailed(
                        paymentIntent.getMetadata(),
                        null,
                        paymentIntent.getId(),
                        paymentIntent.getInvoice(),
                        paymentIntent.getLastPaymentError() != null
                                ? paymentIntent.getLastPaymentError().getMessage()
                                : "Paiement Stripe refusé",
                        "payment_intent.payment_failed"
                );
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
        } catch (Exception e) {
            log.error("Failed to handle payment_intent.payment_failed: {}", e.getMessage(), e);
        }
    }

    private void handleInvoicePaymentSucceeded(Event event, String payload) {
        try {
            String objectId = getStripeObjectIdFromPayload(payload);
            Stripe.apiKey = resolveSecretKey();
            Invoice stripeInvoice = Invoice.retrieve(objectId);
            log.info("invoice.payment_succeeded: objectId={}, invoiceId={}, status={}, metadata={}",
                    objectId, stripeInvoice.getId(), stripeInvoice.getStatus(), stripeInvoice.getMetadata());

            if (!isSubscriptionStripeEvent(stripeInvoice.getMetadata())) {
                return;
            }
            planService.handleStripePaymentSucceeded(
                    stripeInvoice.getMetadata(),
                    null,
                    stripeInvoice.getPaymentIntent(),
                    stripeInvoice.getCustomer(),
                    stripeInvoice.getId(),
                    "invoice.payment_succeeded"
            );
        } catch (Exception e) {
            log.error("Failed to handle invoice.payment_succeeded: {}", e.getMessage(), e);
        }
    }

    private void handleInvoicePaymentFailed(Event event, String payload) {
        try {
            String objectId = getStripeObjectIdFromPayload(payload);
            Stripe.apiKey = resolveSecretKey();
            Invoice stripeInvoice = Invoice.retrieve(objectId);
            log.info("invoice.payment_failed: objectId={}, invoiceId={}, status={}, metadata={}",
                    objectId, stripeInvoice.getId(), stripeInvoice.getStatus(), stripeInvoice.getMetadata());

            if (!isSubscriptionStripeEvent(stripeInvoice.getMetadata())) {
                return;
            }
            planService.handleStripePaymentFailed(
                    stripeInvoice.getMetadata(),
                    null,
                    stripeInvoice.getPaymentIntent(),
                    stripeInvoice.getId(),
                    stripeInvoice.getLastFinalizationError() != null
                            ? stripeInvoice.getLastFinalizationError().getMessage()
                            : "Facture Stripe refusée",
                    "invoice.payment_failed"
            );
        } catch (Exception e) {
            log.error("Failed to handle invoice.payment_failed: {}", e.getMessage(), e);
        }
    }

    private boolean isSubscriptionStripeEvent(Map<String, String> metadata) {
        return metadata != null && "SUBSCRIPTION".equalsIgnoreCase(metadata.get("billingType"));
    }

    private boolean isOrderStripeEvent(Map<String, String> metadata) {
        return metadata != null && "ORDER".equalsIgnoreCase(metadata.get("billingType"));
    }

    private boolean isSubscriptionCheckoutSession(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return false;
        }
        return invoiceRepository.findByPaymentRef(sessionId)
                .map(invoice -> invoice.getOrder() == null)
                .orElse(false);
    }

    private void markOrderPaid(String orderNumber, String paymentRef) {
        orderRepository.findByOrderNumber(orderNumber).ifPresentOrElse(order -> {
            if ("PAID".equals(order.getPaymentStatus()) && "CONFIRMED".equals(order.getStatus())) {
                log.info("Stripe webhook: order {} already PAID, skipping duplicate webhook (ref={})",
                        orderNumber, order.getPaymentRef());
                return;
            }
            order.setPaymentStatus("PAID");
            order.setPaymentRef(paymentRef);
            order.setPaymentMethod("STRIPE");
            order.setStatus("CONFIRMED");
            orderRepository.save(order);
            invoiceRepository.findByOrderId(order.getId()).ifPresent(invoice -> {
                invoice.setStatus("PAID");
                invoice.setPaymentMethod("STRIPE");
                invoice.setPaymentRef(paymentRef);
                invoiceRepository.save(invoice);
            });
            log.info("Stripe webhook: order {} marked PAID (ref={})", orderNumber, paymentRef);
            telegramNotificationService.notifyPaymentValidated(order, "STRIPE", paymentRef);
        }, () -> log.warn("Stripe webhook: order {} not found in database", orderNumber));
    }

    private void markOrderPaidByPaymentIntent(String orderNumber, String paymentIntentId) {
        orderRepository.findByOrderNumber(orderNumber).ifPresent(order -> {
            String paymentRef = order.getPaymentRef() != null && !order.getPaymentRef().isBlank()
                    ? order.getPaymentRef()
                    : paymentIntentId;
            markOrderPaid(orderNumber, paymentRef);
            invoiceRepository.findByOrderId(order.getId()).ifPresent(invoice -> {
                Map<String, Object> invoiceData = invoice.getInvoiceData() != null
                        ? new java.util.HashMap<>(invoice.getInvoiceData())
                        : new java.util.HashMap<>();
                invoiceData.put("stripePaymentIntentId", paymentIntentId);
                invoice.setInvoiceData(invoiceData);
                invoiceRepository.save(invoice);
            });
        });
    }

    private String getStripeObjectIdFromPayload(String payload) {
        try {
            JsonObject root = JsonParser.parseString(payload).getAsJsonObject();
            JsonObject data = root.getAsJsonObject("data");
            JsonObject object = data.getAsJsonObject("object");
            if (object == null || object.get("id") == null || object.get("id").isJsonNull()) {
                throw new IllegalArgumentException("Stripe object id missing from payload");
            }
            return object.get("id").getAsString();
        } catch (Exception e) {
            throw new IllegalArgumentException("Cannot extract Stripe object id from payload", e);
        }
    }

    private String resolveSecretKey() {
        if (stripeSecretKey != null && !stripeSecretKey.isBlank()) {
            return stripeSecretKey;
        }
        String fromEnv = System.getenv("STRIPE_SECRET_KEY");
        if (fromEnv != null && !fromEnv.isBlank()) {
            return fromEnv;
        }
        throw new RuntimeException("STRIPE_SECRET_KEY not configured");
    }

    /**
     * Alternate Stripe webhook endpoint at the path used by `stripe listen --forward-to`.
     * Delegates to the same handler as /api/payments/stripe/webhook.
     */
    @PostMapping("/webhooks/stripe")
    public ResponseEntity<String> handleStripeWebhookFromStripeCli(HttpServletRequest request) {
        return handleStripeWebhook(request);
    }

    @PostMapping("/payments/d17/webhook")
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

    @PostMapping("/payments/konnect/webhook")
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

    @PostMapping("/payments/konnect/init")
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
