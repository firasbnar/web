package io.makewebsite.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.makewebsite.dto.response.PublicCategoryResponse;
import io.makewebsite.dto.response.PublicProductResponse;
import io.makewebsite.dto.response.PublicStoreResponse;
import io.makewebsite.entity.*;
import io.makewebsite.exception.StoreFrozenException;
import io.makewebsite.repository.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.BoutiqueVisitService;
import io.makewebsite.service.PaymentService;
import io.makewebsite.service.StoreGeneratorService;
import io.makewebsite.service.StoreStatusGuard;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@Slf4j
@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicStoreController {

    private static final Set<String> RESERVED_SLUGS = Set.of(
        "login", "register", "signup", "error", "api", "store", "stores",
        "checkout", "flutter", "assets", "uploads", "ws", "favicon",
        "admin", "super-admin", "superadmin", "dashboard", "plans",
        "home", "settings", "profile", "notifications", "messages",
        "orders", "products", "categories", "customers", "team",
        "analytics", "traffic", "pos", "reviews", "coupons",
        "delivery", "subscription", "billing", "payment",
        "index", "health", "status", "about", "contact",
        "privacy", "terms", "legal", "help", "support"
    );

    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final OrderRepository orderRepository;
    private final StoreGeneratorService storeGeneratorService;
    private final StoreStatusGuard storeStatusGuard;
    private final BoutiqueVisitService boutiqueVisitService;
    private final StoreViewRepository storeViewRepository;
    private final PaymentService paymentService;
    private final ObjectMapper objectMapper;

    // Serve full generated store HTML
    @GetMapping("/store/{slug}")
    public ResponseEntity<String> serveStore(@PathVariable String slug, HttpServletRequest request) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        String html = storeGeneratorService.loadHtml(slug);
        if (html == null) {
            storeGeneratorService.regenerate(b.getId());
            html = b.getGeneratedHtml();
            if (html == null) return ResponseEntity.notFound().build();
        }
        trackStoreVisit(b, request);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                .body(html);
    }

    // ---- Clean JSON API (plural /stores/) ----

    @GetMapping("/stores/{slug}")
    public ResponseEntity<PublicStoreResponse> getStoreJson(
            @PathVariable String slug,
            HttpServletRequest request,
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestHeader(value = "X-Visitor-Id", required = false) String visitorId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();

        // Skip counting if the authenticated user is the boutique owner
        if (principal != null) {
            try {
                UUID ownerId = boutiqueRepository.findOwnerIdByBoutiqueId(b.getId());
                if (ownerId != null && ownerId.equals(principal.getUserId())) {
                    log.debug("Owner visit, skipping view count for slug={}", slug);
                } else {
                    boutiqueVisitService.recordVisit(b.getId(), b.getSlug(), request.getRemoteAddr(), request.getHeader("User-Agent"), visitorId);
                }
            } catch (Exception e) {
                log.warn("Owner check failed for slug={}, recording visit: {}", slug, e.getMessage());
                boutiqueVisitService.recordVisit(b.getId(), b.getSlug(), request.getRemoteAddr(), request.getHeader("User-Agent"), visitorId);
            }
        } else {
            boutiqueVisitService.recordVisit(b.getId(), b.getSlug(), request.getRemoteAddr(), request.getHeader("User-Agent"), visitorId);
        }

        long totalViews = storeViewRepository.countByBoutiqueId(b.getId());
        log.info("Total views for slug={}: {} (after recording visit)", slug, totalViews);
        return ResponseEntity.ok(toPublicStoreResponse(b));
    }

    @GetMapping("/stores/{slug}/products")
    public ResponseEntity<List<PublicProductResponse>> listProductsJson(@PathVariable String slug) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<Product> products = productRepository.findByBoutiqueIdAndIsActiveTrue(b.getId());
        return ResponseEntity.ok(products.stream().map(this::toPublicProductResponse).toList());
    }

    @GetMapping("/stores/{slug}/products/{productId}")
    public ResponseEntity<PublicProductResponse> getProductJson(
            @PathVariable String slug, @PathVariable UUID productId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        Product p = productRepository.findById(productId).orElse(null);
        if (p == null || !p.getIsActive()) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(toPublicProductResponse(p));
    }

    @GetMapping("/stores/{slug}/categories")
    public ResponseEntity<List<PublicCategoryResponse>> getCategoriesJson(@PathVariable String slug) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<Category> cats = categoryRepository.findByBoutiqueIdOrderBySortOrder(b.getId());
        return ResponseEntity.ok(cats.stream().map(c -> PublicCategoryResponse.builder()
                .id(c.getId()).name(c.getName()).slug(c.getSlug())
                .productCount(productRepository.countByBoutiqueIdAndCategoryId(b.getId(), c.getId()))
                .build()).toList());
    }

    // Check slug availability (public)
    @PostMapping("/check-slug")
    public ResponseEntity<Map<String, Object>> checkSlug(@RequestBody Map<String, String> body) {
        String slug = body.get("slug");
        if (slug == null || slug.isBlank())
            return ResponseEntity.ok(Map.of("available", false, "message", "Slug requis"));
        slug = slug.toLowerCase().trim().replaceAll("\\s+", "-").replaceAll("[^a-z0-9-]", "");
        boolean reserved = RESERVED_SLUGS.contains(slug);
        boolean exists = boutiqueRepository.existsBySlug(slug);
        return ResponseEntity.ok(Map.of("available", !reserved && !exists, "reserved", reserved, "exists", exists));
    }

    // ---- Backward-compatible JSON endpoints (singular /store/) ----

    @GetMapping("/store/{slug}/products")
    public ResponseEntity<Map<String, Object>> listProducts(
            @PathVariable String slug,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(required = false) UUID categoryId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<Product> products;
        if (categoryId != null) {
            products = productRepository.findByBoutiqueIdAndIsActiveTrue(b.getId()).stream()
                    .filter(p -> p.getCategory() != null && p.getCategory().getId().equals(categoryId))
                    .toList();
        } else {
            products = productRepository.findByBoutiqueIdAndIsActiveTrue(b.getId());
        }
        List<Map<String, Object>> list = products.stream().map(p -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", p.getId()); m.put("name", p.getName());
            m.put("price", p.getPrice()); m.put("comparePrice", p.getComparePrice());
            m.put("images", p.getImages()); m.put("stock", p.getStock());
            m.put("description", p.getDescription());
            return m;
        }).toList();
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("products", list); res.put("total", list.size());
        return ResponseEntity.ok(res);
    }

    @GetMapping("/store/{slug}/products/{productId}")
    public ResponseEntity<Map<String, Object>> getProduct(
            @PathVariable String slug, @PathVariable UUID productId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        Product p = productRepository.findById(productId).orElse(null);
        if (p == null || !p.getIsActive()) return ResponseEntity.notFound().build();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId()); m.put("name", p.getName());
        m.put("price", p.getPrice()); m.put("comparePrice", p.getComparePrice());
        m.put("images", p.getImages()); m.put("stock", p.getStock());
        m.put("description", p.getDescription()); m.put("descriptionHtml", p.getDescriptionHtml());
        m.put("colors", p.getColors()); m.put("sizes", p.getSizes());
        return ResponseEntity.ok(m);
    }

    @GetMapping("/store/{slug}/categories")
    public ResponseEntity<List<Map<String, Object>>> getCategories(@PathVariable String slug) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<Map<String, Object>> list = categoryRepository.findByBoutiqueIdOrderBySortOrder(b.getId())
                .stream().map(c -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", c.getId()); m.put("name", c.getName());
                    m.put("slug", c.getSlug()); m.put("imageUrl", c.getImageUrl());
                    return m;
                }).toList();
        return ResponseEntity.ok(list);
    }

    // Create order (public - no auth)
    @PostMapping("/store/{slug}/orders")
    @SuppressWarnings("unchecked")
    public ResponseEntity<Map<String, Object>> createOrder(
            @PathVariable String slug,
            @RequestBody Map<String, Object> body) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Store not found"));
        try {
            storeStatusGuard.requireActive(b);
        } catch (StoreFrozenException e) {
            return ResponseEntity.status(423).body(Map.of("success", false, "message", e.getMessage(), "code", "STORE_FROZEN"));
        }
        String fullName = (String) body.get("fullName");
        String phone = (String) body.get("phone");
        String billingAddress = (String) body.get("billingAddress");
        String city = (String) body.get("city");
        String paymentMethod = (String) body.get("paymentMethod");
        String email = (String) body.get("email");
        String notes = (String) body.get("notes");
        List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

        if (fullName == null || phone == null || billingAddress == null || city == null || items == null || items.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Champs obligatoires manquants"));
        }

        BigDecimal subtotal = BigDecimal.ZERO;
        List<OrderItem> orderItems = new ArrayList<>();

        for (Map<String, Object> item : items) {
            String pid = item.get("productId").toString();
            int qty = Integer.parseInt(item.get("quantity").toString());
            Product product = productRepository.findById(UUID.fromString(pid)).orElse(null);
            if (product == null || Boolean.FALSE.equals(product.getIsActive())) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Produit introuvable", "code", "PRODUCT_NOT_FOUND"));
            }
            if (!product.getBoutique().getId().equals(b.getId())) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Produit invalide pour cette boutique", "code", "PRODUCT_MISMATCH"));
            }
            if (product.getStock() != null && product.getStock() < qty) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Stock insuffisant pour " + product.getName(), "code", "INSUFFICIENT_STOCK"));
            }
            BigDecimal up = product.getPrice();
            subtotal = subtotal.add(up.multiply(BigDecimal.valueOf(qty)));
            orderItems.add(OrderItem.builder()
                    .product(product).productName(product.getName())
                    .unitPrice(up).quantity(qty)
                    .subtotal(up.multiply(BigDecimal.valueOf(qty)))
                    .build());
            product.setStock(product.getStock() != null ? product.getStock() - qty : 0);
            productRepository.save(product);
        }

        BigDecimal shipping = BigDecimal.valueOf(b.getDeliveryFees() != null ? b.getDeliveryFees() : 7.0);
        BigDecimal total = subtotal.add(shipping);
        String orderNum = "PUB-" + System.currentTimeMillis() % 1000000;

        Order order = Order.builder()
                .boutique(b)
                .orderNumber(orderNum)
                .status("PENDING")
                .subtotal(subtotal)
                .shippingFee(shipping)
                .total(total)
                .paymentMethod(paymentMethod)
                .paymentStatus("UNPAID")
                .shippingAddress(billingAddress + ", " + city)
                .notes(notes)
                .build();
        order.setItems(orderItems);
        order = orderRepository.save(order);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("success", true);
        response.put("orderId", order.getId().toString());
        response.put("orderNumber", orderNum);
        response.put("total", total);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/stores/{slug}/payments/stripe/session")
    public ResponseEntity<Map<String, Object>> createStripeSession(
            @PathVariable String slug,
            @RequestBody Map<String, Object> body) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Boutique introuvable"));
        try {
            storeStatusGuard.requireActive(b);
        } catch (StoreFrozenException e) {
            return ResponseEntity.status(423).body(Map.of("success", false, "message", e.getMessage(), "code", "STORE_FROZEN"));
        }
        String orderNumber = (String) body.get("orderNumber");
        if (orderNumber == null) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Numéro de commande requis"));
        }
        Order order = orderRepository.findByOrderNumber(orderNumber).orElse(null);
        if (order == null) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Commande introuvable"));
        }
        try {
            JsonNode session = paymentService.createPublicStripeSession(order, b.getId());
            return ResponseEntity.ok(Map.of(
                "success", true,
                "sessionId", session.get("sessionId").asText(),
                "sessionUrl", session.get("sessionUrl").asText()
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", e.getMessage()));
        }
    }

    // Newsletter subscribe
    @PostMapping("/subscribe")
    public ResponseEntity<Map<String, Object>> subscribe(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        if (email == null || email.isBlank())
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Email requis"));
        // Simple: just acknowledge (could store in DB)
        return ResponseEntity.ok(Map.of("success", true, "message", "Inscription réussie"));
    }

    // Check name availability (public)
    @PostMapping("/check-name")
    public ResponseEntity<Map<String, Object>> checkName(@RequestBody Map<String, String> body) {
        String name = body.get("name");
        String currentId = body.get("currentBoutiqueId");
        Optional<Boutique> existing = boutiqueRepository.findBySlug(name != null ? name.toLowerCase() : "");
        boolean available = existing.isEmpty() || (currentId != null && existing.get().getId().toString().equals(currentId));
        return ResponseEntity.ok(Map.of("available", available));
    }

    private PublicStoreResponse toPublicStoreResponse(Boutique b) {
        BigDecimal minPrice = productRepository.findMinPriceByBoutiqueIdAndIsActiveTrue(b.getId());
        long productCount = productRepository.countByBoutiqueId(b.getId());
        String publicationStatus;
        if ("FROZEN".equals(b.getStoreStatus())) publicationStatus = "FROZEN";
        else if ("SUSPENDED".equals(b.getStoreStatus())) publicationStatus = "SUSPENDED";
        else if (Boolean.FALSE.equals(b.getIsPublished())) publicationStatus = "DRAFT";
        else publicationStatus = "PUBLISHED";

        List<PublicProductResponse> products = productRepository.findByBoutiqueIdAndIsActiveTrue(b.getId())
                .stream().map(this::toPublicProductResponse).toList();

        return PublicStoreResponse.builder()
                .id(b.getId()).name(b.getName()).slug(b.getSlug())
                .logoUrl(b.getLogoUrl()).bannerUrl(b.getBannerUrl())
                .description(b.getDescription())
                .email(b.getEmail()).phone(b.getPhone()).address(b.getAddress())
                .primaryColor(b.getPrimaryColor()).secondaryColor(b.getSecondaryColor())
                .headerColor(b.getHeaderColor()).footerColor(b.getFooterColor())
                .bodyColor(b.getBodyColor()).cardProductColor(b.getCardProductColor())
                .buttonColor(b.getButtonColor()).topBarColor(b.getTopBarColor())
                .textColor(b.getTextColor()).fontFamily(b.getFontFamily())
                .currency(b.getCurrency()).language(b.getLanguage())
                .announcementText(b.getAnnouncementText())
                .deliveryFees(b.getDeliveryFees())
                .cashOnDelivery(b.getCashOnDelivery())
                .simpleCheckout(b.getSimpleCheckout())
                .konnectActive("active".equals(b.getKonnectStatus()))
                .d17Active("active".equals(b.getD17Status()))
                .facebookUrl(b.getFacebookUrl()).instagramUrl(b.getInstagramUrl())
                .tiktokUrl(b.getTiktokUrl()).whatsappNumber(b.getWhatsappNumber())
                .publicationStatus(publicationStatus)
                .freezeReason(b.getFreezeReason())
                .publicUrl("/store/" + b.getSlug())
                .minPrice(minPrice)
                .productCount(productCount)
                .categories(categoryRepository.findByBoutiqueIdOrderBySortOrder(b.getId()).stream()
                    .map(c -> PublicCategoryResponse.builder()
                        .id(c.getId()).name(c.getName()).slug(c.getSlug())
                        .productCount(productRepository.countByBoutiqueIdAndCategoryId(b.getId(), c.getId()))
                        .build())
                    .toList())
                .products(products)
                .build();
    }

    private PublicProductResponse toPublicProductResponse(Product p) {
        String stockStatus;
        if (p.getStock() == null || p.getStock() <= 0) stockStatus = "OUT_OF_STOCK";
        else if (p.getStock() <= 5) stockStatus = "LOW_STOCK";
        else stockStatus = "IN_STOCK";

        return PublicProductResponse.builder()
                .id(p.getId()).name(p.getName())
                .description(p.getDescription())
                .price(p.getPrice())
                .promotionalPrice(p.getComparePrice() != null && p.getComparePrice().compareTo(BigDecimal.ZERO) > 0
                    ? p.getComparePrice() : null)
                .images(p.getImages())
                .colors(p.getColors()).sizes(p.getSizes())
                .stock(p.getStock()).stockStatus(stockStatus)
                .categoryId(p.getCategory() != null ? p.getCategory().getId() : null)
                .categoryName(p.getCategory() != null ? p.getCategory().getName() : null)
                .descriptionHtml(p.getDescriptionHtml())
                .createdAt(p.getCreatedAt())
                .build();
    }

    private void trackStoreVisit(Boutique boutique, HttpServletRequest request) {
        boutiqueVisitService.recordVisit(boutique.getId(), boutique.getSlug(), request.getRemoteAddr(), request.getHeader("User-Agent"), null);
    }
}
