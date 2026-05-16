package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActivityLogRequest {
    private String action;
    private String status;
    private String details;
    private String ipAddress;
    private String deviceInfo;
    private String metadata;
}
