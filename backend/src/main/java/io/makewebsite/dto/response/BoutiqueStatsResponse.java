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
public class BoutiqueStatsResponse {
    private long totalOrders;
    private long todayOrders;
    private BigDecimal totalRevenue;
    private BigDecimal todayRevenue;
    private long totalProducts;
    private long pendingOrders;
}
