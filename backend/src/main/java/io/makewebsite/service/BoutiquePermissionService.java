package io.makewebsite.service;

import io.makewebsite.entity.TeamMember;
import io.makewebsite.entity.User;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.TeamMemberRepository;
import io.makewebsite.repository.UserRepository;
import io.makewebsite.security.Permission;
import io.makewebsite.security.RolePermissions;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class BoutiquePermissionService {
    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final TeamMemberRepository teamMemberRepository;

    public boolean hasBoutiquePermission(UUID userId, UUID boutiqueId, Permission permission) {
        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            return false;
        }
        String userRole = user.getRole();
        if ("SUPER_ADMIN".equalsIgnoreCase(userRole) || "ADMIN".equalsIgnoreCase(userRole)) {
            return true;
        }
        UUID ownerId = boutiqueRepository.findOwnerIdByBoutiqueId(boutiqueId);
        if (userId.equals(ownerId)) {
            return true;
        }
        return teamMemberRepository.findByBoutiqueIdAndUserIdAndStatus(boutiqueId, userId, "ACTIVE")
                .map(TeamMember::getRole)
                .map(role -> RolePermissions.hasPermission(role, permission))
                .orElse(false);
    }

    public boolean hasAnyBoutiquePermission(UUID userId, UUID boutiqueId, Permission... permissions) {
        for (Permission permission : permissions) {
            if (hasBoutiquePermission(userId, boutiqueId, permission)) {
                return true;
            }
        }
        return false;
    }

    public void requireBoutiquePermission(UUID userId, UUID boutiqueId, Permission permission) {
        if (!hasBoutiquePermission(userId, boutiqueId, permission)) {
            throw new AccessDeniedException("Acces refuse");
        }
    }

    public void requireAnyBoutiquePermission(UUID userId, UUID boutiqueId, Permission... permissions) {
        if (!hasAnyBoutiquePermission(userId, boutiqueId, permissions)) {
            throw new AccessDeniedException("Acces refuse");
        }
    }
}
