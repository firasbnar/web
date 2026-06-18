package io.makewebsite.service;

import io.makewebsite.dto.request.ChangePasswordRequest;
import io.makewebsite.dto.response.UserResponse;
import io.makewebsite.entity.User;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.TeamMemberRepository;
import io.makewebsite.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final UploadService uploadService;
    private final PasswordEncoder passwordEncoder;

    public UserResponse getProfile(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        return mapToResponse(user);
    }

    @Transactional
    public String updateProfilePicture(UUID userId, MultipartFile file) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        String oldUrl = user.getAvatarUrl();
        String newUrl = uploadService.uploadImage(file, "profiles");

        user.setAvatarUrl(newUrl);
        userRepository.save(user);

        if (oldUrl != null && !oldUrl.isBlank()) {
            uploadService.deletePublicUrl(oldUrl);
        }

        log.info("Profile picture updated for userId={}", userId);
        return newUrl;
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            log.warn("Password change failed: incorrect current password for userId={}", userId);
            throw new RuntimeException("Mot de passe actuel incorrect");
        }

        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            throw new RuntimeException("Les mots de passe ne correspondent pas");
        }

        if (request.getNewPassword().length() < 8) {
            throw new RuntimeException("Le nouveau mot de passe doit contenir au moins 8 caractères");
        }

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        log.info("Password changed successfully for userId={}", userId);
    }

    @Transactional
    public void setActiveBoutique(UUID userId, UUID boutiqueId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        boolean ownsBoutique = boutiqueRepository.findByUserIdAndId(userId, boutiqueId).isPresent();
        boolean activeTeamMember = teamMemberRepository.findByBoutiqueIdAndUserIdAndStatus(boutiqueId, userId, "ACTIVE").isPresent();
        if (!ownsBoutique && !activeTeamMember) {
            throw new RuntimeException("Boutique non trouvÃ©e");
        }
        user.setActiveBoutiqueId(boutiqueId);
        userRepository.save(user);
    }

    private UserResponse mapToResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .tenantId(user.getTenant() != null ? user.getTenant().getId() : null)
                .language(user.getLanguage())
                .avatarUrl(user.getAvatarUrl())
                .emailVerified(user.getEmailVerified() != null && user.getEmailVerified())
                .build();
    }
}
