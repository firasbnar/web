package io.makewebsite.repository;

import io.makewebsite.entity.StoreView;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StoreViewRepository extends JpaRepository<StoreView, UUID> {
    long countByBoutiqueId(UUID boutiqueId);
    long countByBoutiqueIdAndViewedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);
    Page<StoreView> findByBoutiqueId(UUID boutiqueId, Pageable pageable);

    Optional<StoreView> findFirstByBoutiqueIdAndVisitorIdAndViewedAtAfter(UUID boutiqueId, String visitorId, LocalDateTime after);
    Optional<StoreView> findFirstByBoutiqueIdAndIpHashAndViewedAtAfter(UUID boutiqueId, String ipHash, LocalDateTime after);

    @Query("SELECT s FROM StoreView s WHERE s.boutiqueId = :boutiqueId AND s.page = :page AND s.ipHash = :ipHash AND s.userAgent = :userAgent AND s.viewedAt >= :since ORDER BY s.viewedAt DESC")
    List<StoreView> findRecentDuplicates(@Param("boutiqueId") UUID boutiqueId, @Param("page") String page, @Param("ipHash") String ipHash, @Param("userAgent") String userAgent, @Param("since") LocalDateTime since);

    @Query("SELECT s.country, COUNT(s) FROM StoreView s WHERE s.boutiqueId = :boutiqueId AND s.country IS NOT NULL GROUP BY s.country ORDER BY COUNT(s) DESC")
    List<Object[]> countByBoutiqueIdGroupByCountry(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT s.city, s.country, COUNT(s) FROM StoreView s WHERE s.boutiqueId = :boutiqueId AND s.city IS NOT NULL GROUP BY s.city, s.country ORDER BY COUNT(s) DESC")
    List<Object[]> countByBoutiqueIdGroupByCity(@Param("boutiqueId") UUID boutiqueId);

    List<StoreView> findAllByBoutiqueIdOrderByViewedAtDesc(UUID boutiqueId);

    @Query("SELECT s FROM StoreView s WHERE s.country = 'Inconnu' OR s.city = 'Inconnu'")
    List<StoreView> findAllWithInconnuLocation();
}
