package io.makewebsite.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.makewebsite.dto.request.CreateProductRequest;
import io.makewebsite.dto.request.UpdateStockRequest;
import io.makewebsite.dto.response.ProductResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.security.TenantContext;
import io.makewebsite.util.CsvUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProductService {
    private final ProductRepository productRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final CategoryRepository categoryRepository;
    private final CartItemRepository cartItemRepository;
    private final WishlistItemRepository wishlistItemRepository;
    private final ProductVariantRepository productVariantRepository;
    private final StoreGeneratorService storeGeneratorService;
    private final ObjectMapper objectMapper;
    private final TenantAccessService tenantAccessService;
    private final StoreStatusGuard storeStatusGuard;
    private final TelegramNotificationService telegramNotificationService;

    @Transactional(readOnly = true)
    public Page<ProductResponse> getProducts(UUID boutiqueId, String search, UUID categoryId, Boolean isActive, Pageable pageable) {
        Page<Product> products;
        if (search != null && !search.isEmpty()) {
            products = productRepository.findByBoutiqueIdAndNameContainingIgnoreCase(boutiqueId, search, pageable);
        } else if (categoryId != null) {
            products = productRepository.findByBoutiqueIdAndCategoryId(boutiqueId, categoryId, pageable);
        } else if (isActive != null) {
            products = productRepository.findByBoutiqueIdAndIsActive(boutiqueId, isActive, pageable);
        } else {
            products = productRepository.findByBoutiqueId(boutiqueId, pageable);
        }
        return products.map(this::mapToResponse);
    }

    @Transactional(readOnly = true)
    public ProductResponse getProduct(UUID id) {
        Product product = productRepository.findById(id).orElseThrow(() -> new RuntimeException("Produit non trouvé"));
        return mapToResponse(product);
    }

    @Transactional
    public ProductResponse createProduct(CreateProductRequest request) {
        Boutique boutique = tenantAccessService.requireBoutiqueAccess(request.getBoutiqueId());
        storeStatusGuard.requireActive(boutique);
        Category category = null;
        if (request.getCategoryId() != null) {
            category = categoryRepository.findById(request.getCategoryId()).orElse(null);
        }
        Product product = Product.builder()
                .boutique(boutique)
                .category(category)
                .name(request.getName())
                .description(request.getDescription())
                .price(request.getPrice())
                .comparePrice(request.getComparePrice())
                .stock(request.getStock() != null ? request.getStock() : 0)
                .sku(request.getSku())
                .purchasePrice(request.getPurchasePrice())
                .colors(request.getColors())
                .sizes(request.getSizes())
                .descriptionHtml(request.getDescriptionHtml())
                .images(request.getImages() != null ? request.getImages() : "[]")
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .isFeatured(request.getIsFeatured() != null ? request.getIsFeatured() : false)
                .seoTitle(request.getSeoTitle())
                .seoDescription(request.getSeoDescription())
                .build();
        product = productRepository.save(product);
        try {
            storeGeneratorService.regenerate(product.getBoutique().getId());
        } catch (Exception e) {
            log.warn("Failed to regenerate storefront after product creation: {}", e.getMessage());
        }
        return mapToResponse(product);
    }

    @Transactional
    public List<ProductResponse> bulkImportProducts(UUID boutiqueId, List<CreateProductRequest> requests) {
        Boutique boutique = tenantAccessService.requireBoutiqueAccess(boutiqueId);
        storeStatusGuard.requireActive(boutique);
        List<ProductResponse> results = new java.util.ArrayList<>();
        for (CreateProductRequest request : requests) {
            request.setBoutiqueId(boutiqueId);
            Category category = null;
            if (request.getCategoryId() != null) {
                category = categoryRepository.findById(request.getCategoryId()).orElse(null);
            }
            Product product = Product.builder()
                    .boutique(boutique)
                    .category(category)
                    .name(request.getName())
                    .description(request.getDescription())
                    .price(request.getPrice())
                    .comparePrice(request.getComparePrice())
                    .stock(request.getStock() != null ? request.getStock() : 0)
                    .sku(request.getSku())
                    .purchasePrice(request.getPurchasePrice())
                    .colors(request.getColors())
                    .sizes(request.getSizes())
                    .descriptionHtml(request.getDescriptionHtml())
                    .images(request.getImages() != null ? request.getImages() : "[]")
                    .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                    .isFeatured(request.getIsFeatured() != null ? request.getIsFeatured() : false)
                    .seoTitle(request.getSeoTitle())
                    .seoDescription(request.getSeoDescription())
                    .build();
            product = productRepository.save(product);
            results.add(mapToResponse(product));
        }
        try {
            storeGeneratorService.regenerate(boutiqueId);
        } catch (Exception e) {
            log.warn("Failed to regenerate storefront after bulk import: {}", e.getMessage());
        }
        return results;
    }

    @Transactional
    public ProductResponse updateProduct(UUID id, CreateProductRequest request) {
        Product product = findTenantProduct(id);
        if (request.getCategoryId() != null) {
            product.setCategory(categoryRepository.findById(request.getCategoryId()).orElse(null));
        }
        if (request.getName() != null) product.setName(request.getName());
        if (request.getDescription() != null) product.setDescription(request.getDescription());
        if (request.getPrice() != null) product.setPrice(request.getPrice());
        if (request.getComparePrice() != null) product.setComparePrice(request.getComparePrice());
        if (request.getStock() != null) product.setStock(request.getStock());
        if (request.getSku() != null) product.setSku(request.getSku());
        if (request.getPurchasePrice() != null) product.setPurchasePrice(request.getPurchasePrice());
        if (request.getColors() != null) product.setColors(request.getColors());
        if (request.getSizes() != null) product.setSizes(request.getSizes());
        if (request.getDescriptionHtml() != null) product.setDescriptionHtml(request.getDescriptionHtml());
        if (request.getImages() != null) product.setImages(request.getImages());
        if (request.getIsActive() != null) product.setIsActive(request.getIsActive());
        if (request.getIsFeatured() != null) product.setIsFeatured(request.getIsFeatured());
        if (request.getSeoTitle() != null) product.setSeoTitle(request.getSeoTitle());
        if (request.getSeoDescription() != null) product.setSeoDescription(request.getSeoDescription());
        product = productRepository.save(product);
        try {
            storeGeneratorService.regenerate(product.getBoutique().getId());
        } catch (Exception e) {
            log.warn("Failed to regenerate storefront after product update: {}", e.getMessage());
        }
        return mapToResponse(product);
    }

    @Transactional
    public void deleteProduct(UUID id, UUID userId) {
        Product product = findTenantProduct(id);
        UUID boutiqueId = product.getBoutique().getId();

        if (!TenantContext.isSuperAdmin()) {
            boolean isOwner = boutiqueRepository.findOwnerIdByBoutiqueId(boutiqueId).equals(userId);
            if (!isOwner) {
                throw new SecurityException("Seul le propriétaire de la boutique peut supprimer un produit");
            }
        }

        storeStatusGuard.requireActive(product.getBoutique());

        if (!Boolean.TRUE.equals(product.getIsActive())) {
            throw new RuntimeException("Produit déjà supprimé");
        }

        product.setIsActive(false);
        productRepository.save(product);
        productVariantRepository.deleteByProductId(id);
        cartItemRepository.deleteByProductId(id);
        wishlistItemRepository.deleteByProductId(id);

        try {
            storeGeneratorService.regenerate(boutiqueId);
        } catch (Exception e) {
            log.warn("Failed to regenerate storefront after product deletion: {}", e.getMessage());
        }

        log.info("Product soft-deleted: id={}, name={}, boutiqueId={}, userId={}",
                id, product.getName(), boutiqueId, userId);
    }

    @Transactional
    public ProductResponse updateStock(UUID id, UpdateStockRequest request) {
        Product product = findTenantProduct(id);
        int oldStock = product.getStock() != null ? product.getStock() : 0;
        int newStock = request.getStock() != null ? request.getStock() : 0;
        product.setStock(newStock);
        product = productRepository.save(product);

        if (newStock > 5) {
            product.setLowStockAlertSent(false);
            product.setOutOfStockAlertSent(false);
        } else if (newStock > 0 && newStock <= 5) {
            if (!Boolean.TRUE.equals(product.getLowStockAlertSent())) {
                telegramNotificationService.notifyLowStock(product, newStock);
                product.setLowStockAlertSent(true);
            }
            product.setOutOfStockAlertSent(false);
        } else if (newStock <= 0) {
            if (!Boolean.TRUE.equals(product.getOutOfStockAlertSent())) {
                telegramNotificationService.notifyOutOfStock(product);
                product.setOutOfStockAlertSent(true);
            }
            product.setLowStockAlertSent(false);
        }
        if (oldStock != newStock) {
            productRepository.save(product);
        }

        try {
            storeGeneratorService.regenerate(product.getBoutique().getId());
        } catch (Exception e) {
            log.warn("Failed to regenerate storefront after stock update: {}", e.getMessage());
        }

        return mapToResponse(product);
    }

    @Transactional
    public ProductResponse toggleActive(UUID id) {
        Product product = findTenantProduct(id);
        if (product.getBoutique() != null) {
            storeStatusGuard.requireActive(product.getBoutique());
        }
        boolean previous = product.getIsActive() != null && product.getIsActive();
        product.setIsActive(!previous);
        product = productRepository.save(product);

        if (product.getBoutique() != null) {
            try {
                storeGeneratorService.regenerate(product.getBoutique().getId());
            } catch (Exception e) {
                log.warn("Failed to regenerate storefront after toggle active: {}", e.getMessage());
            }
        }

        log.info("Product toggleActive: id={}, name={}, boutiqueId={}, previous={}, new={}",
                id, product.getName(), product.getBoutique() != null ? product.getBoutique().getId() : null,
                previous, product.getIsActive());
        return mapToResponse(product);
    }

    @Transactional
    public ProductResponse toggleFeatured(UUID id) {
        Product product = findTenantProduct(id);
        boolean previous = product.getIsFeatured() != null && product.getIsFeatured();
        product.setIsFeatured(!previous);
        product = productRepository.save(product);
        if (product.getBoutique() != null) {
            try {
                storeGeneratorService.regenerate(product.getBoutique().getId());
            } catch (Exception e) {
                log.warn("Failed to regenerate storefront after toggle featured: {}", e.getMessage());
            }
        }
        log.info("Product toggleFeatured: id={}, name={}, boutiqueId={}, previous={}, new={}",
                id, product.getName(), product.getBoutique() != null ? product.getBoutique().getId() : null,
                previous, product.getIsFeatured());
        return mapToResponse(product);
    }

    private ProductResponse mapToResponse(Product p) {
        return ProductResponse.builder()
                .id(p.getId())
                .boutiqueId(p.getBoutique().getId())
                .categoryId(p.getCategory() != null ? p.getCategory().getId() : null)
                .categoryName(p.getCategory() != null ? p.getCategory().getName() : null)
                .name(p.getName())
                .description(p.getDescription())
                .price(p.getPrice())
                .comparePrice(p.getComparePrice())
                .stock(p.getStock())
                .sku(p.getSku())
                .purchasePrice(p.getPurchasePrice())
                .colors(p.getColors())
                .sizes(p.getSizes())
                .descriptionHtml(p.getDescriptionHtml())
                .images(p.getImages())
                .isActive(p.getIsActive())
                .isFeatured(p.getIsFeatured())
                .seoTitle(p.getSeoTitle())
                .seoDescription(p.getSeoDescription())
                .createdAt(p.getCreatedAt())
                .build();
    }

    @Transactional(readOnly = true)
    public String exportCsv(UUID boutiqueId) {
        Page<Product> products = productRepository.findByBoutiqueId(boutiqueId, Pageable.unpaged());
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("Nom,SKU, Prix,Stock,Actif,Featured,Catégorie,Couleurs,Tailles,Créé le\n");
        for (Product p : products) {
            sb.append(CsvUtil.escapeCsv(p.getName())).append(",")
              .append(CsvUtil.escapeCsv(p.getSku())).append(",")
              .append(p.getPrice()).append(",")
              .append(p.getStock()).append(",")
              .append(p.getIsActive()).append(",")
              .append(p.getIsFeatured()).append(",")
              .append(CsvUtil.escapeCsv(p.getCategory() != null ? p.getCategory().getName() : "")).append(",")
              .append(CsvUtil.escapeCsv(p.getColors())).append(",")
              .append(CsvUtil.escapeCsv(p.getSizes())).append(",")
              .append(p.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    private Product findTenantProduct(UUID id) {
        if (io.makewebsite.security.TenantContext.isSuperAdmin()) {
            return productRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Produit non trouvé"));
        }
        UUID tenantId = tenantAccessService.currentTenantIdOrThrow();
        return productRepository.findByIdAndBoutiqueTenantId(id, tenantId)
                .orElseThrow(() -> new SecurityException("Accès tenant refusé"));
    }
}
