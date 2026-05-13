package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrafficStatsResponse {
    private long totalVisits;
    private long uniqueVisitors;
    private long todayVisits;
    private long todayUniqueVisitors;
    private long weekVisits;
    private long weekUniqueVisitors;
    private long monthVisits;
    private long monthUniqueVisitors;
    private long activeVisitors;
    private long authenticatedVisitors;
    private long anonymousVisitors;
}