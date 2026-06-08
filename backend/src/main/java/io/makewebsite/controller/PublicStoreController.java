package io.makewebsite.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.makewebsite.dto.request.ValidateCouponRequest;
import io.makewebsite.dto.response.CouponValidationResponse;
import io.makewebsite.dto.response.OrderResponse;
import io.makewebsite.dto.response.PublicCategoryResponse;
import io.makewebsite.dto.response.PublicProductResponse;
import io.makewebsite.dto.response.PublicStoreResponse;
import io.makewebsite.entity.*;
import io.makewebsite.exception.StoreFrozenException;
import io.makewebsite.repository.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.*;
import io.makewebsite.util.NetworkUtils;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
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
    private final StoreStatusGuard storeStatusGuard;
    private final BoutiqueVisitService boutiqueVisitService;
    private final StoreViewRepository storeViewRepository;
    private final ReviewRepository reviewRepository;
    private final PaymentService paymentService;
    private final CustomerService customerService;
    private final InvoiceService invoiceService;
    private final NotificationService notificationService;
    private final WebSocketService webSocketService;
    private final TelegramService telegramService;
    private final TelegramNotificationService telegramNotificationService;
    private final CaisseService caisseService;
    private final InvoicePdfService invoicePdfService;
    private final EmailService emailService;
    private final ReviewService reviewService;
    private final CouponService couponService;
    private final ObjectMapper objectMapper;
    private final TrafficRepository trafficRepository;
    private final io.makewebsite.service.GeoLocationService geoLocationService;

    // Redirect HTML serving to the shared template endpoint
    @GetMapping("/store/{slug}")
    public ResponseEntity<Void> serveStore(
            @PathVariable String slug,
            @RequestParam(value = "product_id", required = false) String productId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        String redirectUrl = "/store/" + slug;
        if (productId != null && !productId.isBlank()) {
            redirectUrl += "?product_id=" + productId;
        }
        return ResponseEntity.status(302).header(HttpHeaders.LOCATION, redirectUrl).build();
    }

    // ---- Clean JSON API (plural /stores/) ----

    @Transactional(readOnly = true)
    @GetMapping("/stores/{slug}")
    public ResponseEntity<PublicStoreResponse> getStoreJson(
            @PathVariable String slug,
            HttpServletRequest request,
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestHeader(value = "X-Visitor-Id", required = false) String visitorId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();

        long totalViews = storeViewRepository.countByBoutiqueId(b.getId());
        log.info("getStoreJson: slug={} boutiqueId={}", slug, b.getId());
        log.debug("Total views for slug={}: {}", slug, totalViews);

        List<PublicProductResponse> products = productRepository.findPublicProductsWithCategory(b.getId())
                .stream().map(this::toPublicProductResponse).toList();
        log.info("getStoreJson: mapped {} products for slug={}", products.size(), slug);

        List<PublicCategoryResponse> categories = categoryRepository.findByBoutiqueIdOrderBySortOrder(b.getId())
                .stream().map(c -> PublicCategoryResponse.builder()
                        .id(c.getId()).name(c.getName()).slug(c.getSlug())
                        .productCount(productRepository.countByBoutiqueIdAndCategoryIdAndIsActiveTrue(b.getId(), c.getId()))
                        .build())
                .toList();
        log.info("getStoreJson: mapped {} categories for slug={}", categories.size(), slug);

        BigDecimal minPrice = productRepository.findMinPriceByBoutiqueIdAndIsActiveTrue(b.getId());
        long productCount = productRepository.countByBoutiqueIdAndIsActiveTrue(b.getId());
        String publicationStatus;
        if ("FROZEN".equals(b.getStoreStatus())) publicationStatus = "FROZEN";
        else if ("SUSPENDED".equals(b.getStoreStatus())) publicationStatus = "SUSPENDED";
        else if (Boolean.FALSE.equals(b.getIsPublished())) publicationStatus = "DRAFT";
        else publicationStatus = "PUBLISHED";

        PublicStoreResponse response = PublicStoreResponse.builder()
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
                .enableJax(Boolean.TRUE.equals(b.getEnableJax()))
                .enableIntigo(Boolean.TRUE.equals(b.getEnableIntigo()))
                .enableAdeex(Boolean.TRUE.equals(b.getEnableAdeex()))
                .facebookUrl(b.getFacebookUrl()).instagramUrl(b.getInstagramUrl())
                .tiktokUrl(b.getTiktokUrl()).whatsappNumber(b.getWhatsappNumber())
                .publicationStatus(publicationStatus)
                .freezeReason(b.getFreezeReason())
                .publicUrl("/store/" + b.getSlug())
                .minPrice(minPrice)
                .productCount(productCount)
                .categories(categories)
                .products(products)
                .build();

        log.info("getStoreJson: mapping success for slug={}", slug);
        return ResponseEntity.ok(response);
    }

    @Transactional(readOnly = true)
    @GetMapping("/stores/{slug}/products")
    public ResponseEntity<List<PublicProductResponse>> listProductsJson(@PathVariable String slug) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<PublicProductResponse> products = productRepository.findPublicProductsWithCategory(b.getId())
                .stream().map(this::toPublicProductResponse).toList();
        log.info("listProductsJson: slug={} products={}", slug, products.size());
        return ResponseEntity.ok(products);
    }

    @Transactional(readOnly = true)
    @GetMapping("/stores/{slug}/products/{productId}")
    public ResponseEntity<PublicProductResponse> getProductJson(
            @PathVariable String slug, @PathVariable UUID productId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        Product p = productRepository.findByIdWithBoutiqueAndCategory(productId).orElse(null);
        if (p == null || !p.getIsActive() || !p.getBoutique().getId().equals(b.getId())) return ResponseEntity.notFound().build();
        log.info("getProductJson: slug={} productId={} name={}", slug, productId, p.getName());
        return ResponseEntity.ok(toPublicProductResponse(p));
    }

    @Transactional(readOnly = true)
    @GetMapping("/stores/{slug}/products/{productId}/reviews")
    public ResponseEntity<Map<String, Object>> getProductReviews(
            @PathVariable String slug, @PathVariable UUID productId) {
        log.info("getProductReviews: slug={} productId={}", slug, productId);

        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();

        Product p = productRepository.findById(productId).orElse(null);
        if (p == null || !p.getBoutique().getId().equals(b.getId()) || Boolean.FALSE.equals(p.getIsActive())) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Produit introuvable"));
        }

        List<Review> reviews = reviewRepository.findByProductIdAndStatusOrderByCreatedAtDesc(productId, ReviewStatus.APPROVED);
        double averageRating = reviews.isEmpty() ? 0 : reviews.stream().mapToInt(Review::getRating).average().orElse(0);

        log.info("getProductReviews: slug={} productId={} count={} avg={}", slug, productId, reviews.size(), averageRating);

        List<Map<String, Object>> list = reviews.stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", r.getId());
            m.put("customerName", r.getCustomerName() != null ? r.getCustomerName() : "");
            m.put("rating", r.getRating());
            m.put("comment", r.getComment() != null ? r.getComment() : "");
            m.put("createdAt", r.getCreatedAt());
            return m;
        }).toList();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("content", list);
        data.put("totalReviews", reviews.size());
        data.put("averageRating", averageRating);

        return ResponseEntity.ok(Map.of("success", true, "data", data));
    }

    @Transactional
    @PostMapping("/stores/{slug}/products/{productId}/reviews")
    public ResponseEntity<Map<String, Object>> submitProductReview(
            @PathVariable String slug, @PathVariable UUID productId,
            @RequestBody Map<String, Object> body) {
        log.info("submitProductReview: slug={} productId={}", slug, productId);

        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Boutique introuvable"));
        }
        try {
            storeStatusGuard.requireActive(b);
        } catch (StoreFrozenException e) {
            return ResponseEntity.status(423).body(Map.of("success", false, "message", e.getMessage(), "code", "STORE_FROZEN"));
        }

        Product product = productRepository.findById(productId).orElse(null);
        if (product == null || !product.getBoutique().getId().equals(b.getId()) || Boolean.FALSE.equals(product.getIsActive())) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Produit introuvable"));
        }

        String customerName = (String) body.get("customerName");
        Integer rating = body.get("rating") != null ? ((Number) body.get("rating")).intValue() : null;
        String comment = (String) body.get("comment");

        if (customerName == null || customerName.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Veuillez entrer votre nom"));
        }
        if (rating == null || rating < 1 || rating > 5) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Note invalide (1-5)"));
        }

        Review r = reviewService.createReview(productId, null, customerName, rating, comment);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("success", true);
        result.put("id", r.getId());
        result.put("message", "Merci pour votre avis. Il sera affiché après validation par le marchand.");
        return ResponseEntity.ok(result);
    }

    @GetMapping("/stores/{slug}/categories")
    public ResponseEntity<List<PublicCategoryResponse>> getCategoriesJson(@PathVariable String slug) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<Category> cats = categoryRepository.findByBoutiqueIdOrderBySortOrder(b.getId());
        return ResponseEntity.ok(cats.stream().map(c -> PublicCategoryResponse.builder()
                .id(c.getId()).name(c.getName()).slug(c.getSlug())
                .productCount(productRepository.countByBoutiqueIdAndCategoryIdAndIsActiveTrue(b.getId(), c.getId()))
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

    @Transactional(readOnly = true)
    @GetMapping("/store/{slug}/products")
    public ResponseEntity<Map<String, Object>> listProducts(
            @PathVariable String slug,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(required = false) UUID categoryId) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();
        List<Product> products = productRepository.findPublicProductsWithCategory(b.getId());
        if (categoryId != null) {
            products = products.stream()
                    .filter(p -> p.getCategory() != null && p.getCategory().getId().equals(categoryId))
                    .toList();
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
    @Transactional
    @PostMapping("/store/{slug}/orders")
    @SuppressWarnings("unchecked")
    public ResponseEntity<Map<String, Object>> createOrder(
            @PathVariable String slug,
            @RequestBody Map<String, Object> body) {
        log.info("Public checkout received for slug={}", slug);

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
        String deliveryCompany = (String) body.get("deliveryCompany");
        List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

        if (fullName == null || phone == null || billingAddress == null || city == null || items == null || items.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Champs obligatoires manquants"));
        }

        if ("paypal".equalsIgnoreCase(paymentMethod)) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "PayPal n'est plus disponible", "code", "PAYPAL_DISABLED"));
        }

        log.info("Public checkout: slug={}, boutiqueId={}, customer phone={}, email={}",
                slug, b.getId(), phone, email != null ? email : "none");

        BigDecimal subtotal = BigDecimal.ZERO;
        List<OrderItem> orderItems = new ArrayList<>();

        for (Map<String, Object> item : items) {
            String pid = item.get("productId").toString();
            int qty = Integer.parseInt(item.get("quantity").toString());
                Product product = productRepository.findByIdWithBoutique(UUID.fromString(pid)).orElse(null);
            if (product == null || Boolean.FALSE.equals(product.getIsActive())) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Produit introuvable", "code", "PRODUCT_NOT_FOUND"));
            }
            if (!product.getBoutique().getId().equals(b.getId())) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Produit invalide pour cette boutique", "code", "PRODUCT_MISMATCH"));
            }
            if (product.getStock() != null && product.getStock() < qty) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Stock insuffisant pour " + product.getName(), "code", "INSUFFICIENT_STOCK"));
            }
            BigDecimal up = product.getComparePrice() != null && product.getComparePrice().compareTo(BigDecimal.ZERO) > 0 ? product.getComparePrice() : product.getPrice();
            subtotal = subtotal.add(up.multiply(BigDecimal.valueOf(qty)));
            orderItems.add(OrderItem.builder()
                    .product(product).productName(product.getName())
                    .unitPrice(up).quantity(qty)
                    .subtotal(up.multiply(BigDecimal.valueOf(qty)))
                    .build());
            product.setStock(product.getStock() != null ? product.getStock() - qty : 0);
            int remaining = product.getStock() != null ? product.getStock() : 0;

            if (remaining > 5) {
                product.setLowStockAlertSent(false);
                product.setOutOfStockAlertSent(false);
            } else if (remaining > 0 && remaining <= 5) {
                if (!Boolean.TRUE.equals(product.getLowStockAlertSent())) {
                    telegramNotificationService.notifyLowStock(product, remaining);
                    product.setLowStockAlertSent(true);
                }
                product.setOutOfStockAlertSent(false);
            } else if (remaining <= 0) {
                if (!Boolean.TRUE.equals(product.getOutOfStockAlertSent())) {
                    telegramNotificationService.notifyOutOfStock(product);
                    product.setOutOfStockAlertSent(true);
                }
                product.setLowStockAlertSent(false);
            }
            productRepository.save(product);
        }

        BigDecimal shipping = BigDecimal.valueOf(b.getDeliveryFees() != null ? b.getDeliveryFees() : 7.0);
        BigDecimal discount = BigDecimal.ZERO;
        String couponCode = (String) body.get("couponCode");
        if (couponCode != null && !couponCode.isBlank()) {
            ValidateCouponRequest validateReq = ValidateCouponRequest.builder()
                    .boutiqueId(b.getId())
                    .code(couponCode)
                    .orderAmount(subtotal)
                    .build();
            CouponValidationResponse validation = couponService.validateCoupon(validateReq);
            if (!validation.getValid()) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", validation.getMessage()));
            }
            discount = validation.getDiscountAmount();
        }
        BigDecimal total = subtotal.add(shipping).subtract(discount);
        String orderNum = "PUB-" + System.currentTimeMillis() % 1000000;

        // Create or update customer
        Customer customer = customerService.findOrCreateCustomer(
                b.getId(), fullName, email, phone, billingAddress, city,
                null, null, null);

        if (customer.getId() != null) {
            log.info("Customer {} updated/created for boutique {}", customer.getId(), b.getId());
        } else {
            log.info("Customer created for boutique {}", b.getId());
        }

        Order order = Order.builder()
                .boutique(b)
                .customer(customer)
                .orderNumber(orderNum)
                .status("PENDING")
                .subtotal(subtotal)
                .shippingFee(shipping)
                .discount(discount)
                .couponCode(couponCode)
                .total(total)
                .paymentMethod(paymentMethod)
                .paymentStatus("UNPAID")
                .customerName(fullName)
                .customerPhone(phone)
                .customerEmail(email)
                .city(city)
                .shippingAddress(billingAddress + ", " + city)
                .notes(notes)
                .deliveryCompany(deliveryCompany)
                .build();
        order.setItems(orderItems);
        order = orderRepository.save(order);

        log.info("Order created: orderId={}, orderNumber={}", order.getId(), orderNum);

        // Generate invoice
        try {
            invoiceService.generateInvoice(order.getId());
        } catch (Exception e) {
            log.warn("Failed to generate invoice for order {}: {}", order.getId(), e.getMessage());
        }

        // Send confirmation email
        try {
            if (email != null && !email.isBlank()
                    && !Boolean.TRUE.equals(order.getConfirmationEmailSent())) {
                Invoice invoice = invoiceService.findByOrderId(order.getId());
                if (invoice != null) {
                    byte[] pdfBytes = invoicePdfService.generatePdf(order, b, invoice);
                    String subject = "Commande confirm\u00e9e - " + order.getOrderNumber();
                    StringBuilder itemsHtml = new StringBuilder();
                    for (OrderItem oi : orderItems) {
                        String pn = oi.getProductName() != null ? oi.getProductName().replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;") : "Produit";
                        itemsHtml.append("<tr>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px\">").append(pn).append("</td>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px;text-align:center\">").append(oi.getQuantity()).append("</td>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px;text-align:right\">").append(oi.getUnitPrice().stripTrailingZeros().toPlainString()).append("</td>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px;text-align:right\">").append(oi.getSubtotal().stripTrailingZeros().toPlainString()).append("</td>")
                            .append("</tr>");
                    }
                    String subtotalStr = order.getSubtotal().stripTrailingZeros().toPlainString();
                    String shippingFeeStr = order.getShippingFee().stripTrailingZeros().toPlainString();
                    String totalStr = order.getTotal().stripTrailingZeros().toPlainString();
                    String htmlBody = emailService.buildOrderConfirmationHtml(
                            b.getName(), order.getOrderNumber(),
                            fullName, email, phone,
                            billingAddress + ", " + city, paymentMethod,
                            b.getCurrency(), itemsHtml.toString(),
                            subtotalStr, shippingFeeStr, totalStr);
                    emailService.sendOrderConfirmation(email, subject, htmlBody, pdfBytes,
                            "facture-" + order.getOrderNumber() + ".pdf");
                    order.setConfirmationEmailSent(true);
                    orderRepository.save(order);
                    log.info("Confirmation email queued for order {}", order.getOrderNumber());
                }
            }
        } catch (Exception e) {
            log.warn("Failed to send confirmation email for order {}: {}", order.getOrderNumber(), e.getMessage());
        }

        // Update customer aggregation
        try {
            customerService.updateCustomerAggregation(customer, total);
        } catch (Exception e) {
            log.warn("Failed to update customer aggregation: {}", e.getMessage());
        }

        // Send notifications
        try {
            User owner = b.getUser();
            String message = "Nouvelle commande " + orderNum + " - " + total + " TND";
            notificationService.createNotification(owner.getId(), "Nouvelle commande", message, "NEW_ORDER");
            OrderResponse responseDto = OrderResponse.builder()
                    .id(order.getId()).boutiqueId(b.getId())
                    .customerId(customer.getId())
                    .customerName(fullName).customerPhone(phone).customerEmail(email)
                    .orderNumber(orderNum).status("PENDING")
                    .subtotal(subtotal).shippingFee(shipping).discount(discount).couponCode(couponCode).total(total)
                    .paymentMethod(paymentMethod).paymentStatus("UNPAID")
                    .shippingAddress(billingAddress + ", " + city).city(city)
                    .notes(notes)
                    .build();
            webSocketService.sendNewOrderNotification(b.getId(), responseDto);
            webSocketService.sendCaisseOrderUpdate(b.getId(), responseDto);
            telegramNotificationService.notifyNewOrder(order);
            caisseService.recordActivity(b.getId(), null, "Client",
                    "ORDER_CREATED", "Commande " + orderNum + " créée - " + total + " TND");
        } catch (Exception e) {
            log.warn("Failed to send order notifications: {}", e.getMessage());
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("success", true);
        response.put("orderId", order.getId().toString());
        response.put("orderNumber", orderNum);
        response.put("subtotal", subtotal);
        response.put("shipping", shipping);
        response.put("discount", discount);
        response.put("total", total);
        response.put("customerName", fullName);
        response.put("address", billingAddress);
        response.put("city", city);
        response.put("phone", phone);
        response.put("paymentMethod", paymentMethod);

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
            JsonNode session = paymentService.createPublicStripeSession(orderNumber, b.getId());
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

    @PostMapping("/stores/{slug}/coupons/validate")
    public ResponseEntity<Map<String, Object>> validateCoupon(
            @PathVariable String slug,
            @RequestBody Map<String, Object> body) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.badRequest().body(Map.of("valid", false, "message", "Boutique introuvable"));

        String code = (String) body.get("code");
        BigDecimal subtotal = body.get("subtotal") != null
                ? BigDecimal.valueOf(((Number) body.get("subtotal")).doubleValue())
                : BigDecimal.ZERO;

        if (code == null || code.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("valid", false, "message", "Code promo requis"));
        }

        ValidateCouponRequest validateReq = ValidateCouponRequest.builder()
                .boutiqueId(b.getId())
                .code(code)
                .orderAmount(subtotal)
                .build();

        CouponValidationResponse validation = couponService.validateCouponOnly(validateReq);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("valid", validation.getValid());
        response.put("discountAmount", validation.getDiscountAmount());
        response.put("finalTotal", validation.getFinalAmount());
        response.put("message", validation.getMessage());

        return ResponseEntity.ok(response);
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

    @PostMapping("/stores/{slug}/visit")
    public ResponseEntity<Map<String, Object>> recordStoreVisit(
            @PathVariable String slug,
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Boutique introuvable"));

        Double lat = body.get("latitude") != null ? ((Number) body.get("latitude")).doubleValue() : null;
        Double lng = body.get("longitude") != null ? ((Number) body.get("longitude")).doubleValue() : null;
        String visitorId = (String) body.get("visitorId");
        String referrer = (String) body.get("referrer");
        String ua = (String) body.get("userAgent");
        if (ua == null) ua = request.getHeader("User-Agent");
        if (referrer == null) referrer = request.getHeader("Referer");

        log.info("Visit received for slug={} boutiqueId={} lat={} lng={} visitorId={}",
                slug, b.getId(), lat, lng, visitorId);

        // Resolve real client IP from headers (X-Forwarded-For, X-Real-IP, etc.)
        String clientIp = NetworkUtils.resolveClientIp(request);

        log.info("recordStoreVisit: slug={} boutiqueId={} clientIp={}", slug, b.getId(), clientIp);

        // Always resolve country/city from IP geolocation (needed for top countries/cities analytics)
        // Browser-provided lat/lng takes precedence for map coordinates
        String country = "Inconnu";
        String city = "Inconnu";
        String ipHash = hashIp(clientIp);
        try {
            var geo = geoLocationService.locate(clientIp);
            if (geo.isPresent()) {
                var g = geo.get();
                country = g.country() != null ? g.country() : "Inconnu";
                city = g.city() != null ? g.city() : "Inconnu";
                if (lat == null) lat = g.latitude();
                if (lng == null) lng = g.longitude();
                log.info("IP geolocation: country={} city={} browserLat={} browserLng={} geoLat={} geoLng={}",
                        country, city, body.get("latitude"), body.get("longitude"), g.latitude(), g.longitude());
            }
        } catch (Exception e) {
            log.warn("IP geolocation failed for slug={}: {}", slug, e.getMessage());
        }

        log.info("recordStoreVisit final: slug={} boutiqueId={} ip={} country={} city={}",
                slug, b.getId(), clientIp, country, city);

        boutiqueVisitService.recordVisit(b.getId(), b.getSlug(), clientIp, ua, visitorId, referrer, lat, lng);

        // Create/update a Visitor record so map data shows this visit
        try {
            String browser = detectBrowser(ua);
            Visitor existing = trafficRepository.findByBoutiqueIdAndIpHash(b.getId(), ipHash).orElse(null);
            if (existing != null) {
                existing.setTotalVisits(existing.getTotalVisits() + 1);
                existing.setLastActivityAt(java.time.LocalDateTime.now());
                existing.setIsActive(true);
                existing.setCountry(country);
                existing.setCity(city);
                existing.setLatitude(lat);
                existing.setLongitude(lng);
                existing.setBrowser(browser);
                existing.setUserAgent(ua);
                existing.setReferralSource(referrer);
                trafficRepository.save(existing);
                log.info("Visitor updated for boutiqueId={} ipHash={} lat={} lng={} country={} city={}",
                        b.getId(), ipHash, lat, lng, country, city);
            } else {
                Visitor v = Visitor.builder()
                        .boutiqueId(b.getId())
                        .ipHash(ipHash)
                        .country(country)
                        .city(city)
                        .latitude(lat)
                        .longitude(lng)
                        .browser(browser)
                        .userAgent(ua)
                        .referralSource(referrer)
                        .totalVisits(1L)
                        .isActive(true)
                        .build();
                trafficRepository.save(v);
                log.info("Visitor created for boutiqueId={} ipHash={} lat={} lng={} country={} city={}",
                        b.getId(), ipHash, lat, lng, country, city);
            }
        } catch (Exception e) {
            log.warn("Failed to create Visitor record for slug={}: {}", slug, e.getMessage());
        }

        long totalViews = storeViewRepository.countByBoutiqueId(b.getId());
        log.info("Visit complete for slug={}: totalViews={}", slug, totalViews);
        return ResponseEntity.ok(Map.of("success", true, "totalViews", totalViews, "lat", lat, "lng", lng));
    }

    private String hashIp(String ip) {
        if (ip == null) return "unknown";
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(ip.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString().substring(0, 32);
        } catch (java.security.NoSuchAlgorithmException e) {
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

    private void trackStoreVisit(Boutique boutique, HttpServletRequest request) {
        String clientIp = NetworkUtils.resolveClientIp(request);
        boutiqueVisitService.recordVisit(boutique.getId(), boutique.getSlug(),
                clientIp, request.getHeader("User-Agent"), null,
                request.getHeader("Referer"), null, null);
    }

}
