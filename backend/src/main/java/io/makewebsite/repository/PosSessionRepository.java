package io.makewebsite.repository;

import io.makewebsite.entity.PosSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PosSessionRepository extends JpaRepository<PosSession, UUID> {

    Optional<PosSession> findByBoutiqueIdAndClosedAtIsNull(UUID boutiqueId);

    List<PosSession> findByBoutiqueIdOrderByOpenedAtDesc(UUID boutiqueId);
}
