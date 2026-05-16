package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.StoreSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/stores/{storeId}/settings")
@RequiredArgsConstructor
public class StoreSettingsController {
    private final StoreSettingsService storeSettingsService;

    @GetMapping("/countries")
    public ResponseEntity<ApiResponse<List<String>>> getCountries(
            @PathVariable UUID storeId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(
                storeSettingsService.getAcceptedCountries(storeId, principal.getUserId())));
    }

    @PutMapping("/countries")
    @Transactional
    public ResponseEntity<ApiResponse<List<String>>> updateCountries(
            @PathVariable UUID storeId,
            @RequestBody Map<String, List<String>> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        List<String> countries = body.getOrDefault("countries", List.of());
        return ResponseEntity.ok(ApiResponse.ok("Pays acceptes mis a jour",
                storeSettingsService.replaceAcceptedCountries(storeId, principal.getUserId(), countries)));
    }

    @PutMapping("/branding")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateBranding(
            @PathVariable UUID storeId,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Branding mis a jour",
                storeSettingsService.updateBranding(storeId, principal.getUserId(), body)));
    }

    @PutMapping("/currency")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateCurrency(
            @PathVariable UUID storeId,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Devise mise a jour",
                storeSettingsService.updateCurrency(storeId, principal.getUserId(), body.get("currency"))));
    }

    @PostMapping("/logo")
    public ResponseEntity<ApiResponse<Map<String, Object>>> uploadLogo(
            @PathVariable UUID storeId,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Logo mis a jour",
                storeSettingsService.uploadLogo(storeId, principal.getUserId(), file)));
    }
}
