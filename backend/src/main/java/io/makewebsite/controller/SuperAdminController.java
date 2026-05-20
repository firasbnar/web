package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.SuperAdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/super-admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('SUPER_ADMIN')")
public class SuperAdminController {

    private final SuperAdminService superAdminService;

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getDashboard() {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getDashboard()));
    }

    @GetMapping("/stores")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStores(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getStores(pageable)));
    }

    @GetMapping("/stores/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStoreDetail(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getStoreDetail(id)));
    }

    @PutMapping("/stores/{id}/freeze")
    public ResponseEntity<ApiResponse<Map<String, Object>>> freezeStore(
            @PathVariable UUID id,
            @RequestBody(required = false) Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal admin) {
        String reason = body != null ? body.get("reason") : null;
        return ResponseEntity.ok(ApiResponse.ok("Boutique gelée",
                superAdminService.freezeStore(id, reason, admin.getUserId(), admin.getEmail())));
    }

    @PutMapping("/stores/{id}/unfreeze")
    public ResponseEntity<ApiResponse<Map<String, Object>>> unfreezeStore(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal admin) {
        return ResponseEntity.ok(ApiResponse.ok("Boutique dégelée",
                superAdminService.unfreezeStore(id, admin.getUserId(), admin.getEmail())));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getUsers(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getUsers(pageable)));
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getUserDetail(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getUserDetail(id)));
    }

    @PutMapping("/users/{id}/role")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateUserRole(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal admin) {
        return ResponseEntity.ok(ApiResponse.ok("Rôle mis à jour",
                superAdminService.updateUserRole(id, body.get("role"), admin.getUserId(), admin.getEmail())));
    }

    @PutMapping("/users/{id}/verify-email")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyEmail(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal admin) {
        return ResponseEntity.ok(ApiResponse.ok("Email vérifié",
                superAdminService.verifyUserEmail(id, admin.getUserId(), admin.getEmail())));
    }

    @PutMapping("/users/{id}/suspend")
    public ResponseEntity<ApiResponse<Map<String, Object>>> suspendUser(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal admin) {
        String reason = body.get("reason");
        return ResponseEntity.ok(ApiResponse.ok("Utilisateur suspendu",
                superAdminService.suspendUser(id, reason, admin.getUserId(), admin.getEmail())));
    }

    @PutMapping("/users/{id}/activate")
    public ResponseEntity<ApiResponse<Map<String, Object>>> activateUser(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal admin) {
        return ResponseEntity.ok(ApiResponse.ok("Utilisateur activé",
                superAdminService.activateUser(id, admin.getUserId(), admin.getEmail())));
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal admin) {
        superAdminService.deleteUser(id, admin.getUserId(), admin.getEmail());
        return ResponseEntity.ok(ApiResponse.ok("Utilisateur supprimé", null));
    }

    @DeleteMapping("/stores/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteStore(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal admin) {
        superAdminService.deleteStore(id, admin.getUserId(), admin.getEmail());
        return ResponseEntity.ok(ApiResponse.ok("Boutique supprimée", null));
    }

    @GetMapping("/subscriptions")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSubscriptions(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getSubscriptions(pageable)));
    }

    @PutMapping("/subscriptions/{id}/override")
    public ResponseEntity<ApiResponse<Map<String, Object>>> overrideSubscription(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal admin) {
        String newStatus = body.get("status");
        return ResponseEntity.ok(ApiResponse.ok("Statut mis à jour",
                superAdminService.overrideSubscriptionStatus(id, newStatus, admin.getUserId(), admin.getEmail())));
    }

    @GetMapping("/audit-logs")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getAuditLogs(Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(superAdminService.getAuditLogs(pageable)));
    }

    @GetMapping("/stores/export")
    public ResponseEntity<String> exportStoresCsv() {
        String csv = superAdminService.exportStoresCsv();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("boutiques.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
    }

    @GetMapping("/users/export")
    public ResponseEntity<String> exportUsersCsv() {
        String csv = superAdminService.exportUsersCsv();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("utilisateurs.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
    }

    @GetMapping("/subscriptions/export")
    public ResponseEntity<String> exportSubscriptionsCsv() {
        String csv = superAdminService.exportSubscriptionsCsv();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("abonnements.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
    }

    @GetMapping("/audit-logs/export")
    public ResponseEntity<String> exportAuditLogsCsv() {
        String csv = superAdminService.exportAuditLogsCsv();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("audit_logs.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
    }
}
