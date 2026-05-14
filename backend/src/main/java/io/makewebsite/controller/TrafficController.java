package io.makewebsite.controller;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.dto.response.*;
import io.makewebsite.service.TrafficService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
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

    @PostMapping("/track")
    public ResponseEntity<ApiResponse<Map<String, Object>>> trackVisit(
            @Valid @RequestBody TrackVisitRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(
                "Visite enregistrée", trafficService.trackVisit(request)));
    }

    @GetMapping("/{boutiqueId}/recent")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getRecentVisits(
            @PathVariable UUID boutiqueId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(ApiResponse.ok(
                trafficService.getRecentVisits(boutiqueId, page, size)));
    }

    @GetMapping("/{boutiqueId}/map")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getMapData(
            @PathVariable UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getMapData(boutiqueId)));
    }

    @GetMapping("/{boutiqueId}/export")
    public ResponseEntity<byte[]> exportCsv(@PathVariable UUID boutiqueId) {
        String csv = trafficService.exportCsv(boutiqueId);
        byte[] bytes = csv.getBytes();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_OCTET_STREAM);
        headers.setContentDispositionFormData("attachment", "traffic_export.csv");
        return ResponseEntity.ok().headers(headers).body(bytes);
    }

    @GetMapping("/{boutiqueId}/live")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getLiveStats(
            @PathVariable UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getLiveStats(boutiqueId)));
    }

    @GetMapping("/{boutiqueId}/sessions")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSessions(
            @PathVariable UUID boutiqueId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(ApiResponse.ok(trafficService.getSessions(boutiqueId, page, size)));
    }
}
