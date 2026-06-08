package io.makewebsite.repository;

import io.makewebsite.entity.Invoice;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface InvoiceRepository extends JpaRepository<Invoice, UUID> {
    List<Invoice> findByUserIdOrderByCreatedAtDesc(UUID userId);
    List<Invoice> findByUserIdAndSubscriptionIdOrderByCreatedAtDesc(UUID userId, UUID subscriptionId);
    Optional<Invoice> findByOrderId(UUID orderId);
    Optional<Invoice> findByOrderIdAndBoutiqueId(UUID orderId, UUID boutiqueId);
    Optional<Invoice> findByPaymentRef(String paymentRef);
    Optional<Invoice> findByPaymentRefAndUserId(String paymentRef, UUID userId);
}
