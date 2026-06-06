package io.makewebsite.controller;

import io.makewebsite.dto.request.ConnectTelegramRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.User;
import io.makewebsite.repository.UserRepository;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.TelegramService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/telegram")
@RequiredArgsConstructor
public class TelegramController {

    private final TelegramService telegramService;
    private final UserRepository userRepository;

    @PutMapping("/chat-id")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateChatId(
            @Valid @RequestBody ConnectTelegramRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        String cleaned = request.getTelegramChatId().replaceAll("[^0-9]", "");
        if (cleaned.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("L'ID Chat Telegram doit être un nombre valide"));
        }

        user.setTelegramChatId(cleaned);
        user.setTelegramEnabled(true);
        userRepository.save(user);

        log.info("User {} saved Telegram chatId={}", user.getId(), cleaned);

        Map<String, Object> data = new HashMap<>();
        data.put("chatId", cleaned);
        data.put("enabled", true);
        return ResponseEntity.ok(ApiResponse.ok("ID Telegram enregistré", data));
    }

    @PostMapping("/test")
    public ResponseEntity<ApiResponse<Map<String, Object>>> test(
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        if (user.getTelegramChatId() == null || user.getTelegramChatId().isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Aucun ID Telegram enregistré. Enregistrez-le d'abord."));
        }

        boolean sent = telegramService.sendTestMessage(user.getTelegramChatId());
        Map<String, Object> data = new HashMap<>();
        data.put("chatId", user.getTelegramChatId());
        data.put("sent", sent);
        if (sent) {
            return ResponseEntity.ok(ApiResponse.ok("Message de test envoyé !", data));
        } else {
            return ResponseEntity.ok(ApiResponse.ok("Tentative d'envoi... Vérifiez les logs ou la configuration du bot.", data));
        }
    }
}