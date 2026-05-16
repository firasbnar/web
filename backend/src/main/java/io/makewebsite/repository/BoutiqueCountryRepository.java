package io.makewebsite.repository;

import io.makewebsite.entity.BoutiqueCountry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BoutiqueCountryRepository extends JpaRepository<BoutiqueCountry, UUID> {
    List<BoutiqueCountry> findByBoutiqueId(UUID boutiqueId);
    Optional<BoutiqueCountry> findByBoutiqueIdAndCountryCode(UUID boutiqueId, String countryCode);
    void deleteByBoutiqueId(UUID boutiqueId);
}
