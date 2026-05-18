package io.makewebsite.repository;

import io.makewebsite.entity.TeamInvitation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface TeamInvitationRepository extends JpaRepository<TeamInvitation, UUID> {
    Optional<TeamInvitation> findByBoutiqueIdAndInvitedEmailAndStatus(UUID boutiqueId, String email, String status);
    boolean existsByBoutiqueIdAndInvitedEmailAndStatus(UUID boutiqueId, String email, String status);
    long countByBoutiqueIdAndStatus(UUID boutiqueId, String status);
}
