package io.makewebsite.service;

import io.makewebsite.entity.Boutique;
import io.makewebsite.exception.StoreFrozenException;
import io.makewebsite.repository.BoutiqueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StoreStatusGuard {

    private final BoutiqueRepository boutiqueRepository;

    public Boutique requireActive(UUID boutiqueId) {
        Boutique b = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        requireActive(b);
        return b;
    }

    public void requireActive(Boutique boutique) {
        if ("FROZEN".equals(boutique.getStoreStatus())) {
            String reason = boutique.getFreezeReason() != null ? boutique.getFreezeReason() : "Non spécifiée";
            throw new StoreFrozenException(
                    "Cette boutique est actuellement gelée. Veuillez régulariser l'abonnement. Raison : " + reason);
        }
        if ("SUSPENDED".equals(boutique.getStoreStatus())) {
            throw new StoreFrozenException(
                    "Cette boutique a été suspendue. Contactez le support.");
        }
    }

    public void requireActiveByOrder(UUID orderId, io.makewebsite.repository.OrderRepository orderRepository) {
        io.makewebsite.entity.Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Commande non trouvée"));
        requireActive(order.getBoutique());
    }
}
