package io.makewebsite.repository;

import io.makewebsite.entity.NotificationConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface NotificationConfigRepository extends JpaRepository<NotificationConfig, UUID> {
    Optional<NotificationConfig> findByBoutiqueId(UUID boutiqueId);
    void deleteByBoutiqueId(UUID boutiqueId);
}
