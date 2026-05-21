package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BoutiqueResponse {
    private UUID id;
    private String name;
    private String slug;
    private String logoUrl;
    private String description;
    private String email;
    private String phone;
    private String address;
    private String primaryColor;
    private String secondaryColor;
    private String currency;
    private String language;
    private String category;
    private String country;
    private String city;
    private String timezone;
    private String storeConfig;
    private String headerColor;
    private String footerColor;
    private String bodyColor;
    private String cardProductColor;
    private String buttonColor;
    private String topBarColor;
    private String textColor;
    private Boolean isActive;
    private String customDomain;
    private String seoTitle;
    private String seoDescription;
    private String seoKeywords;
    private String ogImageUrl;
    private String facebookUrl;
    private String instagramUrl;
    private String tiktokUrl;
    private String twitterUrl;
    private String linkedinUrl;
    private String whatsappNumber;
    private String customCss;
    private String customJs;
    private Boolean enableCod;
    private Boolean enableD17;
    private Boolean enableAdeex;
    private Boolean enableJax;
    private Boolean enableIntigo;
    private String bannerUrl;
    private String faviconUrl;
    private String fontFamily;
    private Boolean darkMode;
    private String announcementText;
    private Double deliveryFees;
    private Double tva;
    private Boolean simpleCheckout;
    private Boolean cashOnDelivery;
    private String konnectMerchantId;
    private String konnectApiKey;
    private String konnectStatus;
    private String d17MerchantNumber;
    private String d17QrCodeUrl;
    private String d17Status;
    private String facebookPixelId;
    private String googleAnalyticsId;
    private String stripePublishableKey;
    private Double freeShippingThreshold;
    private Integer estimatedDeliveryDays;
    private Boolean enableLocalPickup;
    private Boolean enableEmailNotifications;
    private Boolean enableSmsNotifications;
    private Boolean enablePushNotifications;
    private Boolean enableMarketingEmails;
    private Boolean enableOrderAlerts;
    private Boolean teamEnabled;
    private Boolean clientMessagingEnabled;
    private String telegramChatId;
    private Boolean telegramEnabled;
    private String storeStatus;
    private String publicationStatus;
    private String frozenAt;
    private String freezeReason;
    private Boolean isPublished;
    private String publishedAt;
    private String publicUrl;
    private LocalDateTime createdAt;
}
