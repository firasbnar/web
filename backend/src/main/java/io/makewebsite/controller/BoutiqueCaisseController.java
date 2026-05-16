package io.makewebsite.controller;

import io.makewebsite.dto.response.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.CaisseService;
import io.makewebsite.service.WebSocketService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/boutiques/{boutiqueId}/caisse")
@RequiredArgsConstructor
public class BoutiqueCaisseController {
    private final CaisseService caisseService;
    private final WebSocketService webSocketService;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<CaisseDashboardResponse>> getDashboard(@PathVariable UUID boutiqueId) {
        CaisseDashboardResponse stats = caisseService.getDashboard(boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }

    @GetMapping("/cashiers")
    public ResponseEntity<ApiResponse<Page<CashierResponse>>> getCashiers(
            @PathVariable UUID boutiqueId,
            @RequestParam(required = false) String search,
            Pageable pageable) {
        Page<CashierResponse> cashiers = caisseService.getCashiers(boutiqueId, search, pageable);
        return ResponseEntity.ok(ApiResponse.ok(cashiers));
    }

    @GetMapping("/cashiers/stats")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getCashierStats(@PathVariable UUID boutiqueId) {
        Map<String, Object> stats = caisseService.getCashierStats(boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }

    @PostMapping("/cashiers")
    public ResponseEntity<ApiResponse<CashierResponse>> createCashier(
            @PathVariable UUID boutiqueId,
            @RequestBody Map<String, String> body) {
        CashierResponse cashier = caisseService.createCashier(
                boutiqueId, body.get("email"), body.get("fullName"), body.get("role"));
        return ResponseEntity.ok(ApiResponse.ok("Caissier ajouté", cashier));
    }

    @DeleteMapping("/cashiers/{cashierId}")
    public ResponseEntity<ApiResponse<String>> deleteCashier(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID cashierId) {
        caisseService.deleteCashier(boutiqueId, cashierId);
        return ResponseEntity.ok(ApiResponse.ok("Caissier supprimé"));
    }

    @PutMapping("/cashiers/{cashierId}/suspend")
    public ResponseEntity<ApiResponse<CashierResponse>> suspendCashier(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID cashierId) {
        CashierResponse cashier = caisseService.toggleCashierStatus(boutiqueId, cashierId, true);
        return ResponseEntity.ok(ApiResponse.ok("Caissier suspendu", cashier));
    }

    @PutMapping("/cashiers/{cashierId}/activate")
    public ResponseEntity<ApiResponse<CashierResponse>> activateCashier(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID cashierId) {
        CashierResponse cashier = caisseService.toggleCashierStatus(boutiqueId, cashierId, false);
        return ResponseEntity.ok(ApiResponse.ok("Caissier activé", cashier));
    }

    @GetMapping("/users/search")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> searchUsers(
            @PathVariable UUID boutiqueId,
            @RequestParam(required = false) String query) {
        List<Map<String, Object>> users = caisseService.searchUsers(boutiqueId, query);
        return ResponseEntity.ok(ApiResponse.ok(users));
    }

    @GetMapping("/orders")
    public ResponseEntity<ApiResponse<Page<OrderResponse>>> getOrders(
            @PathVariable UUID boutiqueId,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            @RequestParam(required = false) UUID userId,
            Pageable pageable) {
        Page<OrderResponse> orders = caisseService.getCaisseOrders(boutiqueId, status, startDate, endDate, userId, pageable);
        return ResponseEntity.ok(ApiResponse.ok(orders));
    }

    @GetMapping("/activities")
    public ResponseEntity<ApiResponse<Page<ActivityLogResponse>>> getActivities(
            @PathVariable UUID boutiqueId,
            @RequestParam(required = false) String action,
            Pageable pageable) {
        Page<ActivityLogResponse> activities = caisseService.getActivities(boutiqueId, action, pageable);
        return ResponseEntity.ok(ApiResponse.ok(activities));
    }
}
