package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlanResponse {
    private Integer id;
    private String name;
    private BigDecimal priceDt;
    private Integer durationDays;
    private Integer maxProducts;
    private BigDecimal commissionPercent;
    private String features;
}
