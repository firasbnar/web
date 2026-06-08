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
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/telegram")
@RequiredArgsConstructor
public class TelegramController {

    private final TelegramService telegramService;
    private final UserRepository userRepository;

    private static final String CODE_PREFIX = "MW-";
    private static final int CODE_LENGTH = 6;
    private static final int CODE_EXPIRY_MINUTES = 10;
    private static final String ALLOWED_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    // ── New code-based connection flow ──

    @Transactional
    @PostMapping("/connect/start")
    public ResponseEntity<Map<String, Object>> startConnection(
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        String code = generateUniqueCode();
        user.setTelegramConnectionCode(code);
        user.setTelegramConnectionCodeExpiresAt(LocalDateTime.now().plusMinutes(CODE_EXPIRY_MINUTES));
        userRepository.save(user);

        log.info("Telegram connect start: userId={}, code={}, expiresAt={}",
                user.getId(), code, user.getTelegramConnectionCodeExpiresAt());

        Map<String, Object> data = new HashMap<>();
        data.put("botUsername", telegramService.getBotUsername());
        data.put("connectionCode", code);
        data.put("expiresAt", user.getTelegramConnectionCodeExpiresAt().toString());
        return ResponseEntity.ok(Map.of("success", true, "data", data));
    }

    @Transactional
    @PostMapping("/connect/verify")
    public ResponseEntity<Map<String, Object>> verifyConnection(
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        String code = user.getTelegramConnectionCode();
        if (code == null || code.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "Aucun code de connexion généré. Cliquez d'abord sur Connecter Telegram."
            ));
        }

        if (user.getTelegramConnectionCodeExpiresAt() == null
                || user.getTelegramConnectionCodeExpiresAt().isBefore(LocalDateTime.now())) {
            user.setTelegramConnectionCode(null);
            user.setTelegramConnectionCodeExpiresAt(null);
            userRepository.save(user);
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "Le code de connexion a expiré. Générez un nouveau code."
            ));
        }

        List<TelegramService.TelegramUpdate> updates = telegramService.getUpdates();
        String matchedChatId = null;

        for (TelegramService.TelegramUpdate update : updates) {
            if (code.equals(update.getText().trim())) {
                matchedChatId = update.getChatId();
                break;
            }
        }

        if (matchedChatId == null) {
            return ResponseEntity.ok().body(Map.of(
                    "success", false,
                    "message", "Code non trouvé. Assurez-vous d'avoir envoyé le code exact au bot @" + telegramService.getBotUsername() + " dans Telegram, puis réessayez."
            ));
        }

        user.setTelegramChatId(matchedChatId);
        user.setTelegramEnabled(true);
        user.setTelegramConnected(true);
        user.setTelegramConnectionCode(null);
        user.setTelegramConnectionCodeExpiresAt(null);
        userRepository.save(user);

        telegramService.sendMessage(matchedChatId,
                "\u2705 Telegram connect\u00E9 avec succ\u00E8s\n\n"
                + "Vous recevrez d\u00E9sormais les notifications de votre boutique MakeWebsite.io.");

        log.info("Telegram connect verified: userId={}, chatId={}", user.getId(), matchedChatId);

        Map<String, Object> data = new HashMap<>();
        data.put("connected", true);
        data.put("chatId", maskChatId(matchedChatId));
        return ResponseEntity.ok(Map.of("success", true, "data", data));
    }

    @Transactional
    @DeleteMapping("/disconnect")
    public ResponseEntity<Map<String, Object>> disconnect(
            @AuthenticationPrincipal UserPrincipal principal) {
        User user = userRepository.findById(principal.getUserId())
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        user.setTelegramChatId(null);
        user.setTelegramEnabled(false);
        user.setTelegramConnected(false);
        user.setTelegramConnectionCode(null);
        user.setTelegramConnectionCodeExpiresAt(null);
        userRepository.save(user);

        log.info("Telegram disconnected: userId={}", user.getId());

        return ResponseEntity.ok(Map.of("success", true, "message", "Telegram déconnecté"));
    }

    // ── Existing endpoints (kept for backward compatibility) ──

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
        user.setTelegramConnected(true);
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
            return ResponseEntity.badRequest().body(ApiResponse.error("Aucun ID Telegram enregistré. Connectez Telegram d'abord."));
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

    // ── Helpers ──

    private String generateUniqueCode() {
        int attempts = 0;
        while (attempts < 20) {
            StringBuilder sb = new StringBuilder(CODE_PREFIX);
            for (int i = 0; i < CODE_LENGTH; i++) {
                sb.append(ALLOWED_CHARS.charAt(RANDOM.nextInt(ALLOWED_CHARS.length())));
            }
            String code = sb.toString();
            if (!userRepository.existsByTelegramConnectionCode(code)) {
                return code;
            }
            attempts++;
        }
        throw new RuntimeException("Impossible de générer un code unique");
    }

    private String maskChatId(String chatId) {
        if (chatId == null || chatId.length() < 4) return chatId;
        return chatId.substring(0, 2) + "****" + chatId.substring(chatId.length() - 2);
    }
}
