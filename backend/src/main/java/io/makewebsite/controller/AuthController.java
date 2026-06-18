package io.makewebsite.controller;

import io.makewebsite.dto.*;
import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.AuthService;
import io.makewebsite.service.PasswordResetService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
public class AuthController {
    private final AuthService authService;
    private final PasswordResetService passwordResetService;

    @Value("${app.frontend-url}")
    private String frontendUrl;

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthResponse>> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Inscription réussie. Vérifiez votre email.", authService.register(request)));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request,
                                                            HttpServletRequest httpRequest) {
        String ip = extractIp(httpRequest);
        String device = httpRequest.getHeader("User-Agent");
        return ResponseEntity.ok(ApiResponse.ok("Connexion réussie", authService.login(request, ip, device)));
    }

    @GetMapping({"/verify", "/verify-email"})
    public ResponseEntity<ApiResponse<String>> verifyEmail(@RequestParam String token) {
        authService.verifyEmail(token);
        return ResponseEntity.ok(ApiResponse.ok("Email vérifié avec succès. Vous pouvez maintenant vous connecter."));
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<ApiResponse<String>> resendVerification(@RequestBody Map<String, String> body) {
        authService.resendVerification(body.get("email"));
        return ResponseEntity.ok(ApiResponse.ok("Email de vérification renvoyé. Vérifiez votre boîte de réception."));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(authService.refresh(request)));
    }

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<UserResponse>> getProfile(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(authService.getProfile(principal.getUserId())));
    }

    @PutMapping("/profile")
    public ResponseEntity<ApiResponse<UserResponse>> updateProfile(@AuthenticationPrincipal UserPrincipal principal, @Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Profil mis à jour", authService.updateProfile(principal.getUserId(), request)));
    }

    @PutMapping("/change-password")
    public ResponseEntity<ApiResponse<Void>> changePassword(@AuthenticationPrincipal UserPrincipal principal, @Valid @RequestBody ChangePasswordRequest request) {
        authService.changePassword(principal.getUserId(), request);
        return ResponseEntity.ok(ApiResponse.ok("Mot de passe modifié", null));
    }

    @PostMapping("/google")
    public ResponseEntity<ApiResponse<AuthResponse>> googleLogin(@Valid @RequestBody GoogleLoginRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(authService.loginWithGoogle(request.getIdToken())));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshTokenRequest request,
                                                     HttpServletRequest httpRequest) {
        String ip = extractIp(httpRequest);
        String device = httpRequest.getHeader("User-Agent");
        authService.logout(request, ip, device);
        return ResponseEntity.ok(ApiResponse.ok("Déconnexion réussie", null));
    }

    private String extractIp(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }
        return ip;
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<Map<String, Object>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request,
            HttpServletRequest httpRequest) {
        log.info("forgot-password request for email: {}", request.getEmail());
        Map<String, Object> result = passwordResetService.forgotPassword(request.getEmail(), httpRequest);
        return ResponseEntity.ok(result);
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Map<String, Object>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {
        log.info("reset-password request received (token length: {})", request.getToken().length());
        passwordResetService.resetPassword(request);
        log.info("reset-password successful");
        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Mot de passe réinitialisé avec succès"
        ));
    }

    @GetMapping("/reset-password/redirect")
    public void redirectResetPassword(@RequestParam String token, HttpServletResponse response) throws IOException {
        log.info("reset-password redirect for token length={}", token.length());
        String encodedToken = URLEncoder.encode(token, StandardCharsets.UTF_8);
        String redirectUrl = frontendUrl + "/reset-password?token=" + encodedToken;
        log.info("reset-password redirecting to {}", redirectUrl);
        response.sendRedirect(redirectUrl);
    }
}
