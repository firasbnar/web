package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Product;
import io.makewebsite.entity.ProductVariant;
import io.makewebsite.repository.ProductRepository;
import io.makewebsite.repository.ProductVariantRepository;
import io.makewebsite.security.Permission;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.BoutiquePermissionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@RestController
@RequestMapping("/api/products/{productId}/variants")
@RequiredArgsConstructor
public class ProductVariantController {
    private final ProductVariantRepository variantRepository;
    private final ProductRepository productRepository;
    private final BoutiquePermissionService boutiquePermissionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getVariants(@PathVariable UUID productId) {
        List<Map<String, Object>> list = variantRepository.findByProductIdOrderBySortOrderAsc(productId).stream().map(v -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", v.getId());
            m.put("productId", v.getProduct().getId());
            m.put("name", v.getName());
            m.put("price", v.getPrice());
            m.put("stock", v.getStock());
            m.put("sku", v.getSku());
            m.put("sortOrder", v.getSortOrder());
            m.put("imageUrl", v.getImageUrl());
            return m;
        }).toList();
        return ResponseEntity.ok(ApiResponse.ok(list));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> createVariant(
            @PathVariable UUID productId,
            @Valid @RequestBody VariantRequest req,
            @AuthenticationPrincipal UserPrincipal principal) {
        Product product = productRepository.findByIdWithBoutique(productId)
                .orElseThrow(() -> new RuntimeException("Produit non trouvé"));
        boutiquePermissionService.requireBoutiquePermission(
                principal.getUserId(), product.getBoutique().getId(), Permission.PRODUCT_WRITE);
        ProductVariant v = ProductVariant.builder()
                .product(product)
                .name(req.getName())
                .price(req.getPrice())
                .stock(req.getStock())
                .sku(req.getSku())
                .sortOrder(req.getSortOrder())
                .imageUrl(req.getImageUrl())
                .build();
        v = variantRepository.save(v);
        return ResponseEntity.ok(ApiResponse.ok("Variante créée", variantToMap(v)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateVariant(
            @PathVariable UUID productId,
            @PathVariable UUID id,
            @Valid @RequestBody VariantRequest req,
            @AuthenticationPrincipal UserPrincipal principal) {
        Product product = productRepository.findByIdWithBoutique(productId)
                .orElseThrow(() -> new RuntimeException("Produit non trouvé"));
        boutiquePermissionService.requireBoutiquePermission(
                principal.getUserId(), product.getBoutique().getId(), Permission.PRODUCT_WRITE);
        ProductVariant v = variantRepository.findById(id).orElseThrow(() -> new RuntimeException("Variante non trouvée"));
        if (!productId.equals(v.getProduct().getId())) {
            throw new RuntimeException("Variante non trouvée");
        }
        v.setName(req.getName());
        if (req.getPrice() != null) v.setPrice(req.getPrice());
        if (req.getStock() != null) v.setStock(req.getStock());
        if (req.getSku() != null) v.setSku(req.getSku());
        if (req.getSortOrder() != null) v.setSortOrder(req.getSortOrder());
        if (req.getImageUrl() != null) v.setImageUrl(req.getImageUrl());
        v = variantRepository.save(v);
        return ResponseEntity.ok(ApiResponse.ok("Variante mise à jour", variantToMap(v)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteVariant(
            @PathVariable UUID productId,
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        Product product = productRepository.findByIdWithBoutique(productId)
                .orElseThrow(() -> new RuntimeException("Produit non trouvé"));
        boutiquePermissionService.requireBoutiquePermission(
                principal.getUserId(), product.getBoutique().getId(), Permission.PRODUCT_DELETE);
        ProductVariant variant = variantRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Variante non trouvée"));
        if (!productId.equals(variant.getProduct().getId())) {
            throw new RuntimeException("Variante non trouvée");
        }
        variantRepository.delete(variant);
        return ResponseEntity.ok(ApiResponse.ok("Variante supprimée", null));
    }

    private Map<String, Object> variantToMap(ProductVariant v) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", v.getId());
        m.put("productId", v.getProduct().getId());
        m.put("name", v.getName());
        m.put("price", v.getPrice());
        m.put("stock", v.getStock());
        m.put("sku", v.getSku());
        m.put("sortOrder", v.getSortOrder());
        m.put("imageUrl", v.getImageUrl());
        return m;
    }
}

@Data
class VariantRequest {
    @NotBlank
    private String name;
    private BigDecimal price;
    private Integer stock;
    private String sku;
    private Integer sortOrder;
    private String imageUrl;
}
