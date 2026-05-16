package io.makewebsite.repository;

import io.makewebsite.entity.TeamMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TeamMemberRepository extends JpaRepository<TeamMember, UUID> {
    List<TeamMember> findByBoutiqueId(UUID boutiqueId);
    Optional<TeamMember> findByIdAndBoutiqueId(UUID id, UUID boutiqueId);
    Optional<TeamMember> findByBoutiqueIdAndUserId(UUID boutiqueId, UUID userId);
    Optional<TeamMember> findByBoutiqueIdAndInvitedEmail(UUID boutiqueId, String email);
    boolean existsByBoutiqueIdAndUserId(UUID boutiqueId, UUID userId);
    boolean existsByBoutiqueIdAndInvitedEmailIgnoreCase(UUID boutiqueId, String email);
    void deleteByBoutiqueId(UUID boutiqueId);
    long countByBoutiqueId(UUID boutiqueId);
}
