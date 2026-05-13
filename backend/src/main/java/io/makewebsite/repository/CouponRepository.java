package io.makewebsite.repository;

import io.makewebsite.entity.Coupon;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CouponRepository extends JpaRepository<Coupon, UUID> {

    List<Coupon> findByBoutiqueId(UUID boutiqueId);

    Optional<Coupon> findByBoutiqueIdAndCode(UUID boutiqueId, String code);
}
