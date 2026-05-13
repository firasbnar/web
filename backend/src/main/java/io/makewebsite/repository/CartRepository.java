package io.makewebsite.repository;

import io.makewebsite.entity.Cart;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CartRepository extends JpaRepository<Cart, UUID> {
    Optional<Cart> findByUserIdAndBoutiqueId(UUID userId, UUID boutiqueId);
    void deleteByUserIdAndBoutiqueId(UUID userId, UUID boutiqueId);
}
