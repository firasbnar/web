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
    private String primaryColor;
    private String secondaryColor;
    private String currency;
    private String language;
    private Boolean isActive;
    private String customDomain;
    private String seoTitle;
    private String seoDescription;
    private String seoKeywords;
    private String facebookUrl;
    private String instagramUrl;
    private String tiktokUrl;
    private String whatsappNumber;
    private String customCss;
    private Boolean enablePaypal;
    private Boolean enableCod;
    private Boolean enableD17;
    private Boolean enableAdeex;
    private Boolean enableJax;
    private Boolean enableIntigo;
    private LocalDateTime createdAt;
}
