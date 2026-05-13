package io.makewebsite.repository;

import io.makewebsite.entity.Customer;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface CustomerRepository extends JpaRepository<Customer, UUID> {

    Page<Customer> findByBoutiqueId(UUID boutiqueId, Pageable pageable);

    Page<Customer> findByBoutiqueIdAndFullNameContainingIgnoreCase(UUID boutiqueId, String search, Pageable pageable);

    long countByBoutiqueId(UUID boutiqueId);

    @Query("SELECT COUNT(o) FROM Order o WHERE o.customer.id = :customerId")
    long countByCustomerId(@Param("customerId") UUID customerId);

    @Query("SELECT COALESCE(SUM(o.total), 0) FROM Order o WHERE o.customer.id = :customerId")
    Double sumTotalByCustomerId(@Param("customerId") UUID customerId);

    @Query("SELECT MAX(o.createdAt) FROM Order o WHERE o.customer.id = :customerId")
    java.time.LocalDateTime findLastOrderDateByCustomerId(@Param("customerId") UUID customerId);
}
