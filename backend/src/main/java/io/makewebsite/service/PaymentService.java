package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.makewebsite.dto.request.CreatePaymentRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
@RequiredArgsConstructor
public class PaymentService {
    private final ObjectMapper objectMapper;

    public JsonNode createPayPalOrder(CreatePaymentRequest request) {
        try {
            RestTemplate restTemplate = new RestTemplate();

            HttpHeaders authHeaders = new HttpHeaders();
            authHeaders.setBasicAuth("YOUR_PAYPAL_CLIENT_ID", "YOUR_PAYPAL_SECRET");
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
            throw new RuntimeException("PayPal error: " + e.getMessage());
        }
    }

    public JsonNode capturePayPalOrder(String orderId) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setBasicAuth("YOUR_PAYPAL_CLIENT_ID", "YOUR_PAYPAL_SECRET");
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<String> entity = new HttpEntity<>("", headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api-m.sandbox.paypal.com/v2/checkout/orders/" + orderId + "/capture", entity, String.class);
            return objectMapper.readTree(response.getBody());
        } catch (Exception e) {
            throw new RuntimeException("PayPal capture error: " + e.getMessage());
        }
    }

    public String handleD17Webhook(String payload) {
        return "OK";
    }

    public JsonNode createStripePaymentIntent(CreatePaymentRequest request) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setBearerAuth("YOUR_STRIPE_SECRET_KEY");
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

            String body = "amount=" + request.getAmount().multiply(java.math.BigDecimal.valueOf(100)).longValue() +
                    "&currency=" + (request.getCurrency() != null ? request.getCurrency().toLowerCase() : "usd") +
                    "&payment_method_types[]=card";
            HttpEntity<String> entity = new HttpEntity<>(body, headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.stripe.com/v1/payment_intents", entity, String.class);
            return objectMapper.readTree(response.getBody());
        } catch (Exception e) {
            throw new RuntimeException("Stripe error: " + e.getMessage());
        }
    }

    public JsonNode confirmStripePayment(String paymentIntentId) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setBearerAuth("YOUR_STRIPE_SECRET_KEY");
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

            HttpEntity<String> entity = new HttpEntity<>("", headers);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.stripe.com/v1/payment_intents/" + paymentIntentId + "/confirm", entity, String.class);
            return objectMapper.readTree(response.getBody());
        } catch (Exception e) {
            throw new RuntimeException("Stripe confirm error: " + e.getMessage());
        }
    }
}
