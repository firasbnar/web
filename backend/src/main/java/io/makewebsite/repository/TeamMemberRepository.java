package io.makewebsite.repository;

import io.makewebsite.entity.TeamMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

public interface TeamMemberRepository extends JpaRepository<TeamMember, UUID> {
    List<TeamMember> findByBoutiqueId(UUID boutiqueId);
    Optional<TeamMember> findByIdAndBoutiqueId(UUID id, UUID boutiqueId);
    Optional<TeamMember> findByBoutiqueIdAndUserId(UUID boutiqueId, UUID userId);
    Optional<TeamMember> findByBoutiqueIdAndInvitedEmail(UUID boutiqueId, String email);
    boolean existsByBoutiqueIdAndUserId(UUID boutiqueId, UUID userId);
    boolean existsByBoutiqueIdAndInvitedEmailIgnoreCase(UUID boutiqueId, String email);
    void deleteByBoutiqueId(UUID boutiqueId);
    long countByBoutiqueId(UUID boutiqueId);
    long countByBoutiqueIdAndStatus(UUID boutiqueId, String status);
    long countByBoutiqueIdAndStatusAndJoinedAtAfter(UUID boutiqueId, String status, LocalDateTime after);

    @Query("SELECT t.role, COUNT(t) FROM TeamMember t WHERE t.boutique.id = :boutiqueId GROUP BY t.role")
    List<Object[]> countByRoleGrouped(@Param("boutiqueId") UUID boutiqueId);

    default Map<String, Long> getRoleDistribution(UUID boutiqueId) {
        return countByRoleGrouped(boutiqueId).stream()
                .collect(Collectors.toMap(
                        row -> (String) row[0],
                        row -> (Long) row[1]
                ));
    }
}
