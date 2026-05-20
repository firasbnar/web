package io.makewebsite.repository;

import io.makewebsite.entity.Boutique;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BoutiqueRepository extends JpaRepository<Boutique, UUID> {

    Optional<Boutique> findBySlug(String slug);

    List<Boutique> findByUserId(UUID userId);

    Optional<Boutique> findByUserIdAndId(UUID userId, UUID id);

    Optional<Boutique> findByIdAndTenantId(UUID id, UUID tenantId);

    List<Boutique> findByTenantId(UUID tenantId);

    List<Boutique> findAllByIsActiveTrue();

    long countByStoreStatus(String storeStatus);

    Page<Boutique> findByStoreStatus(String storeStatus, Pageable pageable);

    @Query("SELECT b FROM Boutique b JOIN FETCH b.user")
    Page<Boutique> findAllWithUser(Pageable pageable);

    @Query("SELECT b FROM Boutique b JOIN FETCH b.user WHERE b.id = :id")
    Optional<Boutique> findByIdWithUser(@Param("id") UUID id);

    boolean existsBySlug(String slug);
}
