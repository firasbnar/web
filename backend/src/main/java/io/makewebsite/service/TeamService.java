package io.makewebsite.service;

import io.makewebsite.dto.request.InviteTeamMemberRequest;
import io.makewebsite.dto.request.UpdateRoleRequest;
import io.makewebsite.dto.response.TeamMemberResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.TeamMember;
import io.makewebsite.entity.User;
import io.makewebsite.exception.ResourceNotFoundException;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.TeamMemberRepository;
import io.makewebsite.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TeamService {
    private static final String DEFAULT_ROLE = "STAFF";
    private static final String STATUS_PENDING = "PENDING";
    private static final Set<String> ALLOWED_ROLES = Set.of("ADMIN", "MANAGER", "STAFF");

    private final TeamMemberRepository teamMemberRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public List<TeamMemberResponse> getTeamMembers(UUID boutiqueId, UUID userId) {
        requireOwnedBoutique(boutiqueId, userId);

        return teamMemberRepository.findByBoutiqueId(boutiqueId).stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public TeamMemberResponse inviteMember(InviteTeamMemberRequest request, UUID userId) {
        Boutique boutique = requireOwnedBoutique(request.getBoutiqueId(), userId);
        String email = normalizeEmail(request.getEmail());
        String role = normalizeRole(request.getRole());

        if (email.equalsIgnoreCase(boutique.getUser().getEmail())) {
            throw new IllegalArgumentException("Le proprietaire de la boutique est deja membre");
        }

        if (teamMemberRepository.existsByBoutiqueIdAndInvitedEmailIgnoreCase(boutique.getId(), email)) {
            throw new IllegalArgumentException("Cet email a deja ete invite");
        }

        TeamMember member = userRepository.findByEmailIgnoreCase(email)
                .map(user -> {
                    if (teamMemberRepository.existsByBoutiqueIdAndUserId(boutique.getId(), user.getId())) {
                        throw new IllegalArgumentException("Cet utilisateur est deja membre de cette boutique");
                    }
                    return buildInvitation(boutique, email, role, user);
                })
                .orElseGet(() -> buildInvitation(boutique, email, role, null));

        try {
            return mapToResponse(teamMemberRepository.save(member));
        } catch (DataIntegrityViolationException e) {
            throw new IllegalArgumentException("Cet utilisateur a deja une invitation ou un acces a cette boutique", e);
        }
    }

    @Transactional
    public void removeMember(UUID memberId, UUID boutiqueId, UUID userId) {
        requireOwnedBoutique(boutiqueId, userId);
        TeamMember member = findMemberInBoutique(memberId, boutiqueId);

        teamMemberRepository.delete(member);
    }

    @Transactional
    public TeamMemberResponse updateMemberRole(UUID memberId, UpdateRoleRequest request, UUID boutiqueId, UUID userId) {
        requireOwnedBoutique(boutiqueId, userId);
        TeamMember member = findMemberInBoutique(memberId, boutiqueId);

        member.setRole(normalizeRole(request.getRole()));
        return mapToResponse(teamMemberRepository.save(member));
    }

    private Boutique requireOwnedBoutique(UUID boutiqueId, UUID userId) {
        Objects.requireNonNull(boutiqueId, "boutiqueId is required");
        Objects.requireNonNull(userId, "userId is required");

        return boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new ResourceNotFoundException("Boutique non trouvee"));
    }

    private TeamMember findMemberInBoutique(UUID memberId, UUID boutiqueId) {
        Objects.requireNonNull(memberId, "memberId is required");

        return teamMemberRepository.findByIdAndBoutiqueId(memberId, boutiqueId)
                .orElseThrow(() -> new AccessDeniedException("Membre non trouve ou acces refuse"));
    }

    private TeamMember buildInvitation(Boutique boutique, String email, String role, User user) {
        return TeamMember.builder()
                .boutique(boutique)
                .user(user)
                .name(user != null ? user.getFullName() : null)
                .invitedEmail(email)
                .role(role)
                .status(STATUS_PENDING)
                .invitedAt(LocalDateTime.now())
                .build();
    }

    private String normalizeEmail(String email) {
        if (!StringUtils.hasText(email)) {
            throw new IllegalArgumentException("Email requis");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private String normalizeRole(String role) {
        String normalized = StringUtils.hasText(role)
                ? role.trim().toUpperCase(Locale.ROOT)
                : DEFAULT_ROLE;

        if (!ALLOWED_ROLES.contains(normalized)) {
            throw new IllegalArgumentException("Role d'equipe invalide");
        }
        return normalized;
    }

    private TeamMemberResponse mapToResponse(TeamMember member) {
        return TeamMemberResponse.builder()
                .id(member.getId())
                .boutiqueId(member.getBoutique().getId())
                .userId(member.getUser() != null ? member.getUser().getId() : null)
                .name(member.getName())
                .invitedEmail(member.getInvitedEmail())
                .role(member.getRole())
                .status(member.getStatus())
                .invitedAt(member.getInvitedAt())
                .joinedAt(member.getJoinedAt())
                .build();
    }
}
