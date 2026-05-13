package io.makewebsite.repository;

import io.makewebsite.entity.BoutiqueConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BoutiqueConfigRepository extends JpaRepository<BoutiqueConfig, UUID> {
    List<BoutiqueConfig> findByBoutiqueId(UUID boutiqueId);

    Optional<BoutiqueConfig> findByBoutiqueIdAndConfigKey(UUID boutiqueId, String configKey);

    void deleteByBoutiqueIdAndConfigKey(UUID boutiqueId, String configKey);
}
