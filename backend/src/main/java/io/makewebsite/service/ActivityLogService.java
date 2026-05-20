package io.makewebsite.service;

import io.makewebsite.dto.response.ActivityLogResponse;
import io.makewebsite.entity.ActivityLog;
import io.makewebsite.repository.ActivityLogRepository;
import io.makewebsite.util.CsvUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    private final ActivityLogRepository activityLogRepository;
    private final WebSocketService webSocketService;

    @Transactional
    public ActivityLogResponse record(UUID boutiqueId, UUID userId, String userName,
                                       String action, String status, String details,
                                       String ipAddress, String deviceInfo) {
        ActivityLog log = ActivityLog.builder()
                .boutiqueId(boutiqueId)
                .userId(userId)
                .userName(userName)
                .action(action)
                .status(status != null ? status : "SUCCESS")
                .ipAddress(ipAddress)
                .deviceInfo(deviceInfo)
                .details(details)
                .build();
        log = activityLogRepository.save(log);
        ActivityLogResponse response = mapToResponse(log);
        try {
            webSocketService.sendActivityEvent(response);
        } catch (Exception e) {
            // non-blocking
        }
        return response;
    }

    @Transactional
    public ActivityLogResponse recordWithSession(UUID boutiqueId, UUID userId, String userName,
                                                  String action, String status, String details,
                                                  String ipAddress, String deviceInfo, UUID sessionId) {
        ActivityLog log = ActivityLog.builder()
                .boutiqueId(boutiqueId)
                .userId(userId)
                .userName(userName)
                .action(action)
                .status(status != null ? status : "SUCCESS")
                .ipAddress(ipAddress)
                .deviceInfo(deviceInfo)
                .sessionId(sessionId)
                .details(details)
                .build();
        log = activityLogRepository.save(log);
        ActivityLogResponse response = mapToResponse(log);
        try {
            webSocketService.sendActivityEvent(response);
        } catch (Exception e) {
            // non-blocking
        }
        return response;
    }

    @Transactional(readOnly = true)
    public Page<ActivityLogResponse> getActivities(UUID boutiqueId, String search, String action,
                                                    String status, String startDate, String endDate,
                                                    Pageable pageable) {
        LocalDateTime from = null, to = null;
        if (startDate != null && !startDate.isEmpty()) {
            from = LocalDate.parse(startDate).atStartOfDay();
        }
        if (endDate != null && !endDate.isEmpty()) {
            to = LocalDate.parse(endDate).atTime(LocalTime.MAX);
        }
        if (boutiqueId != null) {
            return activityLogRepository.searchFiltered(
                    boutiqueId, search, action, status, from, to, pageable)
                    .map(this::mapToResponse);
        }
        return activityLogRepository.adminSearchFiltered(
                search, action, status, from, to, pageable)
                .map(this::mapToResponse);
    }

    @Transactional(readOnly = true)
    public long countRecentByStatus(String status, int minutes) {
        return activityLogRepository.countByStatusAndCreatedAtAfter(
                status, LocalDateTime.now().minusMinutes(minutes));
    }

    @Transactional(readOnly = true)
    public long countRecentByStatusAndBoutique(UUID boutiqueId, String status, int minutes) {
        return activityLogRepository.countByBoutiqueIdAndStatusAndCreatedAtAfter(
                boutiqueId, status, LocalDateTime.now().minusMinutes(minutes));
    }

    @Transactional(readOnly = true)
    public String exportCsv(UUID boutiqueId, String search, String action,
                             String status, String startDate, String endDate) {
        Page<ActivityLogResponse> page = getActivities(boutiqueId, search, action, status, startDate, endDate, Pageable.unpaged());
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("Utilisateur,Action,Statut,IP,Appareil,Détails,Date\n");
        for (ActivityLogResponse a : page.getContent()) {
            sb.append(CsvUtil.escapeCsv(a.getUserName())).append(",")
              .append(CsvUtil.escapeCsv(a.getAction())).append(",")
              .append(CsvUtil.escapeCsv(a.getStatus())).append(",")
              .append(CsvUtil.escapeCsv(a.getIpAddress())).append(",")
              .append(CsvUtil.escapeCsv(a.getDeviceInfo())).append(",")
              .append(CsvUtil.escapeCsv(a.getDetails())).append(",")
              .append(a.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    public ActivityLogResponse mapToResponse(ActivityLog log) {
        return ActivityLogResponse.builder()
                .id(log.getId())
                .boutiqueId(log.getBoutiqueId())
                .userId(log.getUserId())
                .userName(log.getUserName())
                .action(log.getAction())
                .status(log.getStatus())
                .ipAddress(log.getIpAddress())
                .deviceInfo(log.getDeviceInfo())
                .sessionId(log.getSessionId())
                .details(log.getDetails())
                .metadata(log.getMetadata())
                .createdAt(log.getCreatedAt())
                .build();
    }
}
