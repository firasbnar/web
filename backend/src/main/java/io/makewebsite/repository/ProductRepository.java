package io.makewebsite.repository;

import io.makewebsite.entity.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProductRepository extends JpaRepository<Product, UUID> {

    Page<Product> findByBoutiqueId(UUID boutiqueId, Pageable pageable);

    Optional<Product> findByIdAndBoutiqueTenantId(UUID id, UUID tenantId);

    Page<Product> findByBoutiqueIdAndCategoryId(UUID boutiqueId, UUID categoryId, Pageable pageable);

    Page<Product> findByBoutiqueIdAndNameContainingIgnoreCase(UUID boutiqueId, String search, Pageable pageable);

    Page<Product> findByBoutiqueIdAndIsActive(UUID boutiqueId, boolean isActive, Pageable pageable);

    List<Product> findByBoutiqueIdAndStockLessThan(UUID boutiqueId, int stock);

    List<Product> findByBoutiqueIdAndIsActiveTrue(UUID boutiqueId);

    @Query("SELECT p FROM Product p LEFT JOIN FETCH p.category WHERE p.boutique.id = :boutiqueId AND (p.isActive = true OR p.isActive IS NULL)")
    List<Product> findPublicProductsWithCategory(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT p FROM Product p LEFT JOIN FETCH p.category WHERE p.boutique.id = :boutiqueId")
    List<Product> findAllByBoutiqueIdSafe(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT p FROM Product p LEFT JOIN FETCH p.category WHERE p.id = :id")
    Optional<Product> findByIdWithCategory(@Param("id") UUID id);

    @Query("SELECT p FROM Product p JOIN FETCH p.boutique WHERE p.id = :id")
    Optional<Product> findByIdWithBoutique(@Param("id") UUID id);

    @Query("SELECT p FROM Product p LEFT JOIN FETCH p.category WHERE p.id = :productId AND p.boutique.slug = :slug")
    Optional<Product> findPublicProductDetails(@Param("slug") String slug, @Param("productId") UUID productId);

    @Query("SELECT p FROM Product p JOIN FETCH p.boutique LEFT JOIN FETCH p.category WHERE p.id = :id")
    Optional<Product> findByIdWithBoutiqueAndCategory(@Param("id") UUID id);

    List<Product> findByCategoryId(UUID categoryId);

    long countByBoutiqueId(UUID boutiqueId);

    long countByBoutiqueIdAndCategoryId(UUID boutiqueId, UUID categoryId);

    long countByBoutiqueIdAndIsActiveTrue(UUID boutiqueId);

    long countByBoutiqueIdAndCategoryIdAndIsActiveTrue(UUID boutiqueId, UUID categoryId);

    @Query("SELECT MIN(p.price) FROM Product p WHERE p.boutique.id = :boutiqueId AND p.isActive = true")
    BigDecimal findMinPriceByBoutiqueIdAndIsActiveTrue(@Param("boutiqueId") UUID boutiqueId);

    List<Product> findByBoutiqueIdAndIsActiveTrueOrderByCreatedAtDesc(UUID boutiqueId);
}
