package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrackVisitRequest {
    @NotBlank
    private String boutiqueSlug;
    private UUID boutiqueId;
    private UUID userId;
    private String userEmail;
    private String userName;
    private String page;
    private String referrer;
    private String userAgent;
    private String ipAddress;
    private String deviceType;
    private String browser;
    private String operatingSystem;
    private String platform;
    private String sessionId;
    private String language;
    private String timezone;
    private String appVersion;
    private String deviceModel;
}
