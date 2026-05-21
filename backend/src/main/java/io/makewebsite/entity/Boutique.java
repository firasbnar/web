package io.makewebsite.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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
@Table(name = "boutiques")
public class Boutique {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tenant_id", nullable = false)
    private Tenant tenant;

    @NotNull
    @Size(max = 100)
    @Column(nullable = false)
    private String name;

    @NotNull
    @Size(max = 100)
    @Column(unique = true, nullable = false)
    private String slug;

    @Column(name = "logo_url", columnDefinition = "TEXT")
    private String logoUrl;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "custom_domain", columnDefinition = "TEXT")
    private String customDomain;

    @Builder.Default
    @Size(max = 7)
    @Column(name = "primary_color")
    private String primaryColor = "#2710BF";

    @Builder.Default
    @Size(max = 7)
    @Column(name = "secondary_color")
    private String secondaryColor = "#6C4FFF";

    @Builder.Default
    @Size(max = 10)
    private String currency = "TND";

    @Builder.Default
    @Size(max = 10)
    private String language = "fr";

    @Size(max = 100)
    private String category;

    @Size(max = 100)
    private String country;

    @Size(max = 100)
    private String city;

    @Builder.Default
    @Column(name = "is_active")
    private Boolean isActive = true;

    @Size(max = 200)
    @Column(name = "seo_title")
    private String seoTitle;

    @Column(name = "seo_description", columnDefinition = "TEXT")
    private String seoDescription;

    @Column(name = "seo_keywords", columnDefinition = "TEXT")
    private String seoKeywords;

    @Column(name = "facebook_url", columnDefinition = "TEXT")
    private String facebookUrl;

    @Column(name = "instagram_url", columnDefinition = "TEXT")
    private String instagramUrl;

    @Column(name = "tiktok_url", columnDefinition = "TEXT")
    private String tiktokUrl;

    @Column(name = "twitter_url", columnDefinition = "TEXT")
    private String twitterUrl;

    @Column(name = "linkedin_url", columnDefinition = "TEXT")
    private String linkedinUrl;

    @Size(max = 20)
    @Column(name = "whatsapp_number")
    private String whatsappNumber;

    @Column(name = "custom_css", columnDefinition = "TEXT")
    private String customCss;

    @Column(name = "custom_js", columnDefinition = "TEXT")
    private String customJs;

    @Builder.Default
    @Column(name = "enable_cod")
    private Boolean enableCod = true;

    @Builder.Default
    @Column(name = "enable_d17")
    private Boolean enableD17 = false;

    @Builder.Default
    @Column(name = "enable_adeex")
    private Boolean enableAdeex = false;

    @Builder.Default
    @Column(name = "enable_jax")
    private Boolean enableJax = false;

    @Builder.Default
    @Column(name = "enable_intigo")
    private Boolean enableIntigo = false;

    // ====== Storefront config fields ======

    @Builder.Default
    @Column(name = "store_config", columnDefinition = "TEXT")
    private String storeConfig = "{}";

    @Column(name = "generated_html", columnDefinition = "TEXT")
    private String generatedHtml;

    @Builder.Default
    @Column(name = "header_color", length = 7)
    private String headerColor = "#ededed";

    @Builder.Default
    @Column(name = "footer_color", length = 7)
    private String footerColor = "#dbdbdb";

    @Builder.Default
    @Column(name = "body_color", length = 7)
    private String bodyColor = "#ffffff";

    @Builder.Default
    @Column(name = "card_product_color", length = 7)
    private String cardProductColor = "#fafafa";

    @Builder.Default
    @Column(name = "button_color", length = 7)
    private String buttonColor = "#b551c2";

    @Builder.Default
    @Column(name = "top_bar_color", length = 7)
    private String topBarColor = "#3b0086";

    @Builder.Default
    @Column(name = "text_color", length = 7)
    private String textColor = "#751515";

    @Column(name = "announcement_text", columnDefinition = "TEXT")
    private String announcementText;

    @Builder.Default
    @Column(name = "delivery_fees")
    private Double deliveryFees = 7.00;

    @Builder.Default
    @Column(name = "tva")
    private Double tva = 0.00;

    @Builder.Default
    @Column(name = "simple_checkout")
    private Boolean simpleCheckout = false;

    @Builder.Default
    @Column(name = "cash_on_delivery")
    private Boolean cashOnDelivery = true;

    @Column(name = "konnect_merchant_id", length = 100)
    private String konnectMerchantId;

    @Column(name = "konnect_api_key", length = 200)
    private String konnectApiKey;

    @Builder.Default
    @Column(name = "konnect_status", length = 20)
    private String konnectStatus = "inactive";

    @Column(name = "d17_merchant_number", length = 50)
    private String d17MerchantNumber;

    @Column(name = "d17_qr_code_url", columnDefinition = "TEXT")
    private String d17QrCodeUrl;

    @Builder.Default
    @Column(name = "d17_status", length = 20)
    private String d17Status = "inactive";

    @Builder.Default
    @Column(name = "invoice_sequence")
    private Long invoiceSequence = 0L;

    @Column(name = "facebook_pixel_id", length = 50)
    private String facebookPixelId;

    @Column(name = "google_analytics_id", length = 50)
    private String googleAnalyticsId;

    // ====== New store settings fields ======

    @Column(length = 200)
    private String email;

    @Column(length = 50)
    private String phone;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Builder.Default
    @Column(length = 50)
    private String timezone = "Africa/Tunis";

    @Column(name = "banner_url", columnDefinition = "TEXT")
    private String bannerUrl;

    @Column(name = "favicon_url", columnDefinition = "TEXT")
    private String faviconUrl;

    @Column(name = "og_image_url", columnDefinition = "TEXT")
    private String ogImageUrl;

    @Builder.Default
    @Column(name = "font_family", length = 100)
    private String fontFamily = "Inter";

    @Builder.Default
    @Column(name = "dark_mode")
    private Boolean darkMode = false;

    @Column(name = "stripe_publishable_key", length = 200)
    private String stripePublishableKey;

    @Column(name = "stripe_secret_key", length = 200)
    private String stripeSecretKey;

    @Column(name = "stripe_webhook_secret", length = 200)
    private String stripeWebhookSecret;

    @Column(name = "free_shipping_threshold")
    private Double freeShippingThreshold;

    @Builder.Default
    @Column(name = "estimated_delivery_days")
    private Integer estimatedDeliveryDays = 3;

    @Builder.Default
    @Column(name = "enable_local_pickup")
    private Boolean enableLocalPickup = false;

    @Builder.Default
    @Column(name = "enable_email_notifications")
    private Boolean enableEmailNotifications = true;

    @Builder.Default
    @Column(name = "enable_sms_notifications")
    private Boolean enableSmsNotifications = false;

    @Builder.Default
    @Column(name = "enable_push_notifications")
    private Boolean enablePushNotifications = true;

    @Builder.Default
    @Column(name = "enable_marketing_emails")
    private Boolean enableMarketingEmails = false;

    @Builder.Default
    @Column(name = "enable_order_alerts")
    private Boolean enableOrderAlerts = true;

    @Column(name = "template_id")
    private Integer templateId;

    @Builder.Default
    @Column(name = "client_messaging_enabled")
    private Boolean clientMessagingEnabled = true;

    @Builder.Default
    @Column(name = "team_enabled")
    private Boolean teamEnabled = false;

    @Builder.Default
    @Column(name = "store_status", length = 20)
    private String storeStatus = "ACTIVE";

    @Column(name = "frozen_at")
    private LocalDateTime frozenAt;

    @Column(name = "freeze_reason", columnDefinition = "TEXT")
    private String freezeReason;

    @Builder.Default
    @Column(name = "is_published")
    private Boolean isPublished = false;

    @Column(name = "published_at")
    private LocalDateTime publishedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
