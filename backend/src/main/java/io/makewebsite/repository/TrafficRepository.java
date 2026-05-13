package io.makewebsite.repository;

import io.makewebsite.entity.Visitor;
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
public interface TrafficRepository extends JpaRepository<Visitor, UUID> {

    long countByBoutiqueId(UUID boutiqueId);

    long countByBoutiqueIdAndLastActivityAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    long countByBoutiqueIdAndCreatedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    Page<Visitor> findByBoutiqueId(UUID boutiqueId, Pageable pageable);

    @Query("SELECT COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.isActive = true")
    long countActiveVisitorsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.isActive = true")
    List<Visitor> findActiveVisitorsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.ipHash = :ipHash")
    Optional<Visitor> findByBoutiqueIdAndIpHash(@Param("boutiqueId") UUID boutiqueId, @Param("ipHash") String ipHash);

    @Query("SELECT v.country, COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.country IS NOT NULL GROUP BY v.country ORDER BY COUNT(v) DESC")
    List<Object[]> countByBoutiqueIdGroupByCountry(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v.city, v.country, COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.city IS NOT NULL GROUP BY v.city, v.country ORDER BY COUNT(v) DESC")
    List<Object[]> countByBoutiqueIdGroupByCity(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v.deviceType, COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.deviceType IS NOT NULL GROUP BY v.deviceType ORDER BY COUNT(v) DESC")
    List<Object[]> countByBoutiqueIdGroupByDeviceType(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v.browser, COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.browser IS NOT NULL GROUP BY v.browser ORDER BY COUNT(v) DESC")
    List<Object[]> countByBoutiqueIdGroupByBrowser(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v.operatingSystem, COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.operatingSystem IS NOT NULL GROUP BY v.operatingSystem ORDER BY COUNT(v) DESC")
    List<Object[]> countByBoutiqueIdGroupByOs(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v.referralSource, COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.referralSource IS NOT NULL GROUP BY v.referralSource ORDER BY COUNT(v) DESC")
    List<Object[]> countByBoutiqueIdGroupByReferralSource(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT COUNT(DISTINCT v.ipHash) FROM Visitor v WHERE v.boutiqueId = :boutiqueId")
    long countUniqueVisitorsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT COUNT(DISTINCT v.ipHash) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.createdAt BETWEEN :from AND :to")
    long countUniqueVisitorsByBoutiqueIdBetween(@Param("boutiqueId") UUID boutiqueId, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

    @Query("SELECT COALESCE(SUM(v.totalVisits), 0) FROM Visitor v WHERE v.boutiqueId = :boutiqueId")
    long sumTotalVisitsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT v FROM Visitor v WHERE v.boutiqueId = :boutiqueId ORDER BY v.lastActivityAt DESC")
    Page<Visitor> findActiveVisitorsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId, Pageable pageable);

    @Query("SELECT v FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.userId IS NOT NULL ORDER BY v.lastActivityAt DESC")
    Page<Visitor> findAuthenticatedVisitorsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId, Pageable pageable);

    @Query("SELECT v FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.userId IS NULL ORDER BY v.lastActivityAt DESC")
    Page<Visitor> findAnonymousVisitorsByBoutiqueId(@Param("boutiqueId") UUID boutiqueId, Pageable pageable);

    @Query("SELECT v FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.lastActivityAt < :cutoff")
    List<Visitor> findByLastActivityAtBefore(@Param("cutoff") LocalDateTime cutoff);

    List<Visitor> findByBoutiqueIdAndCreatedAtBetween(UUID boutiqueId, LocalDateTime from, LocalDateTime to);

    @Query("SELECT COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.userId IS NOT NULL")
    long countByBoutiqueIdAndUserIdIsNotNull(@Param("boutiqueId") UUID boutiqueId);

    @Query("SELECT COUNT(v) FROM Visitor v WHERE v.boutiqueId = :boutiqueId AND v.userId IS NULL")
    long countByBoutiqueIdAndUserIdIsNull(@Param("boutiqueId") UUID boutiqueId);
}