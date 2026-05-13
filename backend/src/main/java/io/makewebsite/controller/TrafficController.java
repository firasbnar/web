package io.makewebsite.controller;

import io.makewebsite.dto.response.*;
import io.makewebsite.service.TrafficService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/traffic")
@RequiredArgsConstructor
public class TrafficController {

    private final TrafficService trafficService;

    @GetMapping("/{boutiqueId}/stats")
    public ResponseEntity<ApiResponse<TrafficStatsResponse>> getStats(
            @PathVariable UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getStats(boutiqueId)));
    }

    @GetMapping("/{boutiqueId}/overview")
    public ResponseEntity<ApiResponse<TrafficOverviewResponse>> getOverview(
            @PathVariable UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getOverview(boutiqueId)));
    }

    @GetMapping("/{boutiqueId}/visitors")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getVisitors(
            @PathVariable UUID boutiqueId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getVisitorsPage(boutiqueId, page, size)));
    }

    @GetMapping("/{boutiqueId}/timeline")
    public ResponseEntity<ApiResponse<List<VisitorTimelineResponse>>> getTimeline(
            @PathVariable UUID boutiqueId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "daily") String period) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getTimeline(boutiqueId, from, to, period)));
    }

    @GetMapping("/{boutiqueId}/visitors/active")
    public ResponseEntity<ApiResponse<Long>> getActiveVisitorCount(
            @PathVariable UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(
                trafficService.getStats(boutiqueId).getActiveVisitors()));
    }

    @GetMapping("/{boutiqueId}/visitors/authenticated")
    public ResponseEntity<ApiResponse<Long>> getAuthenticatedVisitorCount(
            @PathVariable UUID boutiqueId) {
        TrafficStatsResponse stats = trafficService.getStats(boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok(stats.getAuthenticatedVisitors()));
    }

    @GetMapping("/{boutiqueId}/visitors/anonymous")
    public ResponseEntity<ApiResponse<Long>> getAnonymousVisitorCount(
            @PathVariable UUID boutiqueId) {
        TrafficStatsResponse stats = trafficService.getStats(boutiqueId);
        return ResponseEntity.ok(ApiResponse.ok(stats.getAnonymousVisitors()));
    }
}