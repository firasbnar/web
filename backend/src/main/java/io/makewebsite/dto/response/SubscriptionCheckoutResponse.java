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
public class SubscriptionCheckoutResponse {
    private UUID invoiceId;
    private String sessionId;
    private String sessionUrl;
    private String status;
}
