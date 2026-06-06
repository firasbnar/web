package io.makewebsite.controller;

import io.makewebsite.dto.request.TrackVisitRequest;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Product;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.ProductRepository;
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

import java.math.BigDecimal;
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
    private static final String DEFAULT_PRODUCT_IMAGE = "/images/default-product.png";

    @GetMapping("/store/{identifier}")
    public ResponseEntity<String> serveStore(
            @PathVariable String identifier,
            @RequestParam(value = "product_id", required = false) String productId,
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
                "<p>Cette boutique est en cours de configuration et sera bient\u00F4t disponible.</p>" +
                "</div></body></html>";
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                    .body(placeholder);
        }

        // If product_id is present, serve product detail page
        if (productId != null && !productId.isBlank()) {
            try {
                UUID pid = UUID.fromString(productId);
                Product p = productRepository.findByIdWithBoutique(pid).orElse(null);
                if (p == null || !p.getIsActive() || !p.getBoutique().getId().equals(boutique.getId())) {
                    return ResponseEntity.notFound().build();
                }
                String html = buildProductDetailHtml(boutique, p);
                if (html == null) return ResponseEntity.notFound().build();
                trackStoreVisit(boutique, request);
                return ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                        .body(html);
            } catch (IllegalArgumentException e) {
                // Invalid UUID — fall through to normal store page
            }
        }

        String html = storeGeneratorService.loadHtml(boutique.getSlug());
        if (html == null) {
            storeGeneratorService.regenerate(boutique.getId());
            boutique = lookupBoutique(identifier);
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

    /**
     * Build a full product detail HTML page by replacing the &lt;main&gt; section
     * of the generated store HTML with product detail content.
     */
    private String buildProductDetailHtml(Boutique b, Product p) {
        String html = storeGeneratorService.loadHtml(b.getSlug());
        if (html == null) return null;

        String currencySymbol = b.getCurrency() != null
            ? (b.getCurrency().equals("TND") ? "DT"
               : b.getCurrency().equals("EUR") ? "\u20AC" : "$")
            : "DT";

        String firstImg = extractFirstImage(p.getImages());
        String productImg = resolveImageUrl(firstImg.isBlank() ? null : firstImg);

        boolean hasCompare = p.getComparePrice() != null
            && p.getComparePrice().compareTo(BigDecimal.ZERO) > 0;
        String priceHtml = hasCompare
            ? "<old style=\"text-decoration:line-through;color:var(--muted);margin-right:8px\">"
                + currencySymbol + String.format("%.2f", p.getComparePrice()) + "</old> "
                + currencySymbol + String.format("%.2f", p.getPrice())
            : currencySymbol + String.format("%.2f", p.getPrice());

        boolean inStock = p.getStock() == null || p.getStock() > 0;
        String stockHtml = inStock
            ? "<span style=\"color:#16a34a;font-weight:500\">\u2713 En stock</span>"
            : "<span style=\"color:#ef4444;font-weight:500\">\u2717 Rupture de stock</span>";

        String detailContent =
            "<style>" +
            ".pd-wrap{display:grid;grid-template-columns:1fr 1fr;gap:32px;max-width:1000px;margin:0 auto;padding:20px}" +
            "@media(max-width:768px){.pd-wrap{grid-template-columns:1fr}}" +
            ".pd-img{width:100%;border-radius:12px;max-height:500px;object-fit:cover}" +
            ".pd-name{font-size:1.75rem;font-weight:700;margin-bottom:12px}" +
            ".pd-price{font-size:1.5rem;font-weight:700;color:var(--accent);margin-bottom:16px}" +
            ".pd-stock{font-size:0.9375rem;margin-bottom:16px}" +
            ".pd-desc{color:var(--text-soft);font-size:0.9375rem;line-height:1.7;margin-bottom:24px}" +
            ".pd-actions{display:flex;gap:12px;align-items:center;flex-wrap:wrap}" +
            ".pd-actions .add-cart{padding:14px 24px;background:var(--accent);color:#fff;border:none;border-radius:8px;font-weight:600;cursor:pointer;font-size:1rem;transition:0.25s ease}" +
            ".pd-actions .add-cart:hover{filter:brightness(1.1)}" +
            ".pd-actions .wishlist-toggle{width:48px;height:48px;border-radius:8px;border:1px solid var(--border);background:#fff;cursor:pointer;font-size:1.2rem;display:flex;align-items:center;justify-content:center}" +
            ".pd-actions .wishlist-toggle:hover{border-color:var(--accent);color:var(--accent)}" +
            ".pd-back{text-align:center;margin-top:24px}" +
            ".pd-back a{color:var(--accent);text-decoration:none;font-weight:500}" +
            ".pd-back a:hover{text-decoration:underline}" +
            "</style>" +
            "<div class=\"pd-wrap\">" +
            "<div><img class=\"pd-img\" src=\"" + esc(productImg) + "\" alt=\"" + esc(p.getName()) + "\" onerror=\"this.onerror=null;this.src='" + DEFAULT_PRODUCT_IMAGE + "'\"></div>" +
            "<div>" +
            "<h1 class=\"pd-name\">" + esc(p.getName()) + "</h1>" +
            "<div class=\"pd-price\">" + priceHtml + "</div>" +
            "<div class=\"pd-stock\">" + stockHtml + "</div>" +
            "<div class=\"pd-desc\">" + esc(p.getDescription()) + "</div>" +
            "<div class=\"pd-actions\">" +
            "<button type=\"button\" class=\"add-cart\" data-product-id=\"" + p.getId() + "\" data-product-name=\"" + esc(p.getName()) + "\" data-product-price=\"" + p.getPrice() + "\" data-product-img=\"" + esc(productImg) + "\"><i class=\"fas fa-cart-plus\"></i> Ajouter au panier</button>" +
            "<button type=\"button\" class=\"wishlist-toggle\" aria-label=\"Favoris\"><i class=\"far fa-heart\"></i><i class=\"fas fa-heart\" style=\"display:none\"></i></button>" +
            "</div></div></div>" +
            "<div class=\"pd-back\"><a href=\"/store/" + b.getSlug() + "\">\u2190 Retour aux produits</a></div>";

        int mainStart = html.indexOf("<main class=\"main\">");
        int mainEnd = html.indexOf("</main>", mainStart);
        if (mainStart == -1 || mainEnd == -1) return html;

        html = html.substring(0, mainStart + "<main class=\"main\">".length())
             + detailContent
             + html.substring(mainEnd);
        return html;
    }

    private String extractFirstImage(String images) {
        if (images == null || images.isBlank() || images.equals("[]")) return "";
        try {
            String trimmed = images.trim();
            if (trimmed.startsWith("[")) {
                String content = trimmed.substring(1, trimmed.length() - 1).trim();
                if (content.startsWith("\"")) {
                    return content.substring(1, content.indexOf("\"", 1));
                }
                return content;
            }
            return trimmed;
        } catch (Exception e) { return ""; }
    }

    private String resolveImageUrl(String url) {
        if (url == null || url.isBlank()) return DEFAULT_PRODUCT_IMAGE;
        String trimmed = url.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed;
        if (trimmed.startsWith("/")) return trimmed;
        if (trimmed.startsWith("images/") || trimmed.startsWith("uploads/")) return "/" + trimmed;
        return "/uploads/" + trimmed;
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
