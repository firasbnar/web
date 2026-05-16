package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationConfigResponse {
    private UUID id;
    private UUID boutiqueId;
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
}
