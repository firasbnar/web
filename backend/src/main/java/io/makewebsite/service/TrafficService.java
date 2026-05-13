package io.makewebsite.service;

import io.makewebsite.dto.response.*;
import io.makewebsite.entity.Visitor;
import io.makewebsite.repository.TrafficRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TrafficService {

    private final TrafficRepository trafficRepository;

    public TrafficStatsResponse getStats(UUID boutiqueId) {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime todayEnd = LocalDate.now().atTime(LocalTime.MAX);
        LocalDateTime weekStart = LocalDateTime.now().minusDays(7);
        LocalDateTime monthStart = LocalDateTime.now().minusDays(30);

        return TrafficStatsResponse.builder()
                .totalVisits(trafficRepository.sumTotalVisitsByBoutiqueId(boutiqueId))
                .uniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueId(boutiqueId))
                .todayVisits(trafficRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, todayEnd))
                .todayUniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueIdBetween(boutiqueId, todayStart, todayEnd))
                .weekVisits(trafficRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, weekStart, LocalDateTime.now()))
                .weekUniqueVisitors(trafficRepository.countUniqueVisitorsByBoutiqueIdBetween(boutiqueId, weekStart, LocalDateTime.now()))
                .monthVisits(trafficRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, monthStart, LocalDateTime.now()))
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
        List<Visitor> visitors = trafficRepository.findByBoutiqueIdAndCreatedAtBetween(boutiqueId, fromDt, toDt);

        Map<String, List<Visitor>> grouped;
        if ("weekly".equals(period)) {
            grouped = visitors.stream().collect(Collectors.groupingBy(v ->
                    v.getCreatedAt().format(java.time.format.DateTimeFormatter.ofPattern("yyyy-'W'ww"))));
        } else if ("monthly".equals(period)) {
            grouped = visitors.stream().collect(Collectors.groupingBy(v ->
                    v.getCreatedAt().format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM"))));
        } else {
            grouped = visitors.stream().collect(Collectors.groupingBy(v ->
                    v.getCreatedAt().format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd"))));
        }

        return grouped.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(e -> VisitorTimelineResponse.builder()
                        .date(e.getKey())
                        .visits((long) e.getValue().size())
                        .uniqueVisitors(e.getValue().stream().map(Visitor::getIpHash).distinct().count())
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