package io.makewebsite.controller;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.ProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
public class ProductController {
    private final ProductService productService;

    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<ProductResponse>>> getProducts(
            @RequestParam UUID boutiqueId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) UUID categoryId,
            @RequestParam(required = false) Boolean isActive,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<ProductResponse> page = productService.getProducts(boutiqueId, search, categoryId, isActive, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductResponse>> getProduct(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(productService.getProduct(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ProductResponse>> createProduct(@Valid @RequestBody CreateProductRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Produit créé", productService.createProduct(request)));
    }

    @PostMapping("/bulk-import")
    public ResponseEntity<ApiResponse<List<ProductResponse>>> bulkImport(@Valid @RequestBody BulkImportRequest request) {
        List<ProductResponse> created = new java.util.ArrayList<>();
        for (CreateProductRequest productRequest : request.getProducts()) {
            productRequest.setBoutiqueId(request.getBoutiqueId());
            created.add(productService.createProduct(productRequest));
        }
        return ResponseEntity.ok(ApiResponse.ok("Produits importés", created));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductResponse>> updateProduct(@PathVariable UUID id, @Valid @RequestBody CreateProductRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Produit mis à jour", productService.updateProduct(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteProduct(@PathVariable UUID id, @AuthenticationPrincipal UserPrincipal principal) {
        productService.deleteProduct(id, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Produit supprimé", null));
    }

    @PutMapping("/{id}/toggle-active")
    public ResponseEntity<ApiResponse<ProductResponse>> toggleActive(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(productService.toggleActive(id)));
    }

    @PutMapping("/{id}/toggle-featured")
    public ResponseEntity<ApiResponse<ProductResponse>> toggleFeatured(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(productService.toggleFeatured(id)));
    }

    @PutMapping("/{id}/stock")
    public ResponseEntity<ApiResponse<ProductResponse>> updateStock(@PathVariable UUID id, @Valid @RequestBody UpdateStockRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Stock mis à jour", productService.updateStock(id, request)));
    }

    @GetMapping("/export")
    public ResponseEntity<String> exportCsv(@RequestParam UUID boutiqueId) {
        String csv = productService.exportCsv(boutiqueId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("produits.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
    }
}
