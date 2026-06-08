package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SubscriptionCheckoutStatusResponse {
    private String sessionId;
    private String invoiceStatus;
    private String subscriptionStatus;
    private String paymentRef;
    private String paymentIntentId;
    private boolean dashboardUnlocked;
    private String message;
}
