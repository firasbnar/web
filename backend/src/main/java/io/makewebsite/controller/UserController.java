package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;

    @PutMapping("/active-boutique")
    public ResponseEntity<ApiResponse<Void>> setActiveBoutique(
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        UUID boutiqueId = UUID.fromString(body.get("boutiqueId"));
        userService.setActiveBoutique(principal.getUserId(), boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok("Boutique active changée", null));
    }
}
