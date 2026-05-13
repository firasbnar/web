package io.makewebsite.controller;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.service.StoreGeneratorService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicStoreController {

    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final OrderRepository orderRepository;
    private final StoreGeneratorService storeGeneratorService;

    // Serve full generated store HTML
    @GetMapping("/store/{slug}")
    public ResponseEntity<String> serveStore(@PathVariable String slug) {
        String html = storeGeneratorService.loadHtml(slug);
        if (html == null) {
            Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
            if (b == null) return ResponseEntity.notFound().build();
            storeGeneratorService.regenerate(b.getId());
            html = b.getGeneratedHtml();
            if (html == null) return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.TEXT_HTML_VALUE)
                .body(html);
    }

    // Public products list
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

    // Single product
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

    // Categories
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
        String fullName = (String) body.get("fullName");
        String phone = (String) body.get("phone");
        String billingAddress = (String) body.get("billingAddress");
        String city = (String) body.get("city");
        String paymentMethod = (String) body.get("paymentMethod");
        String email = (String) body.get("email");
        String country = (String) body.get("country");
        List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");

        if (fullName == null || phone == null || billingAddress == null || city == null || items == null || items.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Champs obligatoires manquants"));
        }

        BigDecimal subtotal = BigDecimal.ZERO;
        List<OrderItem> orderItems = new ArrayList<>();
        for (Map<String, Object> item : items) {
            String pid = item.get("productId").toString();
            int qty = Integer.parseInt(item.get("quantity").toString());
            BigDecimal up = new BigDecimal(item.get("unitPrice").toString());
            Product product = productRepository.findById(UUID.fromString(pid)).orElse(null);
            String pname = product != null ? product.getName() : "Produit #" + pid;
            subtotal = subtotal.add(up.multiply(BigDecimal.valueOf(qty)));
            OrderItem oi = OrderItem.builder()
                    .productName(pname).unitPrice(up).quantity(qty).subtotal(up.multiply(BigDecimal.valueOf(qty)))
                    .build();
            orderItems.add(oi);
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
                .build();
        order.setItems(orderItems);
        order = orderRepository.save(order);

        return ResponseEntity.ok(Map.of(
            "success", true,
            "orderId", order.getId().toString(),
            "orderNumber", orderNum
        ));
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

    // Track visit
    @PostMapping("/visit")
    public ResponseEntity<Map<String, Object>> trackVisit(@RequestBody Map<String, String> body) {
        return ResponseEntity.ok(Map.of("success", true));
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
}
