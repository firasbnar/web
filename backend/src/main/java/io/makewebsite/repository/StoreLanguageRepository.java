package io.makewebsite.repository;

import io.makewebsite.entity.StoreLanguage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StoreLanguageRepository extends JpaRepository<StoreLanguage, UUID> {
    Optional<StoreLanguage> findByBoutiqueId(UUID boutiqueId);
}
