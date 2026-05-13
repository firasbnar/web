package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreatePosTransactionRequest {
    @NotNull
    private UUID sessionId;

    @NotEmpty
    private List<OrderItemRequest> items;

    @NotBlank
    private String paymentMethod;

    @NotNull
    private BigDecimal total;
}
