package io.makewebsite.repository;

import io.makewebsite.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u JOIN FETCH u.tenant WHERE u.email = :email")
    Optional<User> findByEmailWithTenant(String email);

    Optional<User> findByEmailIgnoreCase(String email);

    Optional<User> findByVerificationToken(String verificationToken);

    boolean existsByEmail(String email);

    @Query("SELECT u FROM User u JOIN FETCH u.tenant WHERE u.id = :id")
    Optional<User> findByIdWithTenant(UUID id);

    Optional<User> findByPhone(String phone);

    Optional<User> findByTenantIdAndId(UUID tenantId, UUID id);

    boolean existsByPhone(String phone);

    long countByRole(String role);
}
