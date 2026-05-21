package io.makewebsite.service;

import io.makewebsite.entity.StoreView;
import io.makewebsite.repository.StoreViewRepository;
import io.makewebsite.service.GeoLocationService.GeoData;
import io.makewebsite.service.GeoLocationService.ReverseGeoData;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BoutiqueVisitService {

    private final StoreViewRepository storeViewRepository;
    private final GeoLocationService geoLocationService;

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

    private String detectBrowser(String userAgent) {
        if (userAgent == null) return null;
        String ua = userAgent.toLowerCase();
        if (ua.contains("edg")) return "Edge";
        if (ua.contains("chrome")) return "Chrome";
        if (ua.contains("firefox")) return "Firefox";
        if (ua.contains("safari")) return "Safari";
        if (ua.contains("opera") || ua.contains("opr")) return "Opera";
        if (ua.contains("msie") || ua.contains("trident")) return "Internet Explorer";
        return "Autre";
    }

    private boolean hasRecentVisit(UUID boutiqueId, String visitorId, String ipHash) {
        LocalDateTime thirtyMinAgo = LocalDateTime.now().minusMinutes(30);
        if (visitorId != null && !visitorId.isEmpty()) {
            Optional<StoreView> existing = storeViewRepository
                    .findFirstByBoutiqueIdAndVisitorIdAndViewedAtAfter(boutiqueId, visitorId, thirtyMinAgo);
            if (existing.isPresent()) {
                log.debug("Duplicate visit by visitorId={} for boutiqueId={} within 30min, skipping", visitorId, boutiqueId);
                return true;
            }
        }
        Optional<StoreView> existing = storeViewRepository
                .findFirstByBoutiqueIdAndIpHashAndViewedAtAfter(boutiqueId, ipHash, thirtyMinAgo);
        if (existing.isPresent()) {
            log.debug("Duplicate visit by ipHash={} for boutiqueId={} within 30min, skipping", ipHash, boutiqueId);
            return true;
        }
        return false;
    }

    @Transactional
    public void recordVisit(UUID boutiqueId, String slug, String ipAddress, String userAgent, String visitorId, String referrer, Double latitude, Double longitude) {
        String ipHash = hashIp(ipAddress);
        if (hasRecentVisit(boutiqueId, visitorId, ipHash)) return;

        Double lat = latitude;
        Double lng = longitude;
        String country = null;
        String city = null;
        String address = null;

        // If browser provided coordinates, reverse-geocode them for accurate country/city/address
        boolean hasBrowserCoords = lat != null && lng != null;
        if (hasBrowserCoords) {
            try {
                var rev = geoLocationService.reverseGeocode(lat, lng);
                if (rev.isPresent()) {
                    var r = rev.get();
                    country = r.country();
                    city = r.city();
                    address = r.address();
                    log.info("Reverse geocode: lat={} lng={} → country={} city={} addr={}", lat, lng, country, city, address);
                }
            } catch (Exception e) {
                log.warn("Reverse geocode failed, falling back to IP geo: {}", e.getMessage());
            }
        }

        // If no reverse geo result (or no browser coords), fallback to IP geolocation
        if (country == null || city == null) {
            GeoData geo = ipAddress != null ? geoLocationService.locate(ipAddress).orElse(null) : null;
            if (geo != null) {
                if (country == null) country = geo.country();
                if (city == null) city = geo.city();
                if (lat == null) lat = geo.latitude();
                if (lng == null) lng = geo.longitude();
                if (address == null) address = city != null && country != null ? city + ", " + country : null;
                log.info("IP geo fallback: country={} city={} lat={} lng={}", country, city, lat, lng);
            }
        }

        // Final fallback — never leave country/city null
        if (country == null) country = "Inconnu";
        if (city == null) city = "Inconnu";

        // Browser detection
        String browser = detectBrowser(userAgent);

        StoreView view = StoreView.builder()
                .boutiqueId(boutiqueId)
                .page("/store/" + slug)
                .ipHash(ipHash)
                .visitorId(visitorId)
                .userAgent(userAgent)
                .referrer(referrer)
                .country(country)
                .city(city)
                .latitude(lat)
                .longitude(lng)
                .address(address)
                .browser(browser)
                .viewedAt(LocalDateTime.now())
                .build();
        storeViewRepository.save(view);
        log.info("Visit recorded for boutiqueId={} slug={} country={} city={} addr={} lat={} lng={} browser={} ipHash={}",
                boutiqueId, slug, country, city, address, lat, lng, browser, ipHash);
    }
}
