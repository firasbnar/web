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

    List<Product> findByCategoryId(UUID categoryId);

    long countByBoutiqueId(UUID boutiqueId);

    long countByBoutiqueIdAndCategoryId(UUID boutiqueId, UUID categoryId);

    @Query("SELECT MIN(p.price) FROM Product p WHERE p.boutique.id = :boutiqueId AND p.isActive = true")
    BigDecimal findMinPriceByBoutiqueIdAndIsActiveTrue(@Param("boutiqueId") UUID boutiqueId);
}
