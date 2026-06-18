package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdatePaymentRequest {
    private Boolean enableCod;

    // Stripe config
    private Boolean stripeEnabled;
    private String stripeStatus;
    private String stripePublishableKey;
    private String stripeSecretKey;
    private String stripeWebhookSecret;
}
