package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateProductRequest {
    @NotNull
    private UUID boutiqueId;

    private UUID categoryId;

    @NotBlank
    private String name;

    private String description;

    @NotNull
    private BigDecimal price;

    private BigDecimal comparePrice;

    @Builder.Default
    private Integer stock = 0;

    private String sku;

    private BigDecimal purchasePrice;

    private String colors;

    private String sizes;

    private String descriptionHtml;

    private String images;

    @Builder.Default
    private Boolean isActive = true;

    @Builder.Default
    private Boolean isFeatured = false;

    private String seoTitle;

    private String seoDescription;
}
