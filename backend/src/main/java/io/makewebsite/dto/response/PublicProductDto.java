package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class PublicProductDto {
    private UUID id;
    private String name;
    private String description;
    private BigDecimal price;
    private BigDecimal comparePrice;
    private String colors;
    private String sizes;
    private String images;
    private Integer stock;
    private UUID categoryId;
    private String categoryName;
    private String firstImage;
}
