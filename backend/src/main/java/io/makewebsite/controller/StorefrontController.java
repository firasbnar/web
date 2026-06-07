package io.makewebsite.controller;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.dto.response.PublicProductDto;
import io.makewebsite.dto.response.PublicReviewDto;
import io.makewebsite.dto.response.StoreData;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Product;
import io.makewebsite.entity.Review;
import io.makewebsite.entity.ReviewStatus;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.ProductRepository;
import io.makewebsite.repository.ReviewRepository;
import io.makewebsite.service.StoreGeneratorService;
import io.makewebsite.service.TrafficService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.thymeleaf.context.Context;
import org.thymeleaf.spring6.SpringTemplateEngine;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequiredArgsConstructor
public class StorefrontController {

    private final BoutiqueRepository boutiqueRepository;
    private final StoreGeneratorService storeGeneratorService;
    private final TrafficService trafficService;
    private final ProductRepository productRepository;
    private final ReviewRepository reviewRepository;
    private final SpringTemplateEngine templateEngine;

    @GetMapping("/store/{identifier}")
    public ResponseEntity<String> serveStore(
            @PathVariable String identifier,
            @RequestParam(value = "product_id", required = false) String productId,
            HttpServletRequest request,
            HttpServletResponse response) {

        log.info("=== STORE REQUEST === slug={}, product_id={}", identifier, productId);

        Boutique boutique = lookupBoutique(identifier);
        if (boutique == null) {
            log.warn("Boutique not found for identifier={}", identifier);
            String notFoundHtml = "<!DOCTYPE html><html lang=\"fr\"><head><meta charset=\"UTF-8\">" +
                "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">" +
                "<title>Boutique introuvable</title>" +
                "<style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#f9f9f9;color:#333}" +
                ".card{text-align:center;padding:48px;max-width:420px}.card h1{font-size:1.5rem;margin-bottom:8px;color:#e53e3e}.card p{color:#666;line-height:1.6}" +
                "</style></head><body><div class=\"card\">" +
                "<h1>Boutique introuvable</h1>" +
                "<p>La boutique que vous recherchez n'existe pas ou a ete supprimee.</p>" +
                "</div></body></html>";
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                    .body(notFoundHtml);
        }

        log.info("Boutique found: id={}, slug={}, storeStatus={}, isPublished={}",
                boutique.getId(), boutique.getSlug(),
                boutique.getStoreStatus(), boutique.getIsPublished());

        // Check store status — null-safe (null → ACTIVE)
        String status = boutique.getStoreStatus() != null ? boutique.getStoreStatus() : "ACTIVE";
        String pageTitle = esc(boutique.getName());
        if ("FROZEN".equals(status) || "SUSPENDED".equals(status)) {
            String msg = "FROZEN".equals(status)
                ? "Cette boutique est actuellement indisponible. Veuillez r\u00E9essayer plus tard."
                : "Cette boutique a \u00E9t\u00E9 suspendue. Veuillez contacter le support.";
            String placeholder = "<!DOCTYPE html><html lang=\"fr\"><head><meta charset=\"UTF-8\">" +
                "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">" +
                "<title>" + pageTitle + "</title>" +
                "<style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#f9f9f9;color:#333}" +
                ".card{text-align:center;padding:48px;max-width:420px}.card h1{font-size:1.5rem;margin-bottom:8px}.card p{color:#666;line-height:1.6}" +
                "</style></head><body><div class=\"card\">" +
                "<h1>" + pageTitle + "</h1><p>" + msg + "</p></div></body></html>";
            log.info("Store status={} for slug={}", status, boutique.getSlug());
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                    .body(placeholder);
        }
        // DRAFT stores show configuration message — null isPublished → PUBLISHED
        if (Boolean.FALSE.equals(boutique.getIsPublished())) {
            String placeholder = "<!DOCTYPE html><html lang=\"fr\"><head><meta charset=\"UTF-8\">" +
                "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\">" +
                "<title>" + pageTitle + "</title>" +
                "<style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#f9f9f9;color:#333}" +
                ".card{text-align:center;padding:48px;max-width:420px}.card h1{font-size:1.5rem;margin-bottom:8px}.card p{color:#666;line-height:1.6}" +
                "</style></head><body><div class=\"card\">" +
                "<h1>" + pageTitle + "</h1>" +
                "<p>Cette boutique est en cours de configuration et sera bient\u00F4t disponible.</p>" +
                "</div></body></html>";
            log.info("Store is DRAFT for slug={}", boutique.getSlug());
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                    .body(placeholder);
        }

        // Load store data from DB
        StoreData storeData;
        try {
            storeData = storeGeneratorService.loadStoreData(boutique.getSlug());
            log.info("Store data: slug={}, products={}, categories={}, sliders={}",
                    boutique.getSlug(),
                    storeData.getProducts() != null ? storeData.getProducts().size() : 0,
                    storeData.getCategories() != null ? storeData.getCategories().size() : 0,
                    storeData.getSliders() != null ? storeData.getSliders().size() : 0);
        } catch (Exception e) {
            log.error("Public store failed for slug={}", identifier, e);
            return ResponseEntity.internalServerError()
                    .body("<html><body><h1>Erreur</h1><p>Impossible de charger la boutique.</p></body></html>");
        }

        // If product_id is present, load product detail (only if it belongs to this boutique)
        List<PublicReviewDto> approvedReviews = List.of();
        int reviewsCount = 0;
        double avgRating = 0;
        if (productId != null && !productId.isBlank()) {
            try {
                UUID pid = UUID.fromString(productId);
                productRepository.findPublicProductDetails(boutique.getSlug(), pid)
                        .map(StoreData::toProductDto)
                        .ifPresentOrElse(
                            storeData::setDetailProduct,
                            () -> log.warn("Product not found for productId={}, slug={}", pid, identifier)
                        );
                if (storeData.getDetailProduct() != null) {
                    List<Review> all = reviewRepository.findByProductIdAndStatusOrderByCreatedAtDesc(pid, ReviewStatus.APPROVED);
                    reviewsCount = all.size();
                    avgRating = all.isEmpty() ? 0 : all.stream().mapToInt(Review::getRating).average().orElse(0);
                    approvedReviews = all.stream().map(r -> PublicReviewDto.builder()
                            .customerName(r.getCustomerName() != null ? r.getCustomerName() : "")
                            .rating(r.getRating())
                            .comment(r.getComment() != null ? r.getComment() : "")
                            .createdAt(r.getCreatedAt())
                            .build()).toList();
                    log.info("Product detail reviews: productId={}, boutiqueId={}, approvedReviews={}, averageRating={}",
                            pid, boutique.getId(), reviewsCount, avgRating);
                }
            } catch (IllegalArgumentException e) {
                log.warn("Invalid product_id format: {}", productId);
            }
        }

        // Render via Thymeleaf template
        try {
            Context ctx = new Context();
            ctx.setVariable("store", storeData);
            ctx.setVariable("detailProduct", storeData.getDetailProduct());
            ctx.setVariable("reviews", approvedReviews);
            ctx.setVariable("reviewsCount", reviewsCount);
            ctx.setVariable("averageRating", avgRating);
            String html = templateEngine.process("public-store", ctx);

            // Track visit internally
            trackStoreVisit(boutique, request);

            log.info("Store rendered successfully: slug={}, products={}, categories={}",
                    identifier,
                    storeData.getProducts() != null ? storeData.getProducts().size() : 0,
                    storeData.getCategories() != null ? storeData.getCategories().size() : 0);

            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                    .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                    .header(HttpHeaders.PRAGMA, "no-cache")
                    .header(HttpHeaders.EXPIRES, "0")
                    .body(html);
        } catch (Exception e) {
            log.error("Public store failed for slug={}", identifier, e);
            return ResponseEntity.internalServerError()
                    .body("<html><body><h1>Erreur</h1><p>Impossible de charger la boutique.</p></body></html>");
        }
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
