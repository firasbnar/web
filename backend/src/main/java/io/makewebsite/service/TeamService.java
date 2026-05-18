package io.makewebsite.service;

import io.makewebsite.dto.request.InviteTeamMemberRequest;
import io.makewebsite.dto.request.UpdateRoleRequest;
import io.makewebsite.dto.response.TeamMemberResponse;
import io.makewebsite.dto.response.TeamStatsResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.TeamInvitation;
import io.makewebsite.entity.TeamMember;
import io.makewebsite.entity.User;
import io.makewebsite.exception.ResourceNotFoundException;
import io.makewebsite.repository.*;
import io.makewebsite.security.Permission;
import io.makewebsite.security.RolePermissions;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TeamService {
    private static final String DEFAULT_ROLE = "STAFF";
    private static final String STATUS_ACTIVE = "ACTIVE";
    private static final String STATUS_DEACTIVATED = "DEACTIVATED";
    private static final Set<String> ALLOWED_ROLES = Set.of("ADMIN", "MANAGER", "STAFF", "CAISSIER");

    private final TeamMemberRepository teamMemberRepository;
    private final TeamInvitationRepository teamInvitationRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;
    private final ActivityLogService activityLogService;
    @Transactional(readOnly = true)
    public List<TeamMemberResponse> getTeamMembers(UUID boutiqueId, UUID userId) {
        requireOwnedBoutiqueOrAdmin(boutiqueId, userId);
        return teamMemberRepository.findByBoutiqueId(boutiqueId).stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public TeamMemberResponse inviteMember(InviteTeamMemberRequest request, UUID userId) {
        UUID boutiqueId = request.getBoutiqueId();
        Boutique boutique = requireOwnedBoutique(boutiqueId, userId);
        String email = normalizeEmail(request.getEmail());
        String role = normalizeRole(request.getRole());
        String name = request.getName() != null ? request.getName().trim() : email.split("@")[0];

        if (email.equalsIgnoreCase(boutique.getUser().getEmail())) {
            throw new IllegalArgumentException("Le proprietaire de la boutique est deja membre");
        }
        if (teamMemberRepository.existsByBoutiqueIdAndInvitedEmailIgnoreCase(boutique.getId(), email)) {
            throw new IllegalArgumentException("Cet email a deja ete invite");
        }

        User currentUser = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouve"));

        // Check if user already has an account in the system
        Optional<User> existingUser = userRepository.findByEmailIgnoreCase(email);
        User user;

        if (existingUser.isPresent()) {
            user = existingUser.get();
            if (teamMemberRepository.existsByBoutiqueIdAndUserId(boutique.getId(), user.getId())) {
                throw new IllegalArgumentException("Cet utilisateur est deja membre de cette boutique");
            }
        } else {
            String verificationToken = UUID.randomUUID().toString() + "-" + UUID.randomUUID().toString();
            String randomHash = passwordEncoder.encode(UUID.randomUUID().toString() + UUID.randomUUID().toString());

            user = User.builder()
                    .email(email)
                    .fullName(name)
                    .passwordHash(randomHash)
                    .tenant(boutique.getTenant())
                    .role("USER")
                    .emailVerified(false)
                    .enabled(false)
                    .mustChangePassword(true)
                    .verificationToken(verificationToken)
                    .verificationTokenExpiry(LocalDateTime.now().plusHours(24))
                    .build();
            user = userRepository.save(user);

            try {
                emailService.sendInvitationVerificationEmail(email, verificationToken, boutique.getName(), role, name, currentUser.getFullName());
            } catch (Exception e) {
                log.warn("Failed to send invitation verification email to {}: {}", email, e.getMessage());
            }
        }

        TeamMember member = TeamMember.builder()
                .boutique(boutique)
                .user(user)
                .name(name)
                .invitedEmail(email)
                .role(role)
                .status("ACTIVE")
                .invitedAt(LocalDateTime.now())
                .joinedAt(LocalDateTime.now())
                .build();

        try {
            member = teamMemberRepository.save(member);
        } catch (DataIntegrityViolationException e) {
            throw new IllegalArgumentException("Cet utilisateur a deja une invitation ou un acces a cette boutique", e);
        }

        TeamInvitation invitation = TeamInvitation.builder()
                .boutique(boutique)
                .invitedEmail(email)
                .role(role)
                .status("ACCEPTED")
                .acceptedAt(LocalDateTime.now())
                .build();
        teamInvitationRepository.save(invitation);

        activityLogService.record(boutique.getId(), userId, currentUser.getFullName(),
                "INVITATION_ENVOYEE", "SUCCESS",
                "Invitation envoyee a " + email + " (" + role + ")",
                null, null);

        return mapToResponse(member);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getInvitationById(UUID id) {
        log.debug("Getting invitation by id={}", id);
        TeamInvitation invitation = teamInvitationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Invitation non trouvee"));

        Map<String, Object> result = new HashMap<>();
        result.put("id", invitation.getId());
        result.put("email", invitation.getInvitedEmail());
        result.put("role", invitation.getRole());
        result.put("status", invitation.getStatus());
        result.put("boutiqueName", invitation.getBoutique().getName());
        result.put("expiresAt", invitation.getTokenExpiresAt() != null ? invitation.getTokenExpiresAt().toString() : null);
        result.put("createdAt", invitation.getCreatedAt() != null ? invitation.getCreatedAt().toString() : null);
        return result;
    }

    @Transactional
    public void removeMember(UUID memberId, UUID boutiqueId, UUID userId) {
        requireOwnedBoutiqueOrAdmin(boutiqueId, userId);
        TeamMember member = findMemberInBoutique(memberId, boutiqueId);

        if (isOwner(member)) {
            throw new IllegalArgumentException("Impossible de supprimer le proprietaire de la boutique");
        }

        teamMemberRepository.delete(member);

        User currentUser = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouve"));
        activityLogService.record(boutiqueId, userId, currentUser.getFullName(),
                "MEMBRE_SUPPRIME", "SUCCESS",
                "Membre supprime: " + (member.getInvitedEmail() != null ? member.getInvitedEmail() : member.getName()),
                null, null);
    }

    @Transactional
    public TeamMemberResponse updateMemberRole(UUID memberId, UpdateRoleRequest request, UUID boutiqueId, UUID userId) {
        requireOwnedBoutiqueOrAdmin(boutiqueId, userId);
        TeamMember member = findMemberInBoutique(memberId, boutiqueId);

        if (isOwner(member)) {
            throw new IllegalArgumentException("Impossible de modifier le role du proprietaire");
        }

        String newRole = normalizeRole(request.getRole());
        String oldRole = member.getRole();
        member.setRole(newRole);
        member = teamMemberRepository.save(member);

        User currentUser = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouve"));
        activityLogService.record(boutiqueId, userId, currentUser.getFullName(),
                "ROLE_MODIFIE", "SUCCESS",
                "Role de " + (member.getInvitedEmail() != null ? member.getInvitedEmail() : member.getName())
                        + ": " + oldRole + " -> " + newRole,
                null, null);

        return mapToResponse(member);
    }

    @Transactional
    public TeamMemberResponse toggleMemberStatus(UUID memberId, UUID boutiqueId, boolean activate, UUID userId) {
        requireOwnedBoutiqueOrAdmin(boutiqueId, userId);
        TeamMember member = findMemberInBoutique(memberId, boutiqueId);

        if (isOwner(member)) {
            throw new IllegalArgumentException("Impossible de desactiver le proprietaire de la boutique");
        }

        if (activate) {
            member.setStatus(STATUS_ACTIVE);
            member.setDeactivatedAt(null);
        } else {
            member.setStatus(STATUS_DEACTIVATED);
            member.setDeactivatedAt(LocalDateTime.now());
        }
        member = teamMemberRepository.save(member);

        User currentUser = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouve"));
        activityLogService.record(boutiqueId, userId, currentUser.getFullName(),
                activate ? "MEMBRE_ACTIVE" : "MEMBRE_DESACTIVE", "SUCCESS",
                (activate ? "Activation" : "Desactivation") + " de "
                        + (member.getInvitedEmail() != null ? member.getInvitedEmail() : member.getName()),
                null, null);

        return mapToResponse(member);
    }

    @Transactional(readOnly = true)
    public TeamStatsResponse getTeamStats(UUID boutiqueId, UUID userId) {
        requireOwnedBoutiqueOrAdmin(boutiqueId, userId);

        long total = teamMemberRepository.countByBoutiqueId(boutiqueId);
        long active = teamMemberRepository.countByBoutiqueIdAndStatus(boutiqueId, STATUS_ACTIVE);
        Map<String, Long> roleDist = teamMemberRepository.getRoleDistribution(boutiqueId);

        return TeamStatsResponse.builder()
                .totalMembers(total + 1)
                .activeMembers(active + 1)
                .pendingInvitations(0)
                .roleDistribution(roleDist)
                .build();
    }

    @Transactional(readOnly = true)
    public List<TeamMemberResponse> searchMembers(UUID boutiqueId, String query, String roleFilter, String statusFilter, UUID userId) {
        requireOwnedBoutiqueOrAdmin(boutiqueId, userId);
        return teamMemberRepository.findByBoutiqueId(boutiqueId).stream()
                .filter(m -> {
                    if (query == null || query.isBlank()) return true;
                    String q = query.toLowerCase();
                    String name = m.getName() != null ? m.getName().toLowerCase() : "";
                    String email = m.getInvitedEmail() != null ? m.getInvitedEmail().toLowerCase() : "";
                    return name.contains(q) || email.contains(q);
                })
                .filter(m -> roleFilter == null || roleFilter.isBlank() || roleFilter.equalsIgnoreCase(m.getRole()))
                .filter(m -> statusFilter == null || statusFilter.isBlank() || statusFilter.equalsIgnoreCase(m.getStatus()))
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public void updateLastActivity(UUID userId) {
        userRepository.findById(userId).ifPresent(user -> {
            boutiqueRepository.findByUserId(userId).forEach(boutique -> {
                teamMemberRepository.findByBoutiqueIdAndUserId(boutique.getId(), userId)
                        .ifPresent(member -> {
                            member.setLastActivityAt(LocalDateTime.now());
                            teamMemberRepository.save(member);
                        });
            });
        });
    }

    private Boutique requireOwnedBoutiqueOrAdmin(UUID boutiqueId, UUID userId) {
        Objects.requireNonNull(boutiqueId, "boutiqueId is required");
        Objects.requireNonNull(userId, "userId is required");
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouve"));

        if ("ADMIN".equalsIgnoreCase(user.getRole()) || "SUPER_ADMIN".equalsIgnoreCase(user.getRole())) {
            return boutiqueRepository.findById(boutiqueId)
                    .orElseThrow(() -> new ResourceNotFoundException("Boutique non trouvee"));
        }

        return boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new ResourceNotFoundException("Boutique non trouvee"));
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

    private boolean isOwner(TeamMember member) {
        if (member.getUser() != null) {
            return "OWNER".equalsIgnoreCase(member.getUser().getRole())
                    && member.getBoutique() != null
                    && member.getBoutique().getUser() != null
                    && member.getBoutique().getUser().getId().equals(member.getUser().getId());
        }
        return false;
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
        List<String> perms = RolePermissions.getPermissions(member.getRole()).stream()
                .map(Permission::name)
                .collect(Collectors.toList());

        return TeamMemberResponse.builder()
                .id(member.getId())
                .boutiqueId(member.getBoutique().getId())
                .userId(member.getUser() != null ? member.getUser().getId() : null)
                .name(member.getName())
                .invitedEmail(member.getInvitedEmail())
                .userEmail(member.getUser() != null ? member.getUser().getEmail() : null)
                .role(member.getRole())
                .status(member.getStatus())
                .invitedAt(member.getInvitedAt())
                .joinedAt(member.getJoinedAt())
                .lastActivityAt(member.getLastActivityAt())
                .permissions(perms)
                .build();
    }
}
