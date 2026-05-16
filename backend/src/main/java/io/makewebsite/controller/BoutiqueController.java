package io.makewebsite.controller;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.service.BoutiqueService;
import io.makewebsite.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/boutiques")
@RequiredArgsConstructor
public class BoutiqueController {
    private final BoutiqueService boutiqueService;

    @GetMapping("/mine")
    public ResponseEntity<ApiResponse<List<BoutiqueResponse>>> getMyBoutiques(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(boutiqueService.getMyBoutiques(principal.getUserId())));
    }

    @GetMapping("/{id}/dashboard")
    public ResponseEntity<ApiResponse<DashboardResponse>> getDashboard(@PathVariable UUID id, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(boutiqueService.getDashboard(id, principal.getUserId())));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> getBoutique(@PathVariable UUID id, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(boutiqueService.getBoutique(id, principal.getUserId())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<BoutiqueResponse>> createBoutique(@Valid @RequestBody CreateBoutiqueRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Boutique créée", boutiqueService.createBoutique(request, principal.getUserId())));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> updateBoutique(@PathVariable UUID id, @Valid @RequestBody UpdateBoutiqueRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Boutique mise à jour", boutiqueService.updateBoutique(id, request, principal.getUserId())));
    }

    @PutMapping("/{id}/theme")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> updateTheme(@PathVariable UUID id, @Valid @RequestBody UpdateThemeRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Thème mis à jour", boutiqueService.updateTheme(id, request, principal.getUserId())));
    }

    @PutMapping("/{id}/seo")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> updateSeo(@PathVariable UUID id, @Valid @RequestBody UpdateSeoRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("SEO mis à jour", boutiqueService.updateSeo(id, request, principal.getUserId())));
    }

    @PutMapping("/{id}/social")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> updateSocial(@PathVariable UUID id, @Valid @RequestBody UpdateSocialRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Réseaux sociaux mis à jour", boutiqueService.updateSocial(id, request, principal.getUserId())));
    }

    @PutMapping("/{id}/payments")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> updatePayments(@PathVariable UUID id, @Valid @RequestBody UpdatePaymentRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Moyens de paiement mis à jour", boutiqueService.updatePayments(id, request, principal.getUserId())));
    }

    @GetMapping("/public")
    public ResponseEntity<ApiResponse<List<BoutiqueResponse>>> getPublicBoutiques() {
        return ResponseEntity.ok(ApiResponse.ok(boutiqueService.getPublicBoutiques()));
    }

    @GetMapping("/{id}/stats")
    public ResponseEntity<ApiResponse<BoutiqueStatsResponse>> getStats(@PathVariable UUID id, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(boutiqueService.getStats(id, principal.getUserId())));
    }

    @PutMapping("/{id}/telegram-settings")
    public ResponseEntity<ApiResponse<BoutiqueResponse>> updateTelegramSettings(
            @PathVariable UUID id,
            @Valid @RequestBody TelegramSettingsRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        BoutiqueResponse response = boutiqueService.updateTelegramSettings(id, request, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Paramètres Telegram mis à jour", response));
    }
}
