package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActivityLogResponse {
    private UUID id;
    private UUID boutiqueId;
    private UUID userId;
    private String userName;
    private String action;
    private String status;
    private String ipAddress;
    private String deviceInfo;
    private UUID sessionId;
    private String details;
    private String metadata;
    private LocalDateTime createdAt;
}
