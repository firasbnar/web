package io.makewebsite.dto.request;

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
public class CreateOrderRequest {
    @NotNull
    private UUID boutiqueId;

    private UUID customerId;

    @NotEmpty
    private List<OrderItemRequest> items;

    private String shippingAddress;

    private String paymentMethod;

    private BigDecimal shippingFee;

    private BigDecimal discount;

    private String notes;

    private String couponCode;
}
