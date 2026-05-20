package io.makewebsite.dto.response;

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
public class PublicStoreResponse {
    private UUID id;
    private String name;
    private String slug;
    private String logoUrl;
    private String bannerUrl;
    private String description;
    private String email;
    private String phone;
    private String address;
    private String primaryColor;
    private String secondaryColor;
    private String headerColor;
    private String footerColor;
    private String bodyColor;
    private String cardProductColor;
    private String buttonColor;
    private String topBarColor;
    private String textColor;
    private String fontFamily;
    private String currency;
    private String language;
    private String announcementText;
    private Double deliveryFees;
    private Boolean cashOnDelivery;
    private Boolean simpleCheckout;
    private Boolean konnectActive;
    private Boolean d17Active;
    private String facebookUrl;
    private String instagramUrl;
    private String tiktokUrl;
    private String whatsappNumber;
    private String publicationStatus;
    private String freezeReason;
    private String publicUrl;
    private BigDecimal minPrice;
    private long productCount;
    private List<PublicCategoryResponse> categories;
    private List<PublicProductResponse> products;
}
