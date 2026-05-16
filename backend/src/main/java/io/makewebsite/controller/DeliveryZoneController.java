package io.makewebsite.controller;

import io.makewebsite.dto.request.DeliveryZoneRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.DeliveryZoneResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.DeliveryZoneService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/boutiques/{boutiqueId}/delivery-zones")
@RequiredArgsConstructor
public class DeliveryZoneController {
    private final DeliveryZoneService deliveryZoneService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DeliveryZoneResponse>>> getZones(
            @PathVariable UUID boutiqueId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(deliveryZoneService.getZones(boutiqueId, principal.getUserId())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DeliveryZoneResponse>> createZone(
            @PathVariable UUID boutiqueId,
            @Valid @RequestBody DeliveryZoneRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Zone créée",
                deliveryZoneService.createZone(boutiqueId, request, principal.getUserId())));
    }

    @PutMapping("/{zoneId}")
    public ResponseEntity<ApiResponse<DeliveryZoneResponse>> updateZone(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID zoneId,
            @Valid @RequestBody DeliveryZoneRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Zone mise à jour",
                deliveryZoneService.updateZone(zoneId, boutiqueId, request, principal.getUserId())));
    }

    @DeleteMapping("/{zoneId}")
    public ResponseEntity<ApiResponse<Void>> deleteZone(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID zoneId,
            @AuthenticationPrincipal UserPrincipal principal) {
        deliveryZoneService.deleteZone(zoneId, boutiqueId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Zone supprimée", null));
    }
}
