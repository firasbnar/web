package io.makewebsite.service;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.StoreView;
import io.makewebsite.entity.TrafficSession;
import io.makewebsite.entity.Visitor;
import io.makewebsite.repository.StoreViewRepository;
import io.makewebsite.repository.TrafficRepository;
import io.makewebsite.repository.TrafficSessionRepository;
import io.makewebsite.service.GeoLocationService.GeoData;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class TrafficService {

    private final TrafficRepository trafficRepository;
    private final StoreViewRepository storeViewRepository;
    private final TrafficSessionRepository sessionRepository;
    private final GeoLocationService geoLocationService;
    private final WebSocketService webSocketService;

    @PersistenceContext
    private EntityManager entityManager;

    public TrafficStatsResponse getStats(UUID boutiqueId) {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime todayEnd = LocalDate.now().atTime(LocalTime.MAX);
        LocalDateTime weekStart = LocalDateTime.now().minusDays(7);
        LocalDateTime monthStart = LocalDateTime.now().minusDays(30);

        return TrafficStatsResponse.builder()
                .totalVisits(sessionRepository.countByBoutiqueId(boutiqueId))
                .uniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueId(boutiqueId))
                .todayVisits(sessionRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, todayEnd))
                .todayUniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueIdBetween(boutiqueId, todayStart, todayEnd))
                .weekVisits(sessionRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, weekStart, LocalDateTime.now()))
                .weekUniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueIdBetween(boutiqueId, weekStart, LocalDateTime.now()))
                .monthVisits(sessionRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, monthStart, LocalDateTime.now()))
                .monthUniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueIdBetween(boutiqueId, monthStart, LocalDateTime.now()))
                .activeVisitors((int) trafficRepository.countActiveVisitorsByBoutiqueId(boutiqueId))
                .authenticatedVisitors((int) trafficRepository.countByBoutiqueIdAndUserIdIsNotNull(boutiqueId))
                .anonymousVisitors((int) trafficRepository.countByBoutiqueIdAndUserIdIsNull(boutiqueId))
                .build();
    }

    public List<VisitorResponse> getVisitors(UUID boutiqueId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "lastActivityAt"));
        Page<Visitor> visitors = trafficRepository.findByBoutiqueId(boutiqueId, pageable);
        return visitors.stream().map(this::toVisitorResponse).collect(Collectors.toList());
    }

    public Map<String, Object> getVisitorsPage(UUID boutiqueId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "lastActivityAt"));
        Page<Visitor> visitorPage = trafficRepository.findByBoutiqueId(boutiqueId, pageable);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", visitorPage.getContent().stream().map(this::toVisitorResponse).collect(Collectors.toList()));
        result.put("totalElements", visitorPage.getTotalElements());
        result.put("totalPages", visitorPage.getTotalPages());
        result.put("currentPage", visitorPage.getNumber());
        return result;
    }

    public TrafficOverviewResponse getOverview(UUID boutiqueId) {
        List<GeoResponse> topCountries = trafficRepository.countByBoutiqueIdGroupByCountry(boutiqueId).stream()
                .map(r -> GeoResponse.builder()
                        .country((String) r[0])
                        .count((Long) r[1])
                        .build())
                .collect(Collectors.toList());

        List<GeoResponse> topCities = trafficRepository.countByBoutiqueIdGroupByCity(boutiqueId).stream()
                .map(r -> GeoResponse.builder()
                        .city((String) r[0])
                        .country((String) r[1])
                        .count((Long) r[2])
                        .build())
                .collect(Collectors.toList());

        List<DeviceBreakdownResponse> deviceBreakdown = trafficRepository.countByBoutiqueIdGroupByDeviceType(boutiqueId).stream()
                .map(r -> DeviceBreakdownResponse.builder()
                        .deviceType((String) r[0])
                        .count((Long) r[1])
                        .percentage(0.0)
                        .build())
                .collect(Collectors.toList());

        List<BrowserBreakdownResponse> browserBreakdown = trafficRepository.countByBoutiqueIdGroupByBrowser(boutiqueId).stream()
                .map(r -> BrowserBreakdownResponse.builder()
                        .browser((String) r[0])
                        .count((Long) r[1])
                        .percentage(0.0)
                        .build())
                .collect(Collectors.toList());

        List<ReferralSourceResponse> referralSources = trafficRepository.countByBoutiqueIdGroupByReferralSource(boutiqueId).stream()
                .map(r -> ReferralSourceResponse.builder()
                        .source((String) r[0])
                        .count((Long) r[1])
                        .percentage(0.0)
                        .build())
                .collect(Collectors.toList());

        long total = deviceBreakdown.stream().mapToLong(DeviceBreakdownResponse::getCount).sum();
        if (total > 0) {
            deviceBreakdown.forEach(d -> d.setPercentage(Math.round((double) d.getCount() / total * 1000.0) / 10.0));
        }

        long browserTotal = browserBreakdown.stream().mapToLong(BrowserBreakdownResponse::getCount).sum();
        if (browserTotal > 0) {
            browserBreakdown.forEach(b -> b.setPercentage(Math.round((double) b.getCount() / browserTotal * 1000.0) / 10.0));
        }

        long referralTotal = referralSources.stream().mapToLong(ReferralSourceResponse::getCount).sum();
        if (referralTotal > 0) {
            referralSources.forEach(r -> r.setPercentage(Math.round((double) r.getCount() / referralTotal * 1000.0) / 10.0));
        }

        return TrafficOverviewResponse.builder()
                .stats(getStats(boutiqueId))
                .topCountries(topCountries)
                .topCities(topCities)
                .deviceBreakdown(deviceBreakdown)
                .browserBreakdown(browserBreakdown)
                .referralSources(referralSources)
                .build();
    }

    public List<VisitorTimelineResponse> getTimeline(UUID boutiqueId, LocalDate from, LocalDate to, String period) {
        LocalDateTime fromDt = from.atStartOfDay();
        LocalDateTime toDt = to.atTime(LocalTime.MAX);
        List<TrafficSession> sessions = sessionRepository.findByBoutiqueIdAndCreatedAtBetween(boutiqueId, fromDt, toDt);

        Map<String, List<TrafficSession>> grouped;
        java.time.format.DateTimeFormatter fmt;
        if ("weekly".equals(period)) {
            fmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-'W'ww");
        } else if ("monthly".equals(period)) {
            fmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM");
        } else {
            fmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd");
        }

        grouped = sessions.stream().collect(Collectors.groupingBy(s ->
                s.getCreatedAt().format(fmt)));

        return grouped.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(e -> VisitorTimelineResponse.builder()
                        .date(e.getKey())
                        .visits((long) e.getValue().size())
                        .uniqueVisitors(e.getValue().stream().map(TrafficSession::getIpHash).distinct().count())
                        .build())
                .collect(Collectors.toList());
    }

    public Visitor findOrCreateVisitor(UUID boutiqueId, String ipHash, String userAgent,
                                       String country, String city, String region,
                                       Double latitude, Double longitude,
                                       String deviceType, String browser, String os,
                                       String platform, String referralSource,
                                       UUID userId, String userEmail, String userName) {

        Optional<Visitor> existing = trafficRepository.findByBoutiqueIdAndIpHash(boutiqueId, ipHash);

        if (existing.isPresent()) {
            Visitor v = existing.get();
            v.setTotalVisits(v.getTotalVisits() + 1);
            v.setLastActivityAt(LocalDateTime.now());
            v.setIsActive(true);
            v.setUserAgent(userAgent);
            v.setBrowser(browser);
            v.setOperatingSystem(os);
            v.setPlatform(platform);
            if (userId != null) {
                v.setUserId(userId);
                v.setUserEmail(userEmail);
                v.setUserName(userName);
            }
            return trafficRepository.save(v);
        }

        Visitor v = Visitor.builder()
                .boutiqueId(boutiqueId)
                .ipHash(ipHash)
                .country(country)
                .city(city)
                .region(region)
                .latitude(latitude)
                .longitude(longitude)
                .deviceType(deviceType)
                .browser(browser)
                .operatingSystem(os)
                .platform(platform)
                .userAgent(userAgent)
                .referralSource(referralSource)
                .totalVisits(1L)
                .userId(userId)
                .userEmail(userEmail)
                .userName(userName)
                .isActive(true)
                .build();
        return trafficRepository.save(v);
    }

    @Transactional
    public Map<String, Object> trackVisit(TrackVisitRequest req) {
        if (req.getBoutiqueId() == null) {
            log.warn("trackVisit called without boutiqueId, skipping");
            return Map.of("tracked", false, "error", "boutiqueId required");
        }

        String ipHash = req.getIpAddress() != null ? req.getIpAddress().hashCode() + "" : "unknown";
        GeoData geo = req.getIpAddress() != null
                ? geoLocationService.locate(req.getIpAddress()).orElse(null)
                : null;

        String country = geo != null ? geo.country() : null;
        String city = geo != null ? geo.city() : null;
        String region = geo != null ? geo.region() : null;
        Double latitude = geo != null ? geo.latitude() : null;
        Double longitude = geo != null ? geo.longitude() : null;

        // Create StoreView record
        StoreView view = StoreView.builder()
                .boutiqueId(req.getBoutiqueId())
                .ipHash(ipHash)
                .page(req.getPage())
                .referrer(req.getReferrer())
                .browser(req.getBrowser())
                .country(country)
                .city(city)
                .userAgent(req.getUserAgent())
                .viewedAt(LocalDateTime.now())
                .build();
        storeViewRepository.save(view);

        // Manage session-based visit tracking
        if (req.getSessionId() != null) {
            LocalDateTime cutoff = LocalDateTime.now().minusMinutes(30);
            TrafficSession existingSession = sessionRepository
                    .findByBoutiqueIdAndSessionIdAndLastActivityAtAfter(req.getBoutiqueId(), req.getSessionId(), cutoff)
                    .orElse(null);

            if (existingSession != null) {
                // Active session within 30 min — update page count, do NOT create new visit
                existingSession.setPagesViewed(existingSession.getPagesViewed() + 1);
                if (req.getUserId() != null) existingSession.setUserId(req.getUserId());
                sessionRepository.save(existingSession);
            } else {
                // New or expired session — this is a new visit
                TrafficSession session = TrafficSession.builder()
                        .boutiqueId(req.getBoutiqueId())
                        .sessionId(req.getSessionId())
                        .ipHash(ipHash)
                        .country(country)
                        .city(city)
                        .latitude(latitude)
                        .longitude(longitude)
                        .deviceType(req.getDeviceType())
                        .browser(req.getBrowser())
                        .operatingSystem(req.getOperatingSystem())
                        .language(req.getLanguage())
                        .timezone(req.getTimezone())
                        .appVersion(req.getAppVersion())
                        .deviceModel(req.getDeviceModel())
                        .referrer(req.getReferrer())
                        .pagesViewed(1)
                        .build();
                sessionRepository.save(session);

                // Only increment visitor count on a new session/visit
                findOrCreateVisitor(
                        req.getBoutiqueId(), ipHash, req.getUserAgent(),
                        country, city, region, latitude, longitude,
                        req.getDeviceType(), req.getBrowser(), req.getOperatingSystem(),
                        req.getPlatform(), req.getReferrer(),
                        req.getUserId(), req.getUserEmail(), req.getUserName()
                );
            }
        } else {
            // No sessionId — legacy fallback, track visitor anyway
            findOrCreateVisitor(
                    req.getBoutiqueId(), ipHash, req.getUserAgent(),
                    country, city, region, latitude, longitude,
                    req.getDeviceType(), req.getBrowser(), req.getOperatingSystem(),
                    req.getPlatform(), req.getReferrer(),
                    req.getUserId(), req.getUserEmail(), req.getUserName()
            );
        }

        // Send real-time WebSocket updates
        try {
            TrafficStatsResponse stats = getStats(req.getBoutiqueId());
            webSocketService.sendVisitorUpdate(req.getBoutiqueId(), stats);
            webSocketService.sendActiveVisitorCount(req.getBoutiqueId(), stats.getActiveVisitors());
        } catch (Exception e) {
            log.debug("WebSocket send failed: {}", e.getMessage());
        }

        return Map.of("tracked", true, "visitId", view.getId().toString());
    }

    public Map<String, Object> getLiveStats(UUID boutiqueId) {
        LocalDateTime fiveMinutesAgo = LocalDateTime.now().minusMinutes(5);
        List<TrafficSession> activeSessions = sessionRepository
                .findActiveSessionsSince(boutiqueId, fiveMinutesAgo);
        long liveVisitors = activeSessions.size();
        long todaySessions = sessionRepository.countByBoutiqueIdAndCreatedAtBetween(
                boutiqueId, LocalDate.now().atStartOfDay(), LocalDateTime.now());
        double avgDuration = sessionRepository.avgSessionDurationByBoutiqueId(boutiqueId);
        long bounceRate = sessionRepository.countByBoutiqueIdAndIsBounceTrue(boutiqueId);
        long totalSessions = sessionRepository.countByBoutiqueIdAndCreatedAtBetween(
                boutiqueId, LocalDateTime.now().minusDays(30), LocalDateTime.now());
        double bouncePct = totalSessions > 0 ? (double) bounceRate / totalSessions * 100 : 0;

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("liveVisitors", liveVisitors);
        result.put("todaySessions", todaySessions);
        result.put("avgSessionDurationSeconds", Math.round(avgDuration));
        result.put("bounceRate", Math.round(bouncePct));
        return result;
    }

    public Map<String, Object> getSessions(UUID boutiqueId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "lastActivityAt"));
        Page<TrafficSession> sessionPage = sessionRepository.findByBoutiqueIdOrderByLastActivityAtDesc(boutiqueId, pageable);
        List<Map<String, Object>> sessions = sessionPage.getContent().stream().map(s -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", s.getId());
            m.put("sessionId", s.getSessionId());
            m.put("ipHash", s.getIpHash());
            m.put("country", s.getCountry());
            m.put("city", s.getCity());
            m.put("deviceType", s.getDeviceType());
            m.put("browser", s.getBrowser());
            m.put("operatingSystem", s.getOperatingSystem());
            m.put("pagesViewed", s.getPagesViewed());
            m.put("sessionDurationSeconds", s.getSessionDurationSeconds());
            m.put("isBounce", s.isBounce());
            m.put("firstActivityAt", s.getFirstActivityAt() != null ? s.getFirstActivityAt().toString() : null);
            m.put("lastActivityAt", s.getLastActivityAt() != null ? s.getLastActivityAt().toString() : null);
            m.put("referrer", s.getReferrer());
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", sessions);
        result.put("totalElements", sessionPage.getTotalElements());
        result.put("totalPages", sessionPage.getTotalPages());
        result.put("currentPage", sessionPage.getNumber());
        return result;
    }

    public Map<String, Object> getRecentVisits(UUID boutiqueId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "viewedAt"));
        Page<StoreView> viewPage = storeViewRepository.findByBoutiqueId(boutiqueId, pageable);
        List<Map<String, Object>> visits = viewPage.getContent().stream().map(v -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", v.getId());
            m.put("ipHash", v.getIpHash());
            m.put("page", v.getPage());
            m.put("referrer", v.getReferrer());
            m.put("browser", v.getBrowser());
            m.put("country", v.getCountry());
            m.put("city", v.getCity());
            m.put("userAgent", v.getUserAgent());
            m.put("viewedAt", v.getViewedAt() != null ? v.getViewedAt().toString() : null);
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", visits);
        result.put("totalElements", viewPage.getTotalElements());
        result.put("totalPages", viewPage.getTotalPages());
        result.put("currentPage", viewPage.getNumber());
        return result;
    }

    public List<Map<String, Object>> getMapData(UUID boutiqueId) {
        List<Visitor> visitors = trafficRepository.findActiveVisitorsByBoutiqueId(boutiqueId);
        return visitors.stream()
                .filter(v -> v.getLatitude() != null && v.getLongitude() != null)
                .map(v -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", v.getId());
                    m.put("ipHash", v.getIpHash());
                    m.put("country", v.getCountry());
                    m.put("city", v.getCity());
                    m.put("latitude", v.getLatitude());
                    m.put("longitude", v.getLongitude());
                    m.put("browser", v.getBrowser());
                    m.put("deviceType", v.getDeviceType());
                    m.put("operatingSystem", v.getOperatingSystem());
                    m.put("totalVisits", v.getTotalVisits());
                    m.put("lastActivityAt", v.getLastActivityAt() != null ? v.getLastActivityAt().toString() : null);
                    m.put("isActive", v.getIsActive());
                    return m;
                }).toList();
    }

    public String exportCsv(UUID boutiqueId) {
        List<StoreView> views = storeViewRepository.findAllByBoutiqueIdOrderByViewedAtDesc(boutiqueId);
        StringBuilder sb = new StringBuilder();
        sb.append("ID,IP Hash,Page,Referrer,Browser,Country,City,User Agent,Viewed At\n");
        for (StoreView v : views) {
            sb.append(v.getId()).append(",");
            sb.append(escapeCsv(v.getIpHash())).append(",");
            sb.append(escapeCsv(v.getPage())).append(",");
            sb.append(escapeCsv(v.getReferrer())).append(",");
            sb.append(escapeCsv(v.getBrowser())).append(",");
            sb.append(escapeCsv(v.getCountry())).append(",");
            sb.append(escapeCsv(v.getCity())).append(",");
            sb.append(escapeCsv(v.getUserAgent())).append(",");
            sb.append(v.getViewedAt()).append("\n");
        }
        return sb.toString();
    }

    private String escapeCsv(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    public void deactivateOldVisitors(int daysInactive) {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(daysInactive);
        List<Visitor> inactive = trafficRepository.findByLastActivityAtBefore(cutoff);
        inactive.forEach(v -> {
            v.setIsActive(false);
            trafficRepository.save(v);
        });
    }

    private VisitorResponse toVisitorResponse(Visitor v) {
        return VisitorResponse.builder()
                .id(v.getId().toString())
                .ipHash(v.getIpHash())
                .country(v.getCountry())
                .city(v.getCity())
                .region(v.getRegion())
                .latitude(v.getLatitude())
                .longitude(v.getLongitude())
                .deviceType(v.getDeviceType())
                .browser(v.getBrowser())
                .operatingSystem(v.getOperatingSystem())
                .platform(v.getPlatform())
                .referralSource(v.getReferralSource())
                .totalVisits(v.getTotalVisits())
                .firstVisitAt(v.getFirstVisitAt() != null ? v.getFirstVisitAt().toString() : null)
                .lastActivityAt(v.getLastActivityAt() != null ? v.getLastActivityAt().toString() : null)
                .isActive(v.getIsActive())
                .isAuthenticated(v.getUserId() != null)
                .userEmail(v.getUserEmail())
                .userName(v.getUserName())
                .createdAt(v.getCreatedAt() != null ? v.getCreatedAt().toString() : null)
                .build();
    }
}