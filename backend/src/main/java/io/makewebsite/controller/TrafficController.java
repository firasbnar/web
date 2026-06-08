package io.makewebsite.controller;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.dto.response.*;
import io.makewebsite.service.TrafficService;
import io.makewebsite.util.NetworkUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/traffic")
@RequiredArgsConstructor
public class TrafficController {

    private final TrafficService trafficService;

    @GetMapping("/{boutiqueId}/stats")
    public ResponseEntity<ApiResponse<TrafficStatsResponse>> getStats(
            @PathVariable UUID boutiqueId) {
        TrafficStatsResponse stats = trafficService.getStats(boutiqueId);
        log.info("Traffic stats for {}: total={}, today={}, week={}, month={}",
                boutiqueId, stats.getTotalVisits(), stats.getTodayVisits(),
                stats.getWeekVisits(), stats.getMonthVisits());
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }

    @GetMapping("/{boutiqueId}/overview")
    public ResponseEntity<ApiResponse<TrafficOverviewResponse>> getOverview(
            @PathVariable UUID boutiqueId) {
        TrafficOverviewResponse overview = trafficService.getOverview(boutiqueId);
        log.info("Overview for storeId={}: topCountries={}, topCities={}",
                boutiqueId,
                overview.getTopCountries() != null ? overview.getTopCountries().size() : 0,
                overview.getTopCities() != null ? overview.getTopCities().size() : 0);
        return ResponseEntity.ok(ApiResponse.ok(overview));
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
            @Valid @RequestBody TrackVisitRequest request,
            HttpServletRequest httpRequest) {
        // Resolve real client IP from headers and set on request DTO
        String clientIp = NetworkUtils.resolveClientIp(httpRequest);
        request.setIpAddress(clientIp);
        log.info("Track visit: boutiqueId={}, slug={}, page={}, ip={}, sessionId={}",
                request.getBoutiqueId(), request.getBoutiqueSlug(),
                request.getPage(), clientIp, request.getSessionId());
        return ResponseEntity.ok(ApiResponse.ok(
                "Visite enregistrée", trafficService.trackVisit(request)));
    }

    @GetMapping("/{boutiqueId}/recent")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getRecentVisits(
            @PathVariable UUID boutiqueId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Map<String, Object> data = trafficService.getRecentVisits(boutiqueId, page, size);
        List<?> content = (List<?>) data.getOrDefault("content", List.of());
        log.info("Recent visits for {}: {} items on page {} of {}",
                boutiqueId, content.size(), page, data.getOrDefault("totalPages", 0));
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    @GetMapping("/{boutiqueId}/map")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getMapData(
            @PathVariable UUID boutiqueId) {
        List<Map<String, Object>> data = trafficService.getMapData(boutiqueId);
        log.info("Map data for {}: {} geo points", boutiqueId, data.size());
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    @GetMapping("/{boutiqueId}/export")
    public ResponseEntity<String> exportCsv(@PathVariable UUID boutiqueId) {
        String csv = trafficService.exportCsv(boutiqueId);
        log.info("CSV export for {}: {} bytes", boutiqueId, csv.length());
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("traffic_export.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
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
