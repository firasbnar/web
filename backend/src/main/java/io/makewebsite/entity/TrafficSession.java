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
@Table(name = "traffic_sessions", indexes = {
    @Index(name = "idx_session_boutique_id", columnList = "boutique_id"),
    @Index(name = "idx_session_session_id", columnList = "session_id"),
    @Index(name = "idx_session_boutique_active", columnList = "boutique_id,is_active"),
    @Index(name = "idx_session_created_at", columnList = "created_at")
})
public class TrafficSession {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @Column(name = "boutique_id", nullable = false)
    private UUID boutiqueId;

    @Column(name = "session_id", nullable = false, length = 64)
    private String sessionId;

    @Column(name = "ip_hash", length = 64)
    private String ipHash;

    @Column(name = "user_id")
    private UUID userId;

    @Column(length = 100)
    private String country;

    @Column(length = 100)
    private String city;

    private Double latitude;
    private Double longitude;

    @Column(name = "device_type", length = 50)
    private String deviceType;

    @Column(length = 100)
    private String browser;

    @Column(name = "os", length = 100)
    private String operatingSystem;

    @Column(length = 50)
    private String language;

    @Column(length = 50)
    private String timezone;

    @Column(name = "app_version", length = 20)
    private String appVersion;

    @Column(name = "device_model", length = 100)
    private String deviceModel;

    @Column(name = "referrer", length = 500)
    private String referrer;

    @Builder.Default
    @Column(name = "pages_viewed")
    private int pagesViewed = 0;

    @Column(name = "first_activity_at")
    private LocalDateTime firstActivityAt;

    @Column(name = "last_activity_at")
    private LocalDateTime lastActivityAt;

    @Column(name = "session_duration_seconds")
    private Long sessionDurationSeconds;

    @Builder.Default
    @Column(name = "is_bounce")
    private boolean isBounce = true;

    @Builder.Default
    @Column(name = "is_active")
    private boolean isActive = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        firstActivityAt = LocalDateTime.now();
        lastActivityAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
        lastActivityAt = LocalDateTime.now();
        if (firstActivityAt != null) {
            sessionDurationSeconds = java.time.Duration.between(firstActivityAt, LocalDateTime.now()).getSeconds();
        }
        isBounce = pagesViewed <= 1;
    }
}
