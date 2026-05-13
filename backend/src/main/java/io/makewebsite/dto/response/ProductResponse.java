package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProductResponse {
    private UUID id;
    private UUID boutiqueId;
    private UUID categoryId;
    private String categoryName;
    private String name;
    private String description;
    private BigDecimal price;
    private BigDecimal comparePrice;
    private Integer stock;
    private String sku;
    private BigDecimal purchasePrice;
    private String colors;
    private String sizes;
    private String descriptionHtml;
    private String images;
    private Boolean isActive;
    private Boolean isFeatured;
    private String seoTitle;
    private String seoDescription;
    private LocalDateTime createdAt;
}
