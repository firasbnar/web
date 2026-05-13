package io.makewebsite.repository;

import io.makewebsite.entity.ProductVariant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ProductVariantRepository extends JpaRepository<ProductVariant, UUID> {
    List<ProductVariant> findByProductIdOrderBySortOrderAsc(UUID productId);
    void deleteByProductId(UUID productId);
}
