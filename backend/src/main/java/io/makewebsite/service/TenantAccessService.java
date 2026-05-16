package io.makewebsite.service;

import io.makewebsite.entity.Boutique;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.security.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TenantAccessService {
    private final BoutiqueRepository boutiqueRepository;

    public UUID currentTenantIdOrThrow() {
        UUID tenantId = TenantContext.getTenantId();
        if (tenantId == null && !TenantContext.isSuperAdmin()) {
            throw new SecurityException("Tenant context missing");
        }
        return tenantId;
    }

    public Boutique requireBoutiqueAccess(UUID boutiqueId) {
        if (TenantContext.isSuperAdmin()) {
            return boutiqueRepository.findById(boutiqueId)
                    .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        }
        UUID tenantId = currentTenantIdOrThrow();
        return boutiqueRepository.findByIdAndTenantId(boutiqueId, tenantId)
                .orElseThrow(() -> new SecurityException("Accès tenant refusé"));
    }

    public void requireTenant(UUID tenantId) {
        if (TenantContext.isSuperAdmin()) {
            return;
        }
        UUID currentTenantId = currentTenantIdOrThrow();
        if (!currentTenantId.equals(tenantId)) {
            throw new SecurityException("Accès tenant refusé");
        }
    }
}
