package io.makewebsite.repository;

import io.makewebsite.entity.StoreSlider;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface StoreSliderRepository extends JpaRepository<StoreSlider, UUID> {
    List<StoreSlider> findByBoutiqueIdOrderBySortOrderAsc(UUID boutiqueId);
    void deleteByBoutiqueId(UUID boutiqueId);
}
