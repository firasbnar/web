package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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

    public record GeoData(String country, String city, String region,
                          Double latitude, Double longitude) {}

    @Cacheable(value = "geoLocation", key = "#ip")
    public Optional<GeoData> locate(String ip) {
        if (ip == null || ip.isBlank() || ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("127.") || "::1".equals(ip) || "localhost".equalsIgnoreCase(ip)) {
            return Optional.empty();
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
}
