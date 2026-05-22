package io.makewebsite.controller;

import io.makewebsite.dto.request.ChangePasswordRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.UserResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserResponse>> getProfile(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(userService.getProfile(principal.getUserId())));
    }

    @PostMapping(value = "/me/profile-picture", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadProfilePicture(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        String url = userService.updateProfilePicture(principal.getUserId(), file);
        return ResponseEntity.ok(ApiResponse.ok("Photo de profil mise à jour", Map.of("profilePictureUrl", url)));
    }

    @PutMapping("/me/password")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        userService.changePassword(principal.getUserId(), request);
        return ResponseEntity.ok(ApiResponse.ok("Mot de passe changé avec succès", null));
    }

    @PutMapping("/active-boutique")
    public ResponseEntity<ApiResponse<Void>> setActiveBoutique(
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        UUID boutiqueId = UUID.fromString(body.get("boutiqueId"));
        userService.setActiveBoutique(principal.getUserId(), boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok("Boutique active changée", null));
    }
}
