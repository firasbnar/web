package io.makewebsite.repository;

import io.makewebsite.entity.AnalyticsEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface AnalyticsEventRepository extends JpaRepository<AnalyticsEvent, UUID> {

    List<AnalyticsEvent> findByBoutiqueIdAndCreatedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    long countByBoutiqueIdAndEventTypeAndCreatedAtBetween(UUID boutiqueId, String eventType, LocalDateTime from, LocalDateTime to);
}
