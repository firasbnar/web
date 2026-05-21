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
@Table(name = "store_views")
public class StoreView {
    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @Column(name = "boutique_id")
    private UUID boutiqueId;

    @Column(name = "ip_hash", length = 64)
    private String ipHash;

    @Column(length = 200)
    private String page;

    @Column(columnDefinition = "TEXT")
    private String referrer;

    @Column(length = 50)
    private String browser;

    @Column(length = 100)
    private String country;

    @Column(length = 100)
    private String city;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "visitor_id", length = 64)
    private String visitorId;

    @Column(name = "viewed_at")
    private LocalDateTime viewedAt;
}
