package io.makewebsite.repository;

import io.makewebsite.entity.DeliveryZone;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface DeliveryZoneRepository extends JpaRepository<DeliveryZone, UUID> {
    List<DeliveryZone> findByBoutiqueIdOrderByFeeAsc(UUID boutiqueId);
    List<DeliveryZone> findByBoutiqueIdAndIsActiveTrue(UUID boutiqueId);
    void deleteByBoutiqueId(UUID boutiqueId);
}
