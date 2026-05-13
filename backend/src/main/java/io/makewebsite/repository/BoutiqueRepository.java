package io.makewebsite.repository;

import io.makewebsite.entity.Boutique;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BoutiqueRepository extends JpaRepository<Boutique, UUID> {

    Optional<Boutique> findBySlug(String slug);

    List<Boutique> findByUserId(UUID userId);

    Optional<Boutique> findByUserIdAndId(UUID userId, UUID id);

    List<Boutique> findAllByIsActiveTrue();
}
