package io.makewebsite.controller;

import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.StoreView;
import io.makewebsite.entity.Visitor;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.StoreViewRepository;
import io.makewebsite.repository.TrafficRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Slf4j
@RestController
@RequestMapping("/api/dev")
@RequiredArgsConstructor
public class DevTrafficController {

    private final BoutiqueRepository boutiqueRepository;
    private final StoreViewRepository storeViewRepository;
    private final TrafficRepository trafficRepository;

    @Value("${spring.profiles.active:}")
    private String activeProfile;

    @PostMapping("/traffic/inject")
    public ResponseEntity<Map<String, Object>> injectTraffic(@RequestBody Map<String, Object> body) {
        // Guard: only allow in dev/local profiles
        if (activeProfile != null && activeProfile.contains("prod")) {
            return ResponseEntity.status(403).body(Map.of("success", false, "message", "Interdit en production"));
        }

        String slug = (String) body.get("slug");
        if (slug == null || slug.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "slug requis"));
        }

        Boutique boutique = boutiqueRepository.findBySlug(slug).orElse(null);
        if (boutique == null) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Boutique introuvable: " + slug));
        }

        String country = (String) body.get("country");
        String city = (String) body.get("city");
        String address = (String) body.get("address");
        Double lat = body.get("latitude") != null ? ((Number) body.get("latitude")).doubleValue() : 35.8256;
        Double lng = body.get("longitude") != null ? ((Number) body.get("longitude")).doubleValue() : 10.63699;
        String browser = (String) body.get("browser");
        String referrer = (String) body.get("referrer");
        int count = body.get("visits") != null ? ((Number) body.get("visits")).intValue() : 1;

        if (country == null) country = "Tunisie";
        if (city == null) city = "Sousse";
        if (address == null) address = city + ", " + country;
        if (browser == null) browser = "Chrome";
        if (referrer == null) referrer = "Direct";

        // Default cities to spread across if multiple visits
        List<LocationPreset> presets = List.of(
            new LocationPreset("Tunisie", "Tunis", "Tunis, Tunisia", 36.8065, 10.1815),
            new LocationPreset("Tunisie", "Sousse", "Sousse, Tunisia", 35.8256, 10.63699),
            new LocationPreset("Tunisie", "Sfax", "Sfax, Tunisia", 34.7400, 10.7600),
            new LocationPreset("France", "Paris", "Paris, France", 48.8566, 2.3522),
            new LocationPreset("Émirats Arabes Unis", "Dubai", "Dubai, UAE", 25.2048, 55.2708)
        );
        List<String> browsers = List.of("Chrome", "Safari", "Firefox", "Edge", "Chrome", "Safari");
        List<String> referrers = List.of("Instagram", "Facebook", "TikTok", "Direct", "WhatsApp", "Google");

        int created = 0;
        int visitorCreated = 0;
        LocalDateTime now = LocalDateTime.now();

        for (int i = 0; i < count; i++) {
            // Pick location (cycle through presets)
            LocationPreset loc = presets.get(i % presets.size());
            double visitLat = loc.lat + (Math.random() - 0.5) * 0.02;
            double visitLng = loc.lng + (Math.random() - 0.5) * 0.02;
            String visitCountry = loc.country;
            String visitCity = loc.city;
            String visitAddress = loc.address;
            String visitBrowser = browsers.get((int) (Math.random() * browsers.size()));
            String visitReferrer = referrers.get((int) (Math.random() * referrers.size()));
            String visitUa = "Mozilla/5.0 " + visitBrowser + "/" + (100 + (int)(Math.random() * 30));

            // Spread timestamps across last 24 hours
            LocalDateTime ts = now.minus((long) (Math.random() * 24 * 60), ChronoUnit.MINUTES);
            String ipHash = hashIp("127.0.0." + (1 + (int)(Math.random() * 10)));

            // Create StoreView
            StoreView view = StoreView.builder()
                    .boutiqueId(boutique.getId())
                    .ipHash(ipHash)
                    .page("/store/" + slug)
                    .referrer(visitReferrer)
                    .browser(visitBrowser)
                    .country(visitCountry)
                    .city(visitCity)
                    .address(visitAddress)
                    .latitude(visitLat)
                    .longitude(visitLng)
                    .userAgent(visitUa)
                    .visitorId(UUID.randomUUID().toString().substring(0, 12))
                    .viewedAt(ts)
                    .build();
            storeViewRepository.save(view);
            created++;

            // Create Visitor record (for map markers)
            String finalVisitCountry = visitCountry;
            String finalVisitCity = visitCity;
            try {
                Visitor existing = trafficRepository.findByBoutiqueIdAndIpHash(boutique.getId(), ipHash).orElse(null);
                if (existing != null) {
                    existing.setTotalVisits(existing.getTotalVisits() + 1);
                    existing.setLastActivityAt(ts);
                    existing.setIsActive(true);
                    existing.setCountry(finalVisitCountry);
                    existing.setCity(finalVisitCity);
                    existing.setLatitude(visitLat);
                    existing.setLongitude(visitLng);
                    existing.setBrowser(visitBrowser);
                    existing.setUserAgent(visitUa);
                    existing.setReferralSource(visitReferrer);
                    trafficRepository.save(existing);
                } else {
                    Visitor v = Visitor.builder()
                            .boutiqueId(boutique.getId())
                            .ipHash(ipHash)
                            .country(finalVisitCountry)
                            .city(finalVisitCity)
                            .latitude(visitLat)
                            .longitude(visitLng)
                            .browser(visitBrowser)
                            .userAgent(visitUa)
                            .referralSource(visitReferrer)
                            .totalVisits(1L)
                            .isActive(true)
                            .build();
                    trafficRepository.save(v);
                }
                visitorCreated++;
            } catch (Exception e) {
                log.warn("Failed to create Visitor for inject: {}", e.getMessage());
            }
        }

        log.info("Injected {} StoreViews and {} Visitors for boutique slug={}", created, visitorCreated, slug);
        return ResponseEntity.ok(Map.of(
            "success", true,
            "storeViewsCreated", created,
            "visitorsCreated", visitorCreated,
            "slug", slug
        ));
    }

    private String hashIp(String ip) {
        if (ip == null) return "unknown";
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(ip.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString().substring(0, 32);
        } catch (NoSuchAlgorithmException e) {
            return ip;
        }
    }

    private record LocationPreset(String country, String city, String address, double lat, double lng) {}
}
