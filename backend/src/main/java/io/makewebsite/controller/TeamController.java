package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/team")
@RequiredArgsConstructor
public class TeamController {

    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTeamMembers(@RequestParam UUID boutiqueId) {
        // Placeholder - in production, query team_members table
        return ResponseEntity.ok(ApiResponse.ok(List.of()));
    }

    @PostMapping("/invite")
    public ResponseEntity<ApiResponse<Map<String, Object>>> inviteMember(@RequestBody Map<String, Object> body) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", UUID.randomUUID());
        result.put("email", body.get("email"));
        result.put("role", body.get("role"));
        result.put("status", "PENDING");
        result.put("invitedAt", LocalDateTime.now());
        return ResponseEntity.ok(ApiResponse.ok("Invitation envoyée", result));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> removeMember(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok("Membre retiré", null));
    }

    @PutMapping("/{id}/role")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateMemberRole(@PathVariable UUID id, @RequestBody Map<String, String> body) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", id);
        result.put("role", body.get("role"));
        return ResponseEntity.ok(ApiResponse.ok("Rôle mis à jour", result));
    }
}
