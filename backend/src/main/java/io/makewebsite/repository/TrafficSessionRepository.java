package io.makewebsite.repository;

import io.makewebsite.entity.TrafficSession;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TrafficSessionRepository extends JpaRepository<TrafficSession, UUID> {

    Optional<TrafficSession> findByBoutiqueIdAndSessionId(UUID boutiqueId, String sessionId);

    @Query("SELECT s FROM TrafficSession s WHERE s.boutiqueId = :boutiqueId AND s.sessionId = :sessionId AND s.lastActivityAt > :cutoff")
    Optional<TrafficSession> findByBoutiqueIdAndSessionIdAndLastActivityAtAfter(
            @Param("boutiqueId") UUID boutiqueId,
            @Param("sessionId") String sessionId,
            @Param("cutoff") LocalDateTime cutoff);

    long countByBoutiqueId(UUID boutiqueId);

    long countByBoutiqueIdAndIsActiveTrue(UUID boutiqueId);

    long countByBoutiqueIdAndCreatedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    long countByBoutiqueIdAndIsBounceTrue(UUID boutiqueId);

    @Query("SELECT COALESCE(AVG(s.sessionDurationSeconds), 0) FROM TrafficSession s WHERE s.boutiqueId = :boutiqueId AND s.sessionDurationSeconds IS NOT NULL")
    double avgSessionDurationByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT s FROM TrafficSession s WHERE s.boutiqueId = :boutiqueId AND s.isActive = true AND s.lastActivityAt > :cutoff")
    List<TrafficSession> findActiveSessionsSince(@Param("boutiqueId") UUID boutiqueId, @Param("cutoff") LocalDateTime cutoff);

    Page<TrafficSession> findByBoutiqueIdOrderByLastActivityAtDesc(UUID boutiqueId, Pageable pageable);

    List<TrafficSession> findByBoutiqueIdAndLastActivityAtBefore(UUID boutiqueId, LocalDateTime cutoff);

    List<TrafficSession> findByBoutiqueIdAndCreatedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    @Query("SELECT s FROM TrafficSession s WHERE s.country = 'Inconnu' OR s.city = 'Inconnu'")
    List<TrafficSession> findAllWithInconnuLocation();
}
