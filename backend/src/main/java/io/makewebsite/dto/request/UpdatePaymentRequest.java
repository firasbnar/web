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
    private Boolean enableD17;
    private Boolean enableAdeex;
    private Boolean enableJax;
    private Boolean enableIntigo;

    // Stripe config
    private String stripePublishableKey;
    private String stripeSecretKey;
    private String stripeWebhookSecret;

    // Konnect config
    private String konnectMerchantId;
    private String konnectApiKey;
    private String konnectStatus;

    // D17 config
    private String d17MerchantNumber;
    private String d17QrCodeUrl;
    private String d17Status;
}
