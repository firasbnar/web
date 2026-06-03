package io.makewebsite.repository;

import io.makewebsite.entity.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, UUID> {

    List<OrderItem> findByOrderId(UUID orderId);

    @Query("""
            SELECT oi.product.id, oi.productName, SUM(oi.quantity), SUM(oi.subtotal)
            FROM OrderItem oi
            WHERE oi.order.boutique.id = :boutiqueId AND oi.product IS NOT NULL
            GROUP BY oi.product.id, oi.productName
            ORDER BY SUM(oi.quantity) DESC
            """)
    List<Object[]> findBestSellingProducts(@Param("boutiqueId") UUID boutiqueId);

    @Query("""
            SELECT oi.product.category.name, SUM(oi.quantity), SUM(oi.subtotal)
            FROM OrderItem oi
            WHERE oi.order.boutique.id = :boutiqueId AND oi.product.category IS NOT NULL
            GROUP BY oi.product.category.name
            ORDER BY SUM(oi.subtotal) DESC
            """)
    List<Object[]> findBestCategories(@Param("boutiqueId") UUID boutiqueId);

    @Query("""
            SELECT DISTINCT oi.product.id
            FROM OrderItem oi
            WHERE oi.order.boutique.id = :boutiqueId AND oi.product IS NOT NULL
            """)
    List<UUID> findSoldProductIds(@Param("boutiqueId") UUID boutiqueId);
}
