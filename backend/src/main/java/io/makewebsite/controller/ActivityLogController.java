package io.makewebsite.controller;

import io.makewebsite.dto.response.ActivityLogResponse;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.service.ActivityLogService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/activities")
@RequiredArgsConstructor
public class ActivityLogController {

    private final ActivityLogService activityLogService;

    @GetMapping
    public ResponseEntity<ApiResponse<Page<ActivityLogResponse>>> getActivities(
            @RequestParam(required = false) UUID boutiqueId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            Pageable pageable) {
        Page<ActivityLogResponse> activities = activityLogService.getActivities(
                boutiqueId, search, action, status, startDate, endDate, pageable);
        return ResponseEntity.ok(ApiResponse.ok(activities));
    }

    @GetMapping("/export")
    public ResponseEntity<String> exportCsv(
            @RequestParam(required = false) UUID boutiqueId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {
        String csv = activityLogService.exportCsv(
                boutiqueId, search, action, status, startDate, endDate);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=activites.csv")
                .contentType(MediaType.TEXT_PLAIN)
                .body(csv);
    }

    @GetMapping("/presence")
    public ResponseEntity<ApiResponse<Long>> getPresence() {
        long recent = activityLogService.countRecentByStatus("SUCCESS", 5);
        return ResponseEntity.ok(ApiResponse.ok(recent));
    }
}
