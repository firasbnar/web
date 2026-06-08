package io.makewebsite.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @NotNull
    @Size(max = 100)
    @Column(name = "full_name", nullable = false)
    private String fullName;

    @NotNull
    @Size(max = 150)
    @Column(unique = true, nullable = false)
    private String email;

    @NotNull
    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Size(max = 20)
    private String phone;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tenant_id", nullable = false)
    private Tenant tenant;

    @Builder.Default
    @Column(length = 20)
    private String role = "USER";

    @Builder.Default
    @Column(length = 10)
    private String language = "fr";

    @Column(name = "active_boutique_id")
    private UUID activeBoutiqueId;

    @Size(max = 50)
    @Column(name = "telegram_chat_id")
    private String telegramChatId;

    @Builder.Default
    @Column(name = "telegram_enabled", nullable = false)
    private Boolean telegramEnabled = false;

    @Builder.Default
    @Column(name = "telegram_connected", nullable = false)
    private Boolean telegramConnected = false;

    @Column(name = "telegram_connection_code", length = 20)
    private String telegramConnectionCode;

    @Column(name = "telegram_connection_code_expires_at")
    private LocalDateTime telegramConnectionCodeExpiresAt;

    @Column(name = "avatar_url", columnDefinition = "TEXT")
    private String avatarUrl;

    @Builder.Default
    @Column(name = "is_suspended")
    private Boolean isSuspended = false;

    @Column(name = "suspended_reason", columnDefinition = "TEXT")
    private String suspendedReason;

    @Builder.Default
    @Column(name = "email_verified", nullable = false)
    private Boolean emailVerified = false;

    @Builder.Default
    @Column(name = "enabled", nullable = false)
    private Boolean enabled = false;

    @Builder.Default
    @Column(name = "must_change_password", nullable = false)
    private Boolean mustChangePassword = false;

    @Column(name = "verification_token", length = 255)
    private String verificationToken;

    @Column(name = "verification_token_expiry")
    private LocalDateTime verificationTokenExpiry;

    @Column(name = "last_login_at")
    private LocalDateTime lastLoginAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
