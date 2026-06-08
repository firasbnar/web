package io.makewebsite.repository;

import io.makewebsite.entity.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    List<Conversation> findByBoutiqueIdOrderByLastMessageAtDesc(UUID boutiqueId);

    Optional<Conversation> findByBoutiqueIdAndCustomerEmail(UUID boutiqueId, String customerEmail);

    Optional<Conversation> findByGuestToken(String guestToken);

    Optional<Conversation> findByIdAndGuestToken(UUID id, String guestToken);
}
