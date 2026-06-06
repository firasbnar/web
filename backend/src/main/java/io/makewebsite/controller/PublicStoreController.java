package io.makewebsite.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.makewebsite.dto.response.OrderResponse;
import io.makewebsite.dto.response.PublicCategoryResponse;
import io.makewebsite.dto.response.PublicProductResponse;
import io.makewebsite.dto.response.PublicStoreResponse;
import io.makewebsite.entity.*;
import io.makewebsite.exception.StoreFrozenException;
import io.makewebsite.repository.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.BoutiqueVisitService;
import io.makewebsite.service.CaisseService;
import io.makewebsite.service.CustomerService;
import io.makewebsite.service.EmailService;
import io.makewebsite.service.InvoicePdfService;
import io.makewebsite.service.InvoiceService;
import io.makewebsite.service.NotificationService;
import io.makewebsite.service.PaymentService;
import io.makewebsite.service.StoreGeneratorService;
import io.makewebsite.service.StoreStatusGuard;
import io.makewebsite.service.TelegramNotificationService;
import io.makewebsite.service.TelegramService;
import io.makewebsite.service.WebSocketService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
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

    private static final String DEFAULT_PRODUCT_IMAGE = "/images/default-product.png";

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
    private final CustomerService customerService;
    private final InvoiceService invoiceService;
    private final NotificationService notificationService;
    private final WebSocketService webSocketService;
    private final TelegramService telegramService;
    private final TelegramNotificationService telegramNotificationService;
    private final CaisseService caisseService;
    private final InvoicePdfService invoicePdfService;
    private final EmailService emailService;
    private final ObjectMapper objectMapper;
    private final TrafficRepository trafficRepository;
    private final io.makewebsite.service.GeoLocationService geoLocationService;

    // Serve full generated store HTML, or product detail if product_id query param is present
    @GetMapping("/store/{slug}")
    public ResponseEntity<String> serveStore(
            @PathVariable String slug,
            @RequestParam(value = "product_id", required = false) String productId,
            HttpServletRequest request) {
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b == null) return ResponseEntity.notFound().build();

        // If product_id is present, serve product detail page
        if (productId != null && !productId.isBlank()) {
            try {
                UUID pid = UUID.fromString(productId);
                Product p = productRepository.findByIdWithBoutique(pid).orElse(null);
                if (p == null || !p.getIsActive() || !p.getBoutique().getId().equals(b.getId())) {
                    return ResponseEntity.notFound().build();
                }
                String html = buildProductDetailHtml(slug, b, p);
                if (html == null) return ResponseEntity.notFound().build();
                trackStoreVisit(b, request);
                return ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                        .body(html);
            } catch (IllegalArgumentException e) {
                // Invalid UUID — fall through to normal store page
            }
        }

        // Normal store listing page
        String html = storeGeneratorService.loadHtml(slug);
        if (html == null) {
            storeGeneratorService.regenerate(b.getId());
            b = boutiqueRepository.findBySlug(slug).orElse(null);
            if (b == null) return ResponseEntity.notFound().build();
            html = b.getGeneratedHtml();
            if (html == null) return ResponseEntity.notFound().build();
        }
        trackStoreVisit(b, request);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                .body(html);
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
        BigDecimal total = subtotal.add(shipping);
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
                    .subtotal(subtotal).shippingFee(shipping).total(total)
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

        // Always resolve country/city from IP geolocation (needed for top countries/cities analytics)
        // Browser-provided lat/lng takes precedence for map coordinates
        String country = null;
        String city = null;
        String ipHash = hashIp(request.getRemoteAddr());
        try {
            var geo = geoLocationService.locate(request.getRemoteAddr());
            if (geo.isPresent()) {
                var g = geo.get();
                country = g.country();
                city = g.city();
                if (lat == null) lat = g.latitude();
                if (lng == null) lng = g.longitude();
                log.info("IP geolocation: country={} city={} browserLat={} browserLng={} geoLat={} geoLng={}",
                        country, city, body.get("latitude"), body.get("longitude"), g.latitude(), g.longitude());
            }
        } catch (Exception e) {
            log.warn("IP geolocation failed for slug={}: {}", slug, e.getMessage());
        }

        boutiqueVisitService.recordVisit(b.getId(), b.getSlug(), request.getRemoteAddr(), ua, visitorId, referrer, lat, lng);

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
        boutiqueVisitService.recordVisit(boutique.getId(), boutique.getSlug(),
                request.getRemoteAddr(), request.getHeader("User-Agent"), null,
                request.getHeader("Referer"), null, null);
    }

    /**
     * Build a full product detail HTML page by taking the store's generated HTML
     * and replacing the &lt;main&gt; section with product detail content.
     * Reuses the store's CSS, header, footer, cart/wishlist JS as-is.
     */
    private String buildProductDetailHtml(String slug, Boutique b, Product p) {
        String html = storeGeneratorService.loadHtml(slug);
        if (html == null) return null;

        String currencySymbol = b.getCurrency() != null
            ? (b.getCurrency().equals("TND") ? "DT"
               : b.getCurrency().equals("EUR") ? "\u20AC" : "$")
            : "DT";

        // First product image
        String firstImg = extractFirstImage(p.getImages());
        String productImg = resolveImageUrl(firstImg.isBlank() ? null : firstImg);

        // Price display
        boolean hasCompare = p.getComparePrice() != null
            && p.getComparePrice().compareTo(BigDecimal.ZERO) > 0;
        String priceHtml = hasCompare
            ? "<old style=\"text-decoration:line-through;color:var(--muted);margin-right:8px\">"
                + currencySymbol + String.format("%.2f", p.getComparePrice()) + "</old> "
                + currencySymbol + String.format("%.2f", p.getPrice())
            : currencySymbol + String.format("%.2f", p.getPrice());

        // Stock
        boolean inStock = p.getStock() == null || p.getStock() > 0;
        String stockHtml = inStock
            ? "<span style=\"color:#16a34a;font-weight:500\">\u2713 En stock</span>"
            : "<span style=\"color:#ef4444;font-weight:500\">\u2717 Rupture de stock</span>";

        // Product detail grid
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
            "<div class=\"pd-back\"><a href=\"/store/" + slug + "\">\u2190 Retour aux produits</a></div>";

        int mainStart = html.indexOf("<main class=\"main\">");
        int mainEnd = html.indexOf("</main>", mainStart);
        if (mainStart == -1 || mainEnd == -1) {
            // Fallback: if <main> not found, just return the HTML as-is (product not found)
            return html;
        }

        html = html.substring(0, mainStart + "<main class=\"main\">".length())
             + detailContent
             + html.substring(mainEnd);
        return html;
    }

    /** Extract the first image URL from a JSON-style image array string. */
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

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private String resolveImageUrl(String url) {
        if (url == null || url.isBlank()) return DEFAULT_PRODUCT_IMAGE;
        String trimmed = url.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed;
        if (trimmed.startsWith("/")) return trimmed;
        if (trimmed.startsWith("images/") || trimmed.startsWith("uploads/")) return "/" + trimmed;
        return "/uploads/" + trimmed;
    }
}
