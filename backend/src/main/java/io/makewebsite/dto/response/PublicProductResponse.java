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
public class PublicProductResponse {
    private UUID id;
    private String name;
    private String description;
    private BigDecimal price;
    private BigDecimal promotionalPrice;
    private String images;
    private String colors;
    private String sizes;
    private Integer stock;
    private String stockStatus;
    private UUID categoryId;
    private String categoryName;
    private String descriptionHtml;
    private LocalDateTime createdAt;
}
