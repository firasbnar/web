package io.makewebsite.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.GenericGenerator;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "notification_configs")
public class NotificationConfig {
    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "boutique_id")
    private Boutique boutique;

    @Builder.Default
    @Column(name = "email_enabled")
    private Boolean emailEnabled = true;

    @Builder.Default
    @Column(name = "sms_enabled")
    private Boolean smsEnabled = false;

    @Builder.Default
    @Column(name = "push_enabled")
    private Boolean pushEnabled = true;

    @Builder.Default
    @Column(name = "order_confirmation")
    private Boolean orderConfirmation = true;

    @Builder.Default
    @Column(name = "order_shipped")
    private Boolean orderShipped = true;

    @Builder.Default
    @Column(name = "order_delivered")
    private Boolean orderDelivered = true;

    @Builder.Default
    @Column(name = "new_customer_welcome")
    private Boolean newCustomerWelcome = true;

    @Builder.Default
    @Column(name = "low_stock_alert")
    private Boolean lowStockAlert = true;

    @Builder.Default
    @Column(name = "marketing_emails")
    private Boolean marketingEmails = false;

    @Column(name = "email_from_address", length = 200)
    private String emailFromAddress;

    @Builder.Default
    @Column(name = "sms_provider", length = 50)
    private String smsProvider = "none";

    @Column(name = "sms_api_key", length = 200)
    private String smsApiKey;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
