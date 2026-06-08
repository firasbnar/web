package io.makewebsite.repository;

import io.makewebsite.entity.Subscription;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {

    Optional<Subscription> findByUserIdAndStatus(UUID userId, String status);

    List<Subscription> findByUserId(UUID userId);

    List<Subscription> findByUserIdAndStatusIn(UUID userId, List<String> statuses);

    long countByStatus(String status);

    List<Subscription> findByStatusIn(List<String> statuses);

    List<Subscription> findByStatusAndExpiresAtBefore(String status, LocalDateTime dateTime);

    @Query("SELECT s FROM Subscription s JOIN FETCH s.user JOIN FETCH s.plan")
    Page<Subscription> findAllWithUserAndPlan(Pageable pageable);
}
