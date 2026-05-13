package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderResponse {
    private UUID id;
    private UUID boutiqueId;
    private UUID userId;
    private UUID customerId;
    private String customerName;
    private String orderNumber;
    private String status;
    private BigDecimal subtotal;
    private BigDecimal shippingFee;
    private BigDecimal discount;
    private BigDecimal total;
    private String paymentMethod;
    private String paymentStatus;
    private String paymentRef;
    private String shippingAddress;
    private String deliveryCompany;
    private String trackingNumber;
    private String notes;
    private LocalDateTime createdAt;
    private List<OrderItemResponse> items;
}
