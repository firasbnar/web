package io.makewebsite.controller;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.entity.Boutique;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.service.StoreGeneratorService;
import io.makewebsite.service.TrafficService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequiredArgsConstructor
public class StorefrontController {

    private final BoutiqueRepository boutiqueRepository;
    private final StoreGeneratorService storeGeneratorService;
    private final TrafficService trafficService;

    @GetMapping("/store/{identifier}")
    public ResponseEntity<String> serveStore(
            @PathVariable String identifier,
            HttpServletRequest request,
            HttpServletResponse response) {

        Boutique boutique = lookupBoutique(identifier);
        if (boutique == null) return ResponseEntity.notFound().build();

        // Unpublished/DRAFT stores – show placeholder
        if (Boolean.FALSE.equals(boutique.getIsPublished())) {
            String placeholder = "<!DOCTYPE html><html lang=\"fr\"><head><meta charset=\"UTF-8\">" +
                "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">" +
                "<title>" + esc(boutique.getName()) + "</title>" +
                "<style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#f9f9f9;color:#333}" +
                ".card{text-align:center;padding:48px;max-width:420px}.card h1{font-size:1.5rem;margin-bottom:8px}.card p{color:#666;line-height:1.6}" +
                "</style></head><body><div class=\"card\">" +
                "<h1>" + esc(boutique.getName()) + "</h1>" +
                "<p>Cette boutique est en cours de configuration et sera bientôt disponible.</p>" +
                "</div></body></html>";
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                    .body(placeholder);
        }

        String html = storeGeneratorService.loadHtml(boutique.getSlug());
        if (html == null) {
            storeGeneratorService.regenerate(boutique.getId());
            html = boutique.getGeneratedHtml();
            if (html == null) return ResponseEntity.notFound().build();
        }

        // Track visit internally
        trackStoreVisit(boutique, request);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                .body(html);
    }

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private Boutique lookupBoutique(String identifier) {
        try {
            UUID id = UUID.fromString(identifier);
            return boutiqueRepository.findById(id).orElse(null);
        } catch (IllegalArgumentException e) {
            return boutiqueRepository.findBySlug(identifier).orElse(null);
        }
    }

    private void trackStoreVisit(Boutique boutique, HttpServletRequest request) {
        try {
            String ip = request.getRemoteAddr();
            String ua = request.getHeader("User-Agent");
            String referrer = request.getHeader("Referer");
            log.info("=== STORE VISIT === slug={}, boutiqueId={}, ip={}, ua={}, referrer={}",
                    boutique.getSlug(), boutique.getId(), ip, ua != null ? ua.substring(0, Math.min(80, ua.length())) : "null", referrer);

            TrackVisitRequest req = new TrackVisitRequest();
            req.setBoutiqueId(boutique.getId());
            req.setBoutiqueSlug(boutique.getSlug());
            req.setPage("/store/" + boutique.getSlug());
            req.setIpAddress(ip);
            req.setUserAgent(ua);
            req.setReferrer(referrer);
            req.setPlatform("WEB");
            req.setDeviceType(detectDeviceType(ua));
            req.setBrowser(detectBrowser(ua));
            req.setOperatingSystem(detectOS(ua));
            Map<String, Object> result = trafficService.trackVisit(req);
            log.info("=== VISIT SAVED === tracked={}, visitId={}", result.get("tracked"), result.get("visitId"));
        } catch (Exception e) {
            log.warn("Failed to track store visit for slug={}: {}", boutique.getSlug(), e.getMessage());
        }
    }

    private String detectDeviceType(String userAgent) {
        if (userAgent == null) return "Desktop";
        String ua = userAgent.toLowerCase();
        if (ua.contains("mobile")) return "Mobile";
        if (ua.contains("tablet") || ua.contains("ipad")) return "Tablet";
        if (ua.contains("android") && !ua.contains("mobile")) return "Tablet";
        return "Desktop";
    }

    private String detectBrowser(String userAgent) {
        if (userAgent == null) return "Unknown";
        String ua = userAgent.toLowerCase();
        if (ua.contains("edg")) return "Edge";
        if (ua.contains("chrome")) return "Chrome";
        if (ua.contains("firefox")) return "Firefox";
        if (ua.contains("safari")) return "Safari";
        if (ua.contains("opera") || ua.contains("opr")) return "Opera";
        if (ua.contains("msie") || ua.contains("trident")) return "Internet Explorer";
        return "Unknown";
    }

    private String detectOS(String userAgent) {
        if (userAgent == null) return "Unknown";
        String ua = userAgent.toLowerCase();
        if (ua.contains("windows")) return "Windows";
        if (ua.contains("mac")) return "macOS";
        if (ua.contains("linux")) return "Linux";
        if (ua.contains("android")) return "Android";
        if (ua.contains("iphone") || ua.contains("ipad")) return "iOS";
        return "Unknown";
    }
}
