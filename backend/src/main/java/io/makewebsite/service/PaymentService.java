package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Event;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import com.stripe.param.checkout.SessionCreateParams;
import io.makewebsite.dto.request.CreatePaymentRequest;
import io.makewebsite.entity.Order;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.OrderRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {
    private final ObjectMapper objectMapper;
    private final OrderRepository orderRepository;
    private final BoutiqueRepository boutiqueRepository;

    private static final Set<String> STRIPE_SUPPORTED_CURRENCIES = Set.of(
            "usd", "eur", "gbp", "cad", "aed", "jpy", "aud", "chf", "dkk", "hkd",
            "inr", "myr", "nok", "nzd", "sar", "sek", "sgd", "try", "zar"
    );

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    @Value("${stripe.webhook-secret}")
    private String stripeWebhookSecret;

    @Value("${paypal.client-id}")
    private String paypalClientId;

    @Value("${paypal.secret}")
    private String paypalSecret;

    @Value("${app.public-url}")
    private String publicUrl;

    @PostConstruct
    public void init() {
        stripeSecretKey = resolveSecretKey(stripeSecretKey, "STRIPE_SECRET_KEY");
        stripeWebhookSecret = resolveSecretKey(stripeWebhookSecret, "STRIPE_WEBHOOK_SECRET");

        if (stripeSecretKey == null || stripeSecretKey.isBlank()) {
            log.error("");
            log.error("==================================================");
            log.error("  STRIPE_SECRET_KEY is NOT configured!");
            log.error("--------------------------------------------------");
            log.error("  Set the env var BEFORE starting the backend:");
            log.error("");
            log.error("  PowerShell:");
            log.error("    $env:STRIPE_SECRET_KEY='sk_test_...'");
            log.error("    mvn spring-boot:run");
            log.error("");
            log.error("  Or permanently (once, then restart terminal):");
            log.error("    setx STRIPE_SECRET_KEY sk_test_...");
            log.error("==================================================");
            log.error("");
            throw new IllegalStateException(
                    "Stripe secret key not configured. " +
                    "Set STRIPE_SECRET_KEY environment variable and restart.");
        }

        Stripe.apiKey = stripeSecretKey;
        log.info("Stripe SDK initialized — key ends with ...{} (length={})",
                stripeSecretKey.substring(Math.max(0, stripeSecretKey.length() - 4)),
                stripeSecretKey.length());

        if (stripeWebhookSecret == null || stripeWebhookSecret.isBlank()) {
            log.warn("STRIPE_WEBHOOK_SECRET not set — webhook signature verification will fail.");
            log.warn("  Set it via:   $env:STRIPE_WEBHOOK_SECRET='whsec_...'");
        } else {
            log.info("Stripe webhook secret configured (length={})", stripeWebhookSecret.length());
        }
    }

    /**
     * Tries @Value-resolved key first, falls back to System.getenv() directly.
     * This ensures the key works even when env vars are set in the shell
     * but not picked up by Spring's property resolution.
     */
    private String resolveSecretKey(String fromValue, String envName) {
        if (fromValue != null && !fromValue.isBlank()) {
            log.debug("{} resolved via application.properties (env var was set at shell level)", envName);
            return fromValue;
        }
        String fromEnv = System.getenv(envName);
        if (fromEnv != null && !fromEnv.isBlank()) {
            log.debug("{} resolved via direct System.getenv() fallback", envName);
            return fromEnv;
        }
        log.debug("{} not found in either @Value or System.getenv()", envName);
        return "";
    }

    public void validateUserOwnsOrder(String orderNumber, UUID userId) {
        Order order = orderRepository.findByOrderNumber(orderNumber)
                .orElseThrow(() -> new RuntimeException("Commande non trouvée: " + orderNumber));
        UUID boutiqueId = order.getBoutique().getId();
        if (boutiqueRepository.findByUserIdAndId(userId, boutiqueId).isEmpty()) {
            log.warn("User {} attempted to pay for order {} belonging to boutique {} which they do not own", userId, orderNumber, boutiqueId);
            throw new RuntimeException("Vous n'êtes pas autorisé à payer cette commande");
        }
    }

    public JsonNode createPayPalOrder(CreatePaymentRequest request) {
        try {
            RestTemplate restTemplate = new RestTemplate();

            HttpHeaders authHeaders = new HttpHeaders();
            authHeaders.setBasicAuth(paypalClientId, paypalSecret);
            authHeaders.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
            HttpEntity<String> authEntity = new HttpEntity<>("grant_type=client_credentials", authHeaders);
            ResponseEntity<String> authResponse = restTemplate.postForEntity(
                    "https://api-m.sandbox.paypal.com/v1/oauth2/token", authEntity, String.class);
            JsonNode authJson = objectMapper.readTree(authResponse.getBody());
            String accessToken = authJson.get("access_token").asText();

            HttpHeaders orderHeaders = new HttpHeaders();
            orderHeaders.setBearerAuth(accessToken);
            orderHeaders.setContentType(MediaType.APPLICATION_JSON);

            String orderJson = "{\"intent\":\"CAPTURE\",\"purchase_units\":[{\"amount\":{\"currency_code\":\"" +
                    (request.getCurrency() != null ? request.getCurrency() : "USD") +
                    "\",\"value\":\"" + request.getAmount() + "\"}}]}";

            HttpEntity<String> orderEntity = new HttpEntity<>(orderJson, orderHeaders);
            ResponseEntity<String> orderResponse = restTemplate.postForEntity(
                    "https://api-m.sandbox.paypal.com/v2/checkout/orders", orderEntity, String.class);
            return objectMapper.readTree(orderResponse.getBody());
        } catch (Exception e) {
            log.error("PayPal error: {}", e.getMessage());
            throw new RuntimeException("PayPal error: " + e.getMessage());
        }
    }

    public JsonNode capturePayPalOrder(String orderId) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setBasicAuth(paypalClientId, paypalSecret);
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<String> entity = new HttpEntity<>("", headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api-m.sandbox.paypal.com/v2/checkout/orders/" + orderId + "/capture", entity, String.class);
            return objectMapper.readTree(response.getBody());
        } catch (Exception e) {
            log.error("PayPal capture error: {}", e.getMessage());
            throw new RuntimeException("PayPal capture error: " + e.getMessage());
        }
    }

    public String handleD17Webhook(String payload) {
        return "OK";
    }

    public JsonNode createStripeCheckoutSession(CreatePaymentRequest request) {
        String key = stripeSecretKey;
        if (key == null || key.isBlank()) {
            key = resolveSecretKey("", "STRIPE_SECRET_KEY");
        }
        if (key == null || key.isBlank()) {
            log.error("Stripe secret key not configured — cannot create checkout session");
            throw new RuntimeException(
                    "Stripe secret key not configured. " +
                    "Set STRIPE_SECRET_KEY environment variable and restart the backend.");
        }

        String orderNumber = request.getOrderNumber();
        if (orderNumber == null || orderNumber.isBlank()) {
            throw new RuntimeException("Numéro de commande requis");
        }

        Order order = orderRepository.findByOrderNumber(orderNumber)
                .orElseThrow(() -> new RuntimeException("Commande non trouvée: " + orderNumber));

        BigDecimal orderTotal = order.getTotal();
        if (orderTotal == null || orderTotal.compareTo(BigDecimal.ZERO) <= 0) {
            log.error("Order {} has invalid total: {}", orderNumber, orderTotal);
            throw new RuntimeException("Montant de la commande invalide: " + orderTotal);
        }

        String currency = request.getCurrency() != null ? request.getCurrency().toLowerCase() : "tnd";
        String stripeCurrency = STRIPE_SUPPORTED_CURRENCIES.contains(currency) ? currency : "eur";
        if (!currency.equals(stripeCurrency)) {
            log.warn("Currency '{}' is not supported by Stripe. Falling back to '{}' for order {} (original total: {} {})",
                    currency, stripeCurrency, orderNumber, orderTotal, currency);
        }

        long amountCents = orderTotal.multiply(BigDecimal.valueOf(100)).longValue();
        if (amountCents <= 0) {
            throw new RuntimeException("Montant invalide après conversion: " + orderTotal + " → " + amountCents + " cents");
        }

        log.info("=== CREATING STRIPE CHECKOUT SESSION ===");
        log.info("Order:      {}", orderNumber);
        log.info("DB total:   {} {} (from database, IGNORING frontend amount)", orderTotal, currency);
        log.info("Stripe currency: {}", stripeCurrency);
        log.info("Amount cents: {}", amountCents);
        log.info("Success URL: {}/checkout/success?order={}&boutiqueId={}",
                publicUrl, orderNumber, request.getBoutiqueId());
        log.info("================================");

        try {
            Stripe.apiKey = stripeSecretKey;

            SessionCreateParams.LineItem.PriceData.ProductData productData =
                    SessionCreateParams.LineItem.PriceData.ProductData.builder()
                            .setName("Commande " + orderNumber)
                            .build();

            SessionCreateParams.LineItem.PriceData priceData =
                    SessionCreateParams.LineItem.PriceData.builder()
                            .setCurrency(stripeCurrency)
                            .setUnitAmount(amountCents)
                            .setProductData(productData)
                            .build();

            SessionCreateParams.LineItem lineItem =
                    SessionCreateParams.LineItem.builder()
                            .setPriceData(priceData)
                            .setQuantity(1L)
                            .build();

            String successUrl = publicUrl + "/checkout/success?order=" + orderNumber +
                    "&boutiqueId=" + (request.getBoutiqueId() != null ? request.getBoutiqueId().toString() : "");
            String cancelUrl = publicUrl + "/checkout/cancel";

            SessionCreateParams.Builder paramsBuilder = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(successUrl)
                    .setCancelUrl(cancelUrl)
                    .addLineItem(lineItem);

            paramsBuilder.putMetadata("orderNumber", orderNumber);
            if (request.getBoutiqueId() != null) {
                paramsBuilder.putMetadata("boutiqueId", request.getBoutiqueId().toString());
            }

            Session session = Session.create(paramsBuilder.build());

            log.info("Stripe Checkout Session created: id={}, url={}", session.getId(), session.getUrl());

            return objectMapper.valueToTree(Map.of(
                    "sessionId", session.getId(),
                    "sessionUrl", session.getUrl()
            ));
        } catch (StripeException e) {
            log.error("Stripe Checkout Session error for order {}: {} (code={}, type={})",
                    orderNumber, e.getMessage(), e.getCode(), e.getStatusCode());
            throw new RuntimeException("Erreur Stripe: " + e.getMessage());
        }
    }

    public Event parseStripeWebhook(String payload, String sigHeader) {
        if (stripeWebhookSecret == null || stripeWebhookSecret.isEmpty()) {
            throw new RuntimeException("Stripe webhook secret not configured. Set STRIPE_WEBHOOK_SECRET environment variable.");
        }
        try {
            return Webhook.constructEvent(payload, sigHeader, stripeWebhookSecret);
        } catch (StripeException e) {
            log.warn("Stripe webhook signature verification failed: {}", e.getMessage());
            throw new RuntimeException("Stripe webhook verification failed", e);
        }
    }

    public JsonNode createStripePaymentIntent(CreatePaymentRequest request) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setBearerAuth(stripeSecretKey);
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

            String body = "amount=" + request.getAmount().multiply(java.math.BigDecimal.valueOf(100)).longValue() +
                    "&currency=" + (request.getCurrency() != null ? request.getCurrency().toLowerCase() : "usd") +
                    "&payment_method_types[]=card";
            HttpEntity<String> entity = new HttpEntity<>(body, headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.stripe.com/v1/payment_intents", entity, String.class);
            return objectMapper.readTree(response.getBody());
        } catch (Exception e) {
            log.error("Stripe error: {}", e.getMessage());
            throw new RuntimeException("Stripe error: " + e.getMessage());
        }
    }

    public JsonNode confirmStripePayment(String paymentIntentId) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setBearerAuth(stripeSecretKey);
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

            HttpEntity<String> entity = new HttpEntity<>("", headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.stripe.com/v1/payment_intents/" + paymentIntentId + "/confirm", entity, String.class);
            return objectMapper.readTree(response.getBody());
        } catch (Exception e) {
            log.error("Stripe confirm error: {}", e.getMessage());
            throw new RuntimeException("Stripe confirm error: " + e.getMessage());
        }
    }
}
