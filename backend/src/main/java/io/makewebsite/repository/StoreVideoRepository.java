package io.makewebsite.repository;

import io.makewebsite.entity.StoreVideo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface StoreVideoRepository extends JpaRepository<StoreVideo, UUID> {
    List<StoreVideo> findByBoutiqueIdOrderBySortOrderAsc(UUID boutiqueId);
    void deleteByBoutiqueId(UUID boutiqueId);
}
