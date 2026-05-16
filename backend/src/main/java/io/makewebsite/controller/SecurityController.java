package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.SessionResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.SecurityService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/security")
@RequiredArgsConstructor
public class SecurityController {
    private final SecurityService securityService;

    @GetMapping("/sessions")
    public ResponseEntity<ApiResponse<List<SessionResponse>>> getSessions(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(securityService.getActiveSessions(principal.getUserId())));
    }

    @DeleteMapping("/sessions/{sessionId}")
    public ResponseEntity<ApiResponse<Void>> revokeSession(
            @PathVariable UUID sessionId,
            @AuthenticationPrincipal UserPrincipal principal) {
        securityService.revokeSession(sessionId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Session révoquée", null));
    }

    @PostMapping("/sessions/revoke-others")
    public ResponseEntity<ApiResponse<Void>> revokeOtherSessions(
            @AuthenticationPrincipal UserPrincipal principal) {
        String currentToken = principal.getTokenHash();
        securityService.revokeOtherSessions(principal.getUserId(), currentToken);
        return ResponseEntity.ok(ApiResponse.ok("Autres sessions déconnectées", null));
    }

    @DeleteMapping("/account")
    public ResponseEntity<ApiResponse<Void>> deleteAccount(
            @AuthenticationPrincipal UserPrincipal principal) {
        securityService.deleteAccount(principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Compte supprimé", null));
    }
}
