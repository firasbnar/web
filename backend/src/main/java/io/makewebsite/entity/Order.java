package io.makewebsite.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.GenericGenerator;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "boutique_id", nullable = false)
    private Boutique boutique;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @NotNull
    @Size(max = 30)
    @Column(name = "order_number", unique = true, nullable = false)
    private String orderNumber;

    @Builder.Default
    @Size(max = 30)
    private String status = "PENDING";

    @NotNull
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal subtotal;

    @Builder.Default
    @Column(name = "shipping_fee", precision = 10, scale = 2)
    private BigDecimal shippingFee = BigDecimal.ZERO;

    @Builder.Default
    @Column(precision = 10, scale = 2)
    private BigDecimal discount = BigDecimal.ZERO;

    @NotNull
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal total;

    @Size(max = 30)
    @Column(name = "payment_method")
    private String paymentMethod;

    @Builder.Default
    @Size(max = 20)
    @Column(name = "payment_status")
    private String paymentStatus = "UNPAID";

    @Size(max = 100)
    @Column(name = "payment_ref")
    private String paymentRef;

    @Column(name = "customer_name")
    @Size(max = 100)
    private String customerName;

    @Column(name = "customer_phone")
    @Size(max = 20)
    private String customerPhone;

    @Column(name = "customer_email")
    @Size(max = 150)
    private String customerEmail;

    @Size(max = 100)
    private String city;

    @Column(name = "shipping_address", columnDefinition = "TEXT")
    private String shippingAddress;

    @Size(max = 50)
    @Column(name = "delivery_company")
    private String deliveryCompany;

    @Size(max = 100)
    @Column(name = "tracking_number")
    private String trackingNumber;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Size(max = 30)
    @Column(name = "invoice_number")
    private String invoiceNumber;

    @Column(name = "invoice_created_at")
    private LocalDateTime invoiceCreatedAt;

    @Builder.Default
    @Column(name = "confirmation_email_sent")
    private Boolean confirmationEmailSent = false;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<OrderItem> items = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
