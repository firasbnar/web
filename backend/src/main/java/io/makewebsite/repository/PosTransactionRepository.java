package io.makewebsite.repository;

import io.makewebsite.entity.PosTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PosTransactionRepository extends JpaRepository<PosTransaction, UUID> {

    List<PosTransaction> findBySessionId(UUID sessionId);
}
