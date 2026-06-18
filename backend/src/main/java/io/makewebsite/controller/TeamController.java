package io.makewebsite.controller;

import io.makewebsite.dto.request.InviteTeamMemberRequest;
import io.makewebsite.dto.request.UpdateRoleRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.BoutiqueResponse;
import io.makewebsite.dto.response.TeamMemberResponse;
import io.makewebsite.dto.response.TeamStatsResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.BoutiqueService;
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
    private final BoutiqueService boutiqueService;

    @GetMapping("/my-boutiques")
    public ResponseEntity<ApiResponse<List<BoutiqueResponse>>> getMyTeamBoutiques(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(boutiqueService.getMyBoutiques(principal.getUserId())));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<TeamMemberResponse>>> getTeamMembers(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(teamService.getTeamMembers(boutiqueId, principal.getUserId())));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<List<TeamMemberResponse>>> searchMembers(
            @RequestParam UUID boutiqueId,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) String role,
            @RequestParam(required = false) String status,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(
                teamService.searchMembers(boutiqueId, query, role, status, principal.getUserId())));
    }

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<TeamStatsResponse>> getTeamStats(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(teamService.getTeamStats(boutiqueId, principal.getUserId())));
    }

    @PostMapping("/invite")
    public ResponseEntity<ApiResponse<TeamMemberResponse>> inviteMember(
            @Valid @RequestBody InviteTeamMemberRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Invitation envoyee", teamService.inviteMember(request, principal.getUserId())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> removeMember(
            @PathVariable UUID id,
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        teamService.removeMember(id, boutiqueId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Membre retire", null));
    }

    @PutMapping("/{id}/role")
    public ResponseEntity<ApiResponse<TeamMemberResponse>> updateMemberRole(
            @PathVariable UUID id,
            @RequestParam UUID boutiqueId,
            @Valid @RequestBody UpdateRoleRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Role mis a jour",
                teamService.updateMemberRole(id, request, boutiqueId, principal.getUserId())));
    }

    @PutMapping("/{id}/toggle-status")
    public ResponseEntity<ApiResponse<TeamMemberResponse>> toggleMemberStatus(
            @PathVariable UUID id,
            @RequestParam UUID boutiqueId,
            @RequestParam boolean activate,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(
                activate ? "Membre active" : "Membre desactive",
                teamService.toggleMemberStatus(id, boutiqueId, activate, principal.getUserId())));
    }
}
