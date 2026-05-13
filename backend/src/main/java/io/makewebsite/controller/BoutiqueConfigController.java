package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.BoutiqueConfig;
import io.makewebsite.repository.BoutiqueConfigRepository;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/boutiques/{boutiqueId}/config")
@RequiredArgsConstructor
public class BoutiqueConfigController {
    private final BoutiqueConfigRepository configRepository;
    private final BoutiqueRepository boutiqueRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, String>>>> getConfigs(@PathVariable UUID boutiqueId, @AuthenticationPrincipal UserPrincipal principal) {
        boutiqueRepository.findByUserIdAndId(principal.getUserId(), boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        List<Map<String, String>> list = configRepository.findByBoutiqueId(boutiqueId).stream().map(c -> {
            Map<String, String> m = new LinkedHashMap<>();
            m.put("key", c.getConfigKey());
            m.put("value", c.getConfigValue());
            return m;
        }).toList();
        return ResponseEntity.ok(ApiResponse.ok(list));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<Void>> updateConfigs(@PathVariable UUID boutiqueId, @RequestBody Map<String, String> configs, @AuthenticationPrincipal UserPrincipal principal) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(principal.getUserId(), boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        configs.forEach((key, value) -> {
            BoutiqueConfig cfg = configRepository.findByBoutiqueIdAndConfigKey(boutiqueId, key)
                    .orElse(BoutiqueConfig.builder().boutique(boutique).configKey(key).build());
            cfg.setConfigValue(value);
            configRepository.save(cfg);
        });
        return ResponseEntity.ok(ApiResponse.ok("Configuration mise à jour", null));
    }

    @DeleteMapping("/{key}")
    public ResponseEntity<ApiResponse<Void>> deleteConfig(@PathVariable UUID boutiqueId, @PathVariable String key, @AuthenticationPrincipal UserPrincipal principal) {
        boutiqueRepository.findByUserIdAndId(principal.getUserId(), boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        configRepository.deleteByBoutiqueIdAndConfigKey(boutiqueId, key);
        return ResponseEntity.ok(ApiResponse.ok("Configuration supprimée", null));
    }
}
