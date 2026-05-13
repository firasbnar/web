package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrafficOverviewResponse {
    private TrafficStatsResponse stats;
    private List<GeoResponse> topCountries;
    private List<GeoResponse> topCities;
    private List<DeviceBreakdownResponse> deviceBreakdown;
    private List<BrowserBreakdownResponse> browserBreakdown;
    private List<ReferralSourceResponse> referralSources;
}