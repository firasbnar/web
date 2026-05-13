package io.makewebsite.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.GenericGenerator;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "visitors")
public class Visitor {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @Column(name = "boutique_id")
    private UUID boutiqueId;

    private UUID userId;
    private String userEmail;
    private String userName;

    @Column(name = "ip_hash", length = 64, nullable = false)
    private String ipHash;

    private String country;
    private String city;
    private String region;
    private Double latitude;
    private Double longitude;

    @Column(name = "device_type", length = 50)
    private String deviceType;

    @Column(length = 100)
    private String browser;

    @Column(name = "os", length = 100)
    private String operatingSystem;

    @Column(length = 100)
    private String platform;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "referral_source", length = 500)
    private String referralSource;

    @Builder.Default
    @Column(name = "total_visits")
    private Long totalVisits = 1L;

    @Column(name = "first_visit_at")
    private LocalDateTime firstVisitAt;

    @Column(name = "last_activity_at")
    private LocalDateTime lastActivityAt;

    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        lastActivityAt = LocalDateTime.now();
        firstVisitAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
        lastActivityAt = LocalDateTime.now();
    }
}