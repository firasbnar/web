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
    private Boolean enablePaypal;
    private Boolean enableCod;
    private Boolean enableD17;
    private Boolean enableAdeex;
    private Boolean enableJax;
    private Boolean enableIntigo;

    // Stripe config
    private String stripePublishableKey;
    private String stripeSecretKey;
    private String stripeWebhookSecret;

    // PayPal config
    private String paypalClientId;
    private String paypalSecret;
    private String paypalWebhookId;

    // Konnect config
    private String konnectMerchantId;
    private String konnectApiKey;
    private String konnectStatus;

    // D17 config
    private String d17MerchantNumber;
    private String d17QrCodeUrl;
    private String d17Status;
}
