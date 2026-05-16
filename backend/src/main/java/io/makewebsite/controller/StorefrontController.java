package io.makewebsite.controller;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.entity.Boutique;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.service.StoreGeneratorService;
import io.makewebsite.service.TrafficService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

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
            TrackVisitRequest req = new TrackVisitRequest();
            req.setBoutiqueId(boutique.getId());
            req.setBoutiqueSlug(boutique.getSlug());
            req.setPage("/store/" + boutique.getSlug());
            req.setIpAddress(request.getRemoteAddr());
            req.setUserAgent(request.getHeader("User-Agent"));
            req.setReferrer(request.getHeader("Referer"));
            req.setPlatform("WEB");
            req.setDeviceType(detectDeviceType(request.getHeader("User-Agent")));
            req.setBrowser(detectBrowser(request.getHeader("User-Agent")));
            req.setOperatingSystem(detectOS(request.getHeader("User-Agent")));
            trafficService.trackVisit(req);
        } catch (Exception e) {
            // Don't let tracking break the store page
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
