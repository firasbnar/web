package io.makewebsite.service;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.security.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {
    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final TenantRepository tenantRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;
    private final EmailService emailService;
    private final CaisseService caisseService;
    private final UserSessionRepository userSessionRepository;
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = request.getEmail().trim().toLowerCase(java.util.Locale.ROOT);
        log.info("Register attempt for email: {}", email);
        try {
            if (userRepository.existsByEmail(email)) {
                log.warn("Registration failed: email already used: {}", email);
                throw new RuntimeException("Email déjà utilisé");
            }
            String verificationToken = UUID.randomUUID().toString() + "-" + UUID.randomUUID().toString();
            Tenant tenant = tenantRepository.save(Tenant.builder()
                    .name(request.getFullName() + "'s Tenant")
                    .build());
            User user = User.builder()
                    .fullName(request.getFullName())
                    .email(email)
                    .passwordHash(passwordEncoder.encode(request.getPassword()))
                    .phone(request.getPhone())
                    .tenant(tenant)
                    .language(request.getLanguage() != null ? request.getLanguage() : "fr")
                    .role("OWNER")
                    .emailVerified(false)
                    .enabled(false)
                    .verificationToken(verificationToken)
                    .verificationTokenExpiry(LocalDateTime.now().plusHours(24))
                    .build();
            user = userRepository.save(user);
            log.debug("User created: id={}, email={}, enabled=false, verificationToken={}",
                    user.getId(), user.getEmail(), verificationToken);

            emailService.sendVerificationEmail(user.getEmail(), verificationToken);
            log.info("Registration successful for email: {}, verification email sent", request.getEmail());

            return AuthResponse.builder()
                    .user(buildUserResponse(user))
                    .emailVerificationRequired(true)
                    .build();
        } catch (EmailService.EmailDeliveryException e) {
            log.error("Registration email delivery failed for email: {}", request.getEmail(), e);
            throw e;
        } catch (RuntimeException e) {
            log.error("Registration failed for email: {} — exceptionType={}, message={}", 
                    request.getEmail(), e.getClass().getName(), e.getMessage(), e);
            throw new RuntimeException("Erreur lors de l'inscription: " + e.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        return login(request, null, null);
    }

    @Transactional
    public AuthResponse login(LoginRequest request, String ipAddress, String deviceInfo) {
        String email = request.getEmail().trim().toLowerCase(java.util.Locale.ROOT);
        String rawPassword = request.getPassword();
        log.info("Login attempt for email: '{}', password length: {}", email, rawPassword != null ? rawPassword.length() : 0);

        // DEBUG: check if user exists before auth
        boolean userExists = userRepository.findByEmailIgnoreCase(email).isPresent();
        log.info("PRE-AUTH: user exists by email '{}': {}", email, userExists);
        if (userExists) {
            User preUser = userRepository.findByEmailIgnoreCase(email).get();
            log.info("PRE-AUTH: found user id={} enabled={} role={} hashPrefix={}",
                preUser.getId(), preUser.getEnabled(), preUser.getRole(),
                preUser.getPasswordHash() != null ? preUser.getPasswordHash().substring(0, Math.min(10, preUser.getPasswordHash().length())) : "null");
        } else {
            // Also try exact case-sensitive match
            userRepository.findByEmail(email).ifPresentOrElse(
                u -> log.warn("PRE-AUTH: user FOUND with case-sensitive but NOT with ignore-case! email='{}' stored='{}'", email, u.getEmail()),
                () -> log.warn("PRE-AUTH: user NOT FOUND with either case-sensitive or ignore-case for email='{}'", email)
            );
        }

        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(email, rawPassword)
            );
            UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();
            User user = userRepository.findByIdWithTenant(userPrincipal.getUserId())
                    .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

            if (!Boolean.TRUE.equals(user.getEnabled())) {
                log.warn("Login blocked: email not verified for user {}", user.getId());
                throw new EmailNotVerifiedException("Veuillez vérifier votre email avant de vous connecter");
            }
            if (Boolean.TRUE.equals(user.getIsSuspended())) {
                log.warn("Login blocked: account suspended for user {}", user.getId());
                throw new RuntimeException("Compte suspendu. Contactez le support.");
            }

            String accessToken = jwtUtil.generateAccessToken(userPrincipal);
            String refreshToken = jwtUtil.generateRefreshToken(userPrincipal);

            RefreshToken rt = RefreshToken.builder()
                    .user(user)
                    .token(refreshToken)
                    .expiresAt(LocalDateTime.now().plusDays(7))
                    .build();
            refreshTokenRepository.save(rt);

            user.setLastLoginAt(LocalDateTime.now());
            userRepository.save(user);

            // Record login activity for all boutiques
            recordUserActivity(user, "CONNEXION_CAISSE_REUSSIE", "Connexion réussie", ipAddress, deviceInfo);

            log.info("Login successful for user {}", user.getId());
            return buildAuthResponse(user, accessToken, refreshToken);
        } catch (BadCredentialsException e) {
            User user = userRepository.findByEmailIgnoreCase(email).orElse(null);
            if (user != null) {
                boolean pwMatch = passwordEncoder.matches(rawPassword, user.getPasswordHash());
                log.warn("Login FAILED for email='{}': user FOUND (id={}), password match={}", email, user.getId(), pwMatch);
                recordUserActivity(user, "CONNEXION_CAISSE_ECHOUEE", "Tentative de connexion échouée", ipAddress, deviceInfo);
            } else {
                log.warn("Login FAILED for email='{}': user NOT FOUND", email);
            }
            throw e;
        }
    }

    @Transactional
    public void verifyEmail(String token) {
        if (token == null || token.isBlank()) {
            throw new RuntimeException("Token de vérification manquant");
        }
        User user = userRepository.findByVerificationToken(token)
                .orElseThrow(() -> new RuntimeException("Token de vérification invalide ou déjà utilisé"));
        if (user.getVerificationTokenExpiry() == null || user.getVerificationTokenExpiry().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Token de vérification expiré. Demandez un nouveau lien.");
        }
        user.setEmailVerified(true);
        user.setEnabled(true);
        user.setVerificationToken(null);
        user.setVerificationTokenExpiry(null);

        // Invited users (mustChangePassword=true) need a temp password + credentials email.
        // Normal signup users keep the password they registered with.
        if (Boolean.TRUE.equals(user.getMustChangePassword())) {
            String tempPassword = generateTemporaryPassword();
            user.setPasswordHash(passwordEncoder.encode(tempPassword));
            userRepository.save(user);

            try {
                emailService.sendCredentialsEmail(user.getEmail(), tempPassword);
                log.info("Credentials email sent for user {}", user.getId());
            } catch (Exception e) {
                log.warn("Failed to send credentials email for user {}: {}", user.getId(), e.getMessage());
            }
        } else {
            userRepository.save(user);
        }
    }

    private String generateTemporaryPassword() {
        String upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        String lower = "abcdefghijklmnopqrstuvwxyz";
        String digits = "0123456789";
        String special = "!@#$%";
        String all = upper + lower + digits + special;
        java.util.Random random = new java.util.Random();
        StringBuilder sb = new StringBuilder(12);
        sb.append(upper.charAt(random.nextInt(upper.length())));
        sb.append(lower.charAt(random.nextInt(lower.length())));
        sb.append(digits.charAt(random.nextInt(digits.length())));
        sb.append(special.charAt(random.nextInt(special.length())));
        for (int i = 0; i < 8; i++) {
            sb.append(all.charAt(random.nextInt(all.length())));
        }
        List<Character> chars = new java.util.ArrayList<>();
        for (char c : sb.toString().toCharArray()) chars.add(c);
        java.util.Collections.shuffle(chars, random);
        StringBuilder result = new StringBuilder();
        for (char c : chars) result.append(c);
        return result.toString();
    }

    @Transactional
    public void resendVerification(String email) {
        if (email == null || email.isBlank()) {
            throw new RuntimeException("Email requis");
        }
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Aucun compte trouvé avec cet email"));
        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new RuntimeException("Email déjà vérifié. Vous pouvez vous connecter.");
        }
        String newToken = UUID.randomUUID().toString() + "-" + UUID.randomUUID().toString();
        user.setVerificationToken(newToken);
        user.setVerificationTokenExpiry(LocalDateTime.now().plusHours(24));
        userRepository.save(user);
        emailService.sendVerificationEmail(user.getEmail(), newToken);
        log.info("Verification email resent successfully to user {}", user.getId());
    }

    @Transactional(readOnly = true)
    public AuthResponse refresh(RefreshTokenRequest request) {
        RefreshToken rt = refreshTokenRepository.findByToken(request.getRefreshToken())
                .orElseThrow(() -> new RuntimeException("Refresh token invalide"));
        if (rt.getExpiresAt().isBefore(LocalDateTime.now())) {
            refreshTokenRepository.delete(rt);
            throw new RuntimeException("Refresh token expiré");
        }
        User user = userRepository.findByIdWithTenant(rt.getUser().getId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        UserPrincipal userPrincipal = new UserPrincipal(
                user.getId(), user.getEmail(), user.getPasswordHash(),
                user.getRole(), user.getTenant().getId());

        String newAccessToken = jwtUtil.generateAccessToken(userPrincipal);
        String newRefreshToken = jwtUtil.generateRefreshToken(userPrincipal);

        rt.setToken(newRefreshToken);
        rt.setExpiresAt(LocalDateTime.now().plusDays(7));
        refreshTokenRepository.save(rt);

        return buildAuthResponse(user, newAccessToken, newRefreshToken);
    }

    @Transactional(readOnly = true)
    public UserResponse getProfile(UUID userId) {
        User user = userRepository.findByIdWithTenant(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        return buildUserResponse(user);
    }

    @Transactional
    public UserResponse updateProfile(UUID userId, UpdateProfileRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (request.getFullName() != null) user.setFullName(request.getFullName());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        if (request.getLanguage() != null) user.setLanguage(request.getLanguage());
        user = userRepository.save(user);
        return buildUserResponse(user);
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (!passwordEncoder.matches(request.getOldPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Ancien mot de passe incorrect");
        }
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        user.setMustChangePassword(false);
        userRepository.save(user);
    }

    @Transactional
    public void logout(RefreshTokenRequest request) {
        logout(request, null, null);
    }

    @Transactional
    public void logout(RefreshTokenRequest request, String ipAddress, String deviceInfo) {
        refreshTokenRepository.findByToken(request.getRefreshToken())
                .ifPresent(rt -> {
                    User user = rt.getUser();
                    refreshTokenRepository.delete(rt);
                    if (user != null) {
                        recordUserActivity(user, "DECONNEXION_CAISSE", "Déconnexion", ipAddress, deviceInfo);
                    }
                });
    }

    @Transactional
    public AuthResponse loginWithGoogle(String idToken) {
        RestTemplate rt = new RestTemplate();
        String verifyUrl = "https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken;
        java.util.Map response;
        try {
            response = rt.getForObject(verifyUrl, java.util.Map.class);
        } catch (Exception e) {
            throw new RuntimeException("Token Google invalide");
        }
        String email = (String) response.get("email");
        String name = (String) response.get("name");
        String avatar = (String) response.get("picture");

        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) {
            String randomSlug = "-" + UUID.randomUUID().toString().substring(0, 6);
            Tenant tenant = tenantRepository.save(Tenant.builder()
                    .name((name != null ? name : email.split("@")[0]) + "'s Tenant")
                    .build());
            user = User.builder()
                    .fullName(name != null ? name : email.split("@")[0])
                    .email(email)
                    .passwordHash(passwordEncoder.encode(UUID.randomUUID().toString()))
                    .tenant(tenant)
                    .role("OWNER")
                    .language("fr")
                    .avatarUrl(avatar)
                    .emailVerified(true)
                    .enabled(true)
                    .build();
            user = userRepository.save(user);

            Boutique boutique = Boutique.builder()
                    .user(user)
                    .tenant(tenant)
                    .name(name != null ? name + "'s Store" : email.split("@")[0] + "'s Store")
                    .slug(email.split("@")[0].toLowerCase().replaceAll("[^a-z0-9-]", "") + randomSlug)
                    .currency("TND")
                    .language("fr")
                    .isActive(true)
                    .enableCod(true)
                    .build();
            boutiqueRepository.save(boutique);
        } else {
            ensureTenant(user);
            if (!Boolean.TRUE.equals(user.getEmailVerified())) {
                user.setEmailVerified(true);
                user.setEnabled(true);
                user.setVerificationToken(null);
                user.setVerificationTokenExpiry(null);
                userRepository.save(user);
            }
        }
        UserPrincipal userPrincipal = new UserPrincipal(
                user.getId(), user.getEmail(), user.getPasswordHash(),
                user.getRole(), user.getTenant().getId());
        String accessToken = jwtUtil.generateAccessToken(userPrincipal);
        String refreshToken = jwtUtil.generateRefreshToken(userPrincipal);

        RefreshToken rt2 = RefreshToken.builder()
                .user(user)
                .token(refreshToken)
                .expiresAt(LocalDateTime.now().plusDays(7))
                .build();
        refreshTokenRepository.save(rt2);

        return buildAuthResponse(user, accessToken, refreshToken);
    }

    private void recordUserActivity(User user, String action, String details,
                                     String ipAddress, String deviceInfo) {
        try {
            List<Boutique> boutiques = boutiqueRepository.findByUserId(user.getId());
            for (Boutique b : boutiques) {
                caisseService.recordActivity(b.getId(), user.getId(), user.getFullName(),
                        action, "SUCCESS", details, ipAddress, deviceInfo);
            }
        } catch (Exception e) {
            log.warn("Failed to record activity for user {}: {}", user.getId(), e.getMessage());
        }
    }

    private void recordUserActivity(User user, String action, String details) {
        recordUserActivity(user, action, details, null, null);
    }

    private AuthResponse buildAuthResponse(User user, String accessToken, String refreshToken) {
        boolean subActive = subscriptionRepository.findByUserIdAndStatus(user.getId(), "ACTIVE").isPresent();
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .user(buildUserResponse(user))
                .role(user.getRole())
                .tenant(buildTenantResponse(user.getTenant()))
                .emailVerificationRequired(false)
                .subscriptionActive(subActive || "SUPER_ADMIN".equals(user.getRole()))
                .build();
    }

    private UserResponse buildUserResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .tenantId(user.getTenant() != null ? user.getTenant().getId() : null)
                .language(user.getLanguage())
                .avatarUrl(user.getAvatarUrl())
                .emailVerified(Boolean.TRUE.equals(user.getEmailVerified()))
                .build();
    }

    private Tenant ensureTenant(User user) {
        if (user.getTenant() != null) {
            return user.getTenant();
        }
        Tenant tenant = tenantRepository.save(Tenant.builder()
                .name((user.getFullName() != null ? user.getFullName() : "User") + "'s Tenant")
                .build());
        user.setTenant(tenant);
        return tenant;
    }

    private TenantResponse buildTenantResponse(Tenant tenant) {
        if (tenant == null) {
            return null;
        }
        return TenantResponse.builder()
                .id(tenant.getId())
                .name(tenant.getName())
                .build();
    }

    public static class EmailNotVerifiedException extends RuntimeException {
        public EmailNotVerifiedException(String message) {
            super(message);
        }
    }
}
