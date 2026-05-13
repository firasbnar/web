package io.makewebsite.repository;

import io.makewebsite.entity.Order;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {

    Page<Order> findByBoutiqueId(UUID boutiqueId, Pageable pageable);

    Page<Order> findByUserId(UUID userId, Pageable pageable);

    Page<Order> findByBoutiqueIdAndStatus(UUID boutiqueId, String status, Pageable pageable);

    Page<Order> findByBoutiqueIdAndOrderNumberContainingIgnoreCase(UUID boutiqueId, String search, Pageable pageable);

    Page<Order> findByBoutiqueIdAndStatusAndOrderNumberContainingIgnoreCase(UUID boutiqueId, String status, String search, Pageable pageable);

    Optional<Order> findByOrderNumber(String orderNumber);

    long countByBoutiqueId(UUID boutiqueId);

    long countByBoutiqueIdAndStatus(UUID boutiqueId, String status);

    long countByBoutiqueIdAndCreatedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    List<Order> findByBoutiqueIdAndCreatedAtBetweenOrderByCreatedAtDesc(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    @Query("SELECT COALESCE(SUM(o.total), 0) FROM Order o WHERE o.boutique.id = :boutiqueId AND o.createdAt BETWEEN :from AND :to")
    BigDecimal sumRevenueByBoutiqueIdAndCreatedAtBetween(@Param("boutiqueId") UUID boutiqueId, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

    @Query("SELECT COALESCE(SUM(o.total), 0) FROM Order o WHERE o.boutique.id = :boutiqueId")
    BigDecimal sumRevenueByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT COALESCE(SUM(o.total), 0) FROM Order o")
    BigDecimal sumAllRevenue();
}
