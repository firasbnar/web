package io.makewebsite.service;

import io.makewebsite.dto.ResetPasswordRequest;
import io.makewebsite.entity.PasswordResetToken;
import io.makewebsite.entity.User;
import io.makewebsite.repository.PasswordResetTokenRepository;
import io.makewebsite.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
@Slf4j
public class PasswordResetService {

    private static final int TOKEN_BYTES = 32;
    private static final int TOKEN_EXPIRY_MINUTES = 30;
    private static final int RATE_LIMIT_MAX = 3;
    private static final long RATE_LIMIT_WINDOW_MS = 3600_000;

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final Base64.Encoder BASE64_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    @Value("${app.public-url}")
    private String publicUrl;

    private final Map<String, List<Long>> rateLimitMap = new ConcurrentHashMap<>();

    @Transactional
    public Map<String, Object> forgotPassword(String email, HttpServletRequest request) {
        String ip = request.getRemoteAddr();
        log.info("forgot-password: email={}, ip={}", email, ip);

        if (isRateLimited(ip)) {
            log.warn("forgot-password rate limited for IP: {}", ip);
            return genericSuccess();
        }

        Optional<User> userOpt = userRepository.findByEmailIgnoreCase(email.trim());
        log.info("forgot-password: user found={}", userOpt.isPresent());

        if (userOpt.isPresent()) {
            User user = userOpt.get();
            log.info("forgot-password: generating token for userId={}", user.getId());

            tokenRepository.deleteByUser(user);
            log.debug("forgot-password: old tokens invalidated for userId={}", user.getId());

            byte[] tokenBytes = new byte[TOKEN_BYTES];
            SECURE_RANDOM.nextBytes(tokenBytes);
            String rawToken = BASE64_ENCODER.encodeToString(tokenBytes);
            String tokenHash = passwordEncoder.encode(rawToken);
            log.debug("forgot-password: rawToken length={}, hash generated", rawToken.length());

            PasswordResetToken resetToken = PasswordResetToken.builder()
                    .user(user)
                    .tokenHash(tokenHash)
                    .expiresAt(LocalDateTime.now().plusMinutes(TOKEN_EXPIRY_MINUTES))
                    .build();

            tokenRepository.save(resetToken);
            log.info("forgot-password: token saved for userId={}", user.getId());

            String encodedToken = URLEncoder.encode(rawToken, StandardCharsets.UTF_8);
            String resetLink = publicUrl + "/api/auth/reset-password/redirect?token=" + encodedToken;
            log.info("forgot-password: resetLink={}", resetLink);

            emailService.sendPasswordResetEmail(user.getEmail(), rawToken, resetLink);
            log.info("forgot-password: email dispatched (async) to {}", user.getEmail());
        }

        log.info("forgot-password: returning generic success for email={}", email);
        return genericSuccess();
    }

    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        log.info("reset-password: received request, token length={}", request.getToken().length());

        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            log.warn("reset-password: password mismatch");
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Les mots de passe ne correspondent pas");
        }

        List<PasswordResetToken> allTokens = tokenRepository.findAll();
        log.debug("reset-password: scanning {} tokens", allTokens.size());

        PasswordResetToken matchingToken = null;
        for (PasswordResetToken t : allTokens) {
            if (passwordEncoder.matches(request.getToken(), t.getTokenHash())) {
                matchingToken = t;
                break;
            }
        }

        if (matchingToken == null) {
            log.warn("reset-password: no matching token found");
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Token invalide ou déjà utilisé");
        }

        log.info("reset-password: matching token found for userId={}", matchingToken.getUser().getId());

        if (matchingToken.getUsedAt() != null) {
            log.warn("reset-password: token already used at {}", matchingToken.getUsedAt());
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Token invalide ou déjà utilisé");
        }

        if (matchingToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            log.warn("reset-password: token expired at {}", matchingToken.getExpiresAt());
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Token expiré. Veuillez refaire une demande");
        }

        User user = matchingToken.getUser();
        log.info("reset-password: updating password for userId={}", user.getId());

        tokenRepository.deleteByUser(user);
        log.debug("reset-password: tokens invalidated for userId={}", user.getId());

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        log.info("reset-password: SUCCESS for user={}", user.getEmail());
    }

    private boolean isRateLimited(String ip) {
        long now = System.currentTimeMillis();
        long cutoff = now - RATE_LIMIT_WINDOW_MS;

        List<Long> timestamps = rateLimitMap.computeIfAbsent(ip,
                k -> Collections.synchronizedList(new ArrayList<>()));

        synchronized (timestamps) {
            timestamps.removeIf(t -> t < cutoff);
            if (timestamps.size() >= RATE_LIMIT_MAX) {
                return true;
            }
            timestamps.add(now);
            return false;
        }
    }

    private Map<String, Object> genericSuccess() {
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("message", "Si cet email existe, un lien de réinitialisation a été envoyé");
        return response;
    }
}
