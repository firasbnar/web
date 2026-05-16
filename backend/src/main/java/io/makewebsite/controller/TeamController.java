package io.makewebsite.controller;

import io.makewebsite.dto.request.InviteTeamMemberRequest;
import io.makewebsite.dto.request.UpdateRoleRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.TeamMemberResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.TeamService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/team")
@RequiredArgsConstructor
public class TeamController {
    private final TeamService teamService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<TeamMemberResponse>>> getTeamMembers(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(teamService.getTeamMembers(boutiqueId, principal.getUserId())));
    }

    @PostMapping("/invite")
    public ResponseEntity<ApiResponse<TeamMemberResponse>> inviteMember(
            @Valid @RequestBody InviteTeamMemberRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Invitation envoyée", teamService.inviteMember(request, principal.getUserId())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> removeMember(
            @PathVariable UUID id,
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        teamService.removeMember(id, boutiqueId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Membre retiré", null));
    }

    @PutMapping("/{id}/role")
    public ResponseEntity<ApiResponse<TeamMemberResponse>> updateMemberRole(
            @PathVariable UUID id,
            @RequestParam UUID boutiqueId,
            @Valid @RequestBody UpdateRoleRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Rôle mis à jour",
                teamService.updateMemberRole(id, request, boutiqueId, principal.getUserId())));
    }
}
