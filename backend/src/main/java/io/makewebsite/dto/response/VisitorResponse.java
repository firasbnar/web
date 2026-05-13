package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VisitorResponse {
    private String id;
    private String ipHash;
    private String country;
    private String city;
    private String region;
    private Double latitude;
    private Double longitude;
    private String deviceType;
    private String browser;
    private String operatingSystem;
    private String platform;
    private String referralSource;
    private Long totalVisits;
    private String firstVisitAt;
    private String lastActivityAt;
    private Boolean isActive;
    private Boolean isAuthenticated;
    private String userEmail;
    private String userName;
    private String createdAt;
}