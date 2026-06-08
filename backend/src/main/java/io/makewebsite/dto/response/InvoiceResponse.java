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
public class InvoiceResponse {
    private UUID id;
    private UUID userId;
    private UUID subscriptionId;
    private UUID boutiqueId;
    private String boutiqueName;
    private String boutiqueEmail;
    private String boutiquePhone;
    private String boutiqueAddress;
    private UUID orderId;
    private String orderNumber;
    private String invoiceNumber;
    private LocalDateTime invoiceCreatedAt;
    private String customerName;
    private String customerEmail;
    private String customerPhone;
    private String shippingAddress;
    private BigDecimal subtotal;
    private BigDecimal shippingFee;
    private BigDecimal discount;
    private BigDecimal total;
    private BigDecimal amount;
    private String currency;
    private String status;
    private String planName;
    private String paymentMethod;
    private String paymentRef;
    private String paymentStatus;
    private LocalDateTime paidAt;
    private LocalDateTime createdAt;
    private List<OrderItemResponse> items;
}
