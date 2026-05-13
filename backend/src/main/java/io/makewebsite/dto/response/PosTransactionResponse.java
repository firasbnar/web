package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PosTransactionResponse {
    private UUID id;
    private UUID sessionId;
    private UUID orderId;
    private BigDecimal total;
    private String paymentMethod;
    private LocalDateTime createdAt;
}
