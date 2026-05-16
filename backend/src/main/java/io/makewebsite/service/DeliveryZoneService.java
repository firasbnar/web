package io.makewebsite.service;

import io.makewebsite.dto.request.DeliveryZoneRequest;
import io.makewebsite.dto.response.DeliveryZoneResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DeliveryZoneService {
    private final DeliveryZoneRepository deliveryZoneRepository;
    private final BoutiqueRepository boutiqueRepository;

    public List<DeliveryZoneResponse> getZones(UUID boutiqueId, UUID userId) {
        boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        return deliveryZoneRepository.findByBoutiqueIdOrderByFeeAsc(boutiqueId).stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public DeliveryZoneResponse createZone(UUID boutiqueId, DeliveryZoneRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        DeliveryZone zone = DeliveryZone.builder()
                .boutique(boutique)
                .name(request.getName())
                .countries(request.getCountries() != null ? request.getCountries() : "")
                .fee(request.getFee() != null ? request.getFee() : 0.0)
                .minOrderAmount(request.getMinOrderAmount())
                .estimatedDays(request.getEstimatedDays() != null ? request.getEstimatedDays() : 3)
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .build();
        zone = deliveryZoneRepository.save(zone);
        return mapToResponse(zone);
    }

    @Transactional
    public DeliveryZoneResponse updateZone(UUID zoneId, UUID boutiqueId, DeliveryZoneRequest request, UUID userId) {
        boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        DeliveryZone zone = deliveryZoneRepository.findById(zoneId)
                .orElseThrow(() -> new RuntimeException("Zone non trouvée"));
        if (!zone.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Accès refusé");
        }
        if (request.getName() != null) zone.setName(request.getName());
        if (request.getCountries() != null) zone.setCountries(request.getCountries());
        if (request.getFee() != null) zone.setFee(request.getFee());
        if (request.getMinOrderAmount() != null) zone.setMinOrderAmount(request.getMinOrderAmount());
        if (request.getEstimatedDays() != null) zone.setEstimatedDays(request.getEstimatedDays());
        if (request.getIsActive() != null) zone.setIsActive(request.getIsActive());
        zone = deliveryZoneRepository.save(zone);
        return mapToResponse(zone);
    }

    @Transactional
    public void deleteZone(UUID zoneId, UUID boutiqueId, UUID userId) {
        boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        DeliveryZone zone = deliveryZoneRepository.findById(zoneId)
                .orElseThrow(() -> new RuntimeException("Zone non trouvée"));
        if (!zone.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Accès refusé");
        }
        deliveryZoneRepository.delete(zone);
    }

    private DeliveryZoneResponse mapToResponse(DeliveryZone z) {
        return DeliveryZoneResponse.builder()
                .id(z.getId())
                .boutiqueId(z.getBoutique().getId())
                .name(z.getName())
                .countries(z.getCountries())
                .fee(z.getFee())
                .minOrderAmount(z.getMinOrderAmount())
                .estimatedDays(z.getEstimatedDays())
                .isActive(z.getIsActive())
                .createdAt(z.getCreatedAt())
                .build();
    }
}
