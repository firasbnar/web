package io.makewebsite.service;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.security.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {
    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email déjà utilisé");
        }
        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .phone(request.getPhone())
                .language(request.getLanguage() != null ? request.getLanguage() : "fr")
                .role("OWNER")
                .build();
        user = userRepository.save(user);

        Boutique boutique = Boutique.builder()
                .user(user)
                .name(request.getFullName() + "'s Store")
                .slug(request.getFullName().toLowerCase().replaceAll("\\s+", "-").replaceAll("[^a-z0-9-]", "") + "-" + UUID.randomUUID().toString().substring(0, 6))
                .currency("TND")
                .language(request.getLanguage() != null ? request.getLanguage() : "fr")
                .isActive(true)
                .enableCod(true)
                .build();
        boutiqueRepository.save(boutique);

        UserPrincipal userPrincipal = new UserPrincipal(user);
        String accessToken = jwtUtil.generateAccessToken(userPrincipal);
        String refreshToken = jwtUtil.generateRefreshToken(userPrincipal);

        RefreshToken rt = RefreshToken.builder()
                .user(user)
                .token(refreshToken)
                .expiresAt(LocalDateTime.now().plusDays(7))
                .build();
        refreshTokenRepository.save(rt);

        return buildAuthResponse(user, accessToken, refreshToken);
    }

    public AuthResponse login(LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );
        UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();
        User user = userRepository.findById(userPrincipal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        String accessToken = jwtUtil.generateAccessToken(userPrincipal);
        String refreshToken = jwtUtil.generateRefreshToken(userPrincipal);

        RefreshToken rt = RefreshToken.builder()
                .user(user)
                .token(refreshToken)
                .expiresAt(LocalDateTime.now().plusDays(7))
                .build();
        refreshTokenRepository.save(rt);

        return buildAuthResponse(user, accessToken, refreshToken);
    }

    public AuthResponse refresh(RefreshTokenRequest request) {
        RefreshToken rt = refreshTokenRepository.findByToken(request.getRefreshToken())
                .orElseThrow(() -> new RuntimeException("Refresh token invalide"));
        if (rt.getExpiresAt().isBefore(LocalDateTime.now())) {
            refreshTokenRepository.delete(rt);
            throw new RuntimeException("Refresh token expiré");
        }
        User user = rt.getUser();
        UserPrincipal userPrincipal = new UserPrincipal(user);

        String newAccessToken = jwtUtil.generateAccessToken(userPrincipal);
        String newRefreshToken = jwtUtil.generateRefreshToken(userPrincipal);

        rt.setToken(newRefreshToken);
        rt.setExpiresAt(LocalDateTime.now().plusDays(7));
        refreshTokenRepository.save(rt);

        return buildAuthResponse(user, newAccessToken, newRefreshToken);
    }

    public UserResponse getProfile(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        return UserResponse.builder()
                .id(user.getId()).fullName(user.getFullName()).email(user.getEmail())
                .phone(user.getPhone()).role(user.getRole()).language(user.getLanguage())
                .avatarUrl(user.getAvatarUrl())
                .build();
    }

    @Transactional
    public UserResponse updateProfile(UUID userId, UpdateProfileRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (request.getFullName() != null) user.setFullName(request.getFullName());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        if (request.getLanguage() != null) user.setLanguage(request.getLanguage());
        user = userRepository.save(user);
        return UserResponse.builder()
                .id(user.getId()).fullName(user.getFullName()).email(user.getEmail())
                .phone(user.getPhone()).role(user.getRole()).language(user.getLanguage())
                .avatarUrl(user.getAvatarUrl())
                .build();
    }

    @Transactional
    public void changePassword(UUID userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        if (!passwordEncoder.matches(request.getOldPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Ancien mot de passe incorrect");
        }
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }

    @Transactional
    public void logout(RefreshTokenRequest request) {
        refreshTokenRepository.findByToken(request.getRefreshToken())
                .ifPresent(refreshTokenRepository::delete);
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
            user = User.builder()
                    .fullName(name != null ? name : email.split("@")[0])
                    .email(email)
                    .passwordHash(passwordEncoder.encode(UUID.randomUUID().toString()))
                    .role("OWNER")
                    .language("fr")
                    .avatarUrl(avatar)
                    .build();
            user = userRepository.save(user);

            Boutique boutique = Boutique.builder()
                    .user(user)
                    .name(name != null ? name + "'s Store" : email.split("@")[0] + "'s Store")
                    .slug(email.split("@")[0].toLowerCase().replaceAll("[^a-z0-9-]", "") + randomSlug)
                    .currency("TND")
                    .language("fr")
                    .isActive(true)
                    .enableCod(true)
                    .build();
            boutiqueRepository.save(boutique);
        }
        UserPrincipal userPrincipal = new UserPrincipal(user);
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

    private AuthResponse buildAuthResponse(User user, String accessToken, String refreshToken) {
        UserResponse userResponse = UserResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .language(user.getLanguage())
                .avatarUrl(user.getAvatarUrl())
                .build();
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .user(userResponse)
                .build();
    }
}
