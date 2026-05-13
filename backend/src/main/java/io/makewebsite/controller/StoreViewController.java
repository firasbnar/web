package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.StoreView;
import io.makewebsite.repository.StoreViewRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class StoreViewController {
    private final StoreViewRepository storeViewRepository;

    @GetMapping("/boutiques/{boutiqueId}/traffic/stats")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getTrafficStats(@PathVariable UUID boutiqueId) {
        long totalVisits = storeViewRepository.countByBoutiqueId(boutiqueId);
        long todayVisits = storeViewRepository.countByBoutiqueIdAndViewedAtBetween(boutiqueId,
                LocalDateTime.of(LocalDate.now(), LocalTime.MIN),
                LocalDateTime.of(LocalDate.now(), LocalTime.MAX));
        long weekVisits = storeViewRepository.countByBoutiqueIdAndViewedAtBetween(boutiqueId,
                LocalDateTime.now().minusDays(7), LocalDateTime.now());
        long monthVisits = storeViewRepository.countByBoutiqueIdAndViewedAtBetween(boutiqueId,
                LocalDateTime.now().minusDays(30), LocalDateTime.now());
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalVisits", totalVisits);
        stats.put("todayVisits", todayVisits);
        stats.put("weekVisits", weekVisits);
        stats.put("monthVisits", monthVisits);
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }

    @GetMapping("/boutiques/{boutiqueId}/traffic/visits")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getVisits(
            @PathVariable UUID boutiqueId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "viewedAt"));
        Page<StoreView> visitPage = storeViewRepository.findByBoutiqueId(boutiqueId, pageable);
        List<Map<String, Object>> visits = visitPage.getContent().stream().map(v -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", v.getId());
            m.put("ipHash", v.getIpHash());
            m.put("viewedAt", v.getViewedAt());
            m.put("page", v.getPage());
            m.put("referrer", v.getReferrer());
            m.put("browser", v.getBrowser());
            m.put("country", v.getCountry());
            m.put("city", v.getCity());
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", visits);
        result.put("totalElements", visitPage.getTotalElements());
        result.put("totalPages", visitPage.getTotalPages());
        result.put("currentPage", visitPage.getNumber());
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/boutiques/{boutiqueId}/traffic/top-countries")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTopCountries(@PathVariable UUID boutiqueId) {
        List<Object[]> results = storeViewRepository.countByBoutiqueIdGroupByCountry(boutiqueId);
        List<Map<String, Object>> list = results.stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("country", r[0]);
            m.put("count", r[1]);
            return m;
        }).toList();
        return ResponseEntity.ok(ApiResponse.ok(list));
    }

    @GetMapping("/boutiques/{boutiqueId}/traffic/top-cities")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTopCities(@PathVariable UUID boutiqueId) {
        List<Object[]> results = storeViewRepository.countByBoutiqueIdGroupByCity(boutiqueId);
        List<Map<String, Object>> list = results.stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("city", r[0]);
            m.put("country", r[1]);
            m.put("count", r[2]);
            return m;
        }).toList();
        return ResponseEntity.ok(ApiResponse.ok(list));
    }


}
