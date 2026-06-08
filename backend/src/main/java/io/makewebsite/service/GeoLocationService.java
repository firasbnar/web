package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.makewebsite.util.NetworkUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeoLocationService {

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

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
            log.info("Reverse geocode lat={} lng={} \u2192 country={} city={} region={}",
                    latitude, longitude, country, city, region);
            return Optional.of(new ReverseGeoData(country, city, region, displayName));
        } catch (Exception e) {
            log.warn("Reverse geocode failed for {}/{}: {}", latitude, longitude, e.getMessage());
            return Optional.empty();
        }
    }

    private static final String DEV_COUNTRY = "Tunisie";
    private static final String DEV_CITY = "Sousse";

    /**
     * Detects localhost and private network IPs that cannot be geolocated.
     * This is a development-only helper so the traffic dashboard shows
     * meaningful data (Tunisie / Sousse) instead of "Inconnu".
     */
    private boolean isLocalIp(String ip) {
        return NetworkUtils.isPrivateIp(ip);
    }

    private String safeText(JsonNode node) {
        return node != null ? node.asText() : null;
    }

    @Cacheable(value = "geoLocation", key = "#ip")
    public Optional<GeoData> locate(String ip) {
        if (ip == null || ip.isBlank()) return Optional.empty();
        // Development-only fallback: private/local IPs cannot be geolocated,
        // so assign a default location so the traffic dashboard shows meaningful data.
        if (isLocalIp(ip)) {
            log.debug("Private IP {} detected — assigning development fallback: Tunisie/Sousse", ip);
            return Optional.of(new GeoData(DEV_COUNTRY, DEV_CITY, null, null, null));
        }
        try {
            String json = restTemplate.getForObject("http://ip-api.com/json/" + ip + "?fields=country,city,regionName,lat,lon,status", String.class);
            if (json == null) return Optional.of(new GeoData("Inconnu", "Inconnu", null, null, null));
            JsonNode node = objectMapper.readTree(json);
            if (!"success".equals(node.get("status").asText())) {
                return Optional.of(new GeoData("Inconnu", "Inconnu", null, null, null));
            }
            String country = node.has("country") ? node.get("country").asText() : "Inconnu";
            String city = node.has("city") ? node.get("city").asText() : "Inconnu";
            if (country == null || country.isBlank() || "null".equalsIgnoreCase(country)) country = "Inconnu";
            if (city == null || city.isBlank() || "null".equalsIgnoreCase(city)) city = "Inconnu";
            return Optional.of(new GeoData(
                    country,
                    city,
                    node.has("regionName") ? node.get("regionName").asText() : null,
                    node.has("lat") ? node.get("lat").asDouble() : null,
                    node.has("lon") ? node.get("lon").asDouble() : null
            ));
        } catch (Exception e) {
            log.warn("GeoIP lookup failed for {}: {}", ip, e.getMessage());
            return Optional.of(new GeoData("Inconnu", "Inconnu", null, null, null));
        }
    }
}
