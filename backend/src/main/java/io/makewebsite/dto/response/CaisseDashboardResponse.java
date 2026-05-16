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
public class CaisseDashboardResponse {
    private BigDecimal totalVentes;
    private long commandesAujourdhui;
    private long caissesActives;
    private long utilisateursConnectes;
    private BigDecimal ventesAujourdhui;
    private long totalCommandes;
}
