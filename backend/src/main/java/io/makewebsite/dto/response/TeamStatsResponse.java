package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TeamStatsResponse {
    private long totalMembers;
    private long activeMembers;
    private long pendingInvitations;
    private Map<String, Long> roleDistribution;
}
