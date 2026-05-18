package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TeamMemberResponse {
    private UUID id;
    private UUID boutiqueId;
    private UUID userId;
    private String name;
    private String invitedEmail;
    private String userEmail;
    private String role;
    private String status;
    private LocalDateTime invitedAt;
    private LocalDateTime joinedAt;
    private LocalDateTime lastActivityAt;
    private List<String> permissions;
}
