package io.makewebsite.repository;

import io.makewebsite.entity.UserSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserSessionRepository extends JpaRepository<UserSession, UUID> {
    List<UserSession> findByUserIdAndIsActiveTrueOrderByLastActivityDesc(UUID userId);
    Optional<UserSession> findByTokenHash(String tokenHash);
    @Modifying
    @Query("UPDATE UserSession s SET s.isActive = false WHERE s.user.id = ?1 AND s.id <> ?2")
    void deactivateOtherSessions(UUID userId, UUID currentSessionId);
    @Modifying
    @Query("UPDATE UserSession s SET s.isActive = false WHERE s.user.id = ?1")
    void deactivateAllUserSessions(UUID userId);
    long countByUserIdAndIsActiveTrue(UUID userId);
}
