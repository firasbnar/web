package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationConfigRequest {
    private Boolean emailEnabled;
    private Boolean smsEnabled;
    private Boolean pushEnabled;
    private Boolean orderConfirmation;
    private Boolean orderShipped;
    private Boolean orderDelivered;
    private Boolean newCustomerWelcome;
    private Boolean lowStockAlert;
    private Boolean marketingEmails;
    private String emailFromAddress;
    private String smsProvider;
    private String smsApiKey;
}
