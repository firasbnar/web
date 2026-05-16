package io.makewebsite.repository;

import io.makewebsite.entity.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.UUID;

@Repository
public interface ActivityLogRepository extends JpaRepository<ActivityLog, UUID> {

    Page<ActivityLog> findByBoutiqueIdOrderByCreatedAtDesc(UUID boutiqueId, Pageable pageable);

    Page<ActivityLog> findByBoutiqueIdAndActionOrderByCreatedAtDesc(UUID boutiqueId, String action, Pageable pageable);

    Page<ActivityLog> findByBoutiqueIdAndStatusOrderByCreatedAtDesc(UUID boutiqueId, String status, Pageable pageable);

    Page<ActivityLog> findByBoutiqueIdAndActionAndStatusOrderByCreatedAtDesc(
            UUID boutiqueId, String action, String status, Pageable pageable);

    long countByBoutiqueIdAndActionAndCreatedAtAfter(UUID boutiqueId, String action, LocalDateTime after);

    long countByBoutiqueIdAndStatusAndCreatedAtAfter(UUID boutiqueId, String status, LocalDateTime after);

    @Query("SELECT a FROM ActivityLog a WHERE a.boutiqueId = :boutiqueId AND " +
           "(:search IS NULL OR LOWER(a.userName) LIKE LOWER(CONCAT('%', :search, '%')) OR LOWER(a.details) LIKE LOWER(CONCAT('%', :search, '%'))) " +
           "ORDER BY a.createdAt DESC")
    Page<ActivityLog> searchByBoutiqueId(@Param("boutiqueId") UUID boutiqueId, @Param("search") String search, Pageable pageable);

    @Query("SELECT a FROM ActivityLog a WHERE a.boutiqueId = :boutiqueId AND " +
           "(:search IS NULL OR LOWER(a.userName) LIKE LOWER(CONCAT('%', :search, '%')) OR LOWER(a.details) LIKE LOWER(CONCAT('%', :search, '%'))) AND " +
           "(:action IS NULL OR a.action = :action) AND " +
           "(:status IS NULL OR a.status = :status) AND " +
           "(:fromDate IS NULL OR a.createdAt >= :fromDate) AND " +
           "(:toDate IS NULL OR a.createdAt <= :toDate) " +
           "ORDER BY a.createdAt DESC")
    Page<ActivityLog> searchFiltered(
            @Param("boutiqueId") UUID boutiqueId,
            @Param("search") String search,
            @Param("action") String action,
            @Param("status") String status,
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate,
            Pageable pageable);

    @Query("SELECT a FROM ActivityLog a WHERE " +
           "(:search IS NULL OR LOWER(a.userName) LIKE LOWER(CONCAT('%', :search, '%')) OR LOWER(a.details) LIKE LOWER(CONCAT('%', :search, '%'))) AND " +
           "(:action IS NULL OR a.action = :action) AND " +
           "(:status IS NULL OR a.status = :status) AND " +
           "(:fromDate IS NULL OR a.createdAt >= :fromDate) AND " +
           "(:toDate IS NULL OR a.createdAt <= :toDate) " +
           "ORDER BY a.createdAt DESC")
    Page<ActivityLog> adminSearchFiltered(
            @Param("search") String search,
            @Param("action") String action,
            @Param("status") String status,
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate,
            Pageable pageable);

    long countByStatusAndCreatedAtAfter(String status, LocalDateTime after);
}
