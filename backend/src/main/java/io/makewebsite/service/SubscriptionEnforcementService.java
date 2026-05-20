package io.makewebsite.service;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class SubscriptionEnforcementService {

    private final SubscriptionRepository subscriptionRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final AdminAuditLogRepository auditLogRepository;

    @Transactional
    public int enforceAll() {
        int frozen = 0;
        List<Subscription> expired = subscriptionRepository.findByStatusIn(List.of("EXPIRED", "CANCELLED"));
        for (Subscription s : expired) {
            List<Boutique> boutiques = boutiqueRepository.findByUserId(s.getUser().getId());
            for (Boutique b : boutiques) {
                if (!"FROZEN".equals(b.getStoreStatus())) {
                    freezeStore(b, "SUBSCRIPTION_" + s.getStatus());
                    frozen++;
                }
            }
        }

        List<Subscription> activeWithPastEnd = subscriptionRepository.findByStatusAndExpiresAtBefore("ACTIVE", LocalDateTime.now());
        for (Subscription s : activeWithPastEnd) {
            s.setStatus("EXPIRED");
            subscriptionRepository.save(s);
            List<Boutique> boutiques = boutiqueRepository.findByUserId(s.getUser().getId());
            for (Boutique b : boutiques) {
                if (!"FROZEN".equals(b.getStoreStatus())) {
                    freezeStore(b, "SUBSCRIPTION_EXPIRED");
                    frozen++;
                }
            }
        }

        if (frozen > 0) {
            log.info("SubscriptionEnforcementService: frozen {} stores due to subscription status", frozen);
        }
        return frozen;
    }

    @Transactional
    public void freezeStore(Boutique b, String reason) {
        b.setStoreStatus("FROZEN");
        b.setFrozenAt(LocalDateTime.now());
        b.setFreezeReason(reason);
        boutiqueRepository.save(b);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(java.util.UUID.randomUUID())
                .adminEmail("system@makewebsite.io")
                .action("AUTO_FREEZE_STORE").targetType("STORE")
                .targetId(b.getId()).details("Gel automatique: " + reason)
                .build());
    }
}
