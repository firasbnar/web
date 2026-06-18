package io.makewebsite.controller;

import io.makewebsite.dto.response.*;
import io.makewebsite.security.Permission;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.AnalyticsService;
import io.makewebsite.service.BoutiquePermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/analytics")
@RequiredArgsConstructor
public class AnalyticsController {
    private final AnalyticsService analyticsService;
    private final BoutiquePermissionService boutiquePermissionService;

    @GetMapping("/overview")
    public ResponseEntity<ApiResponse<AnalyticsOverviewResponse>> getOverview(
            @RequestParam UUID boutiqueId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @AuthenticationPrincipal UserPrincipal principal) {
        boutiquePermissionService.requireBoutiquePermission(principal.getUserId(), boutiqueId, Permission.ANALYTICS_READ);
        return ResponseEntity.ok(ApiResponse.ok(analyticsService.getOverview(boutiqueId, from, to)));
    }

    @GetMapping("/revenue-chart")
    public ResponseEntity<ApiResponse<RevenueChartResponse>> getRevenueChart(
            @RequestParam UUID boutiqueId,
            @RequestParam(defaultValue = "daily") String period,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @AuthenticationPrincipal UserPrincipal principal) {
        boutiquePermissionService.requireBoutiquePermission(principal.getUserId(), boutiqueId, Permission.ANALYTICS_READ);
        return ResponseEntity.ok(ApiResponse.ok(analyticsService.getRevenueChart(boutiqueId, period, from, to)));
    }

    @GetMapping("/top-products")
    public ResponseEntity<ApiResponse<List<TopProductResponse>>> getTopProducts(
            @RequestParam UUID boutiqueId,
            @RequestParam(defaultValue = "5") int limit,
            @AuthenticationPrincipal UserPrincipal principal) {
        boutiquePermissionService.requireBoutiquePermission(principal.getUserId(), boutiqueId, Permission.ANALYTICS_READ);
        return ResponseEntity.ok(ApiResponse.ok(analyticsService.getTopProducts(boutiqueId, limit)));
    }

    @GetMapping("/orders-by-status")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getOrdersByStatus(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        boutiquePermissionService.requireBoutiquePermission(principal.getUserId(), boutiqueId, Permission.ANALYTICS_READ);
        return ResponseEntity.ok(ApiResponse.ok(analyticsService.getOrdersByStatus(boutiqueId)));
    }

    @GetMapping("/traffic-sources")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getTrafficSources(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        boutiquePermissionService.requireBoutiquePermission(principal.getUserId(), boutiqueId, Permission.ANALYTICS_READ);
        return ResponseEntity.ok(ApiResponse.ok(analyticsService.getTrafficSources(boutiqueId)));
    }
}
