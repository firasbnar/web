package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeoLocationService {

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.geo.localhost-fallback:true}")
    private boolean localhostFallbackEnabled;

    public record GeoData(String country, String city, String region,
                          Double latitude, Double longitude) {}

    public record ReverseGeoData(String country, String city, String region, String address) {}

    @Cacheable(value = "reverseGeo", key = "#latitude.toString() + ',' + #longitude.toString()")
    public Optional<ReverseGeoData> reverseGeocode(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) return Optional.empty();
        try {
            String url = String.format(
                "https://nominatim.openstreetmap.org/reverse?format=json&lat=%s&lon=%s&addressdetails=1&accept-language=fr",
                latitude, longitude);
            String json = restTemplate.getForObject(url, String.class);
            if (json == null) return Optional.empty();
            JsonNode node = objectMapper.readTree(json);
            if (node.has("error")) {
                log.warn("Nominatim reverse geocode error: {}", node.get("error").asText());
                return Optional.empty();
            }
            JsonNode address = node.get("address");
            String country = address != null ? safeText(address.get("country")) : null;
            String city = address != null ? safeText(address.get("city")) : null;
            if (city == null) city = address != null ? safeText(address.get("town")) : null;
            if (city == null) city = address != null ? safeText(address.get("village")) : null;
            if (city == null) city = address != null ? safeText(address.get("municipality")) : null;
            String region = address != null ? safeText(address.get("state")) : null;
            String displayName = safeText(node.get("display_name"));
            log.info("Reverse geocode lat={} lng={} → country={} city={} region={}",
                    latitude, longitude, country, city, region);
            return Optional.of(new ReverseGeoData(country, city, region, displayName));
        } catch (Exception e) {
            log.warn("Reverse geocode failed for {}/{}: {}", latitude, longitude, e.getMessage());
            return Optional.empty();
        }
    }

    private String safeText(JsonNode node) {
        return node != null ? node.asText() : null;
    }

    @Cacheable(value = "geoLocation", key = "#ip")
    public Optional<GeoData> locate(String ip) {
        if (ip == null || ip.isBlank()) return Optional.empty();
        // Private/local IPs — return localhost placeholder for development
        if (localhostFallbackEnabled && isPrivateIp(ip)) {
            log.debug("Local/dev IP {}, returning default geo (Sousse, Tunisia)", ip);
            return Optional.of(new GeoData("Tunisie", "Sousse", "Sousse", 35.8256, 10.63699));
        }
        try {
            String json = restTemplate.getForObject("http://ip-api.com/json/" + ip + "?fields=country,city,regionName,lat,lon,status", String.class);
            if (json == null) return Optional.empty();
            JsonNode node = objectMapper.readTree(json);
            if (!"success".equals(node.get("status").asText())) return Optional.empty();
            return Optional.of(new GeoData(
                    node.get("country").asText(),
                    node.get("city").asText(),
                    node.get("regionName").asText(),
                    node.get("lat").asDouble(),
                    node.get("lon").asDouble()
            ));
        } catch (Exception e) {
            log.warn("GeoIP lookup failed for {}: {}", ip, e.getMessage());
            return Optional.empty();
        }
    }

    private boolean isPrivateIp(String ip) {
        if (ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("127.")
                || "::1".equals(ip) || "localhost".equalsIgnoreCase(ip)) {
            return true;
        }
        if (ip.startsWith("172.") && ip.length() > 5) {
            try {
                int dot = ip.indexOf('.', 4);
                if (dot > 0) {
                    int second = Integer.parseInt(ip.substring(4, dot));
                    return second >= 16 && second <= 31;
                }
            } catch (Exception e) {
                return false;
            }
        }
        return false;
    }
}
