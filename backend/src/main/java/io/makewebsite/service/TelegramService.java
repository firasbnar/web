package io.makewebsite.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Service
@Slf4j
public class TelegramService {

    @Value("${telegram.bot-token:}")
    private String botToken;

    @Value("${telegram.enabled:false}")
    private boolean enabled;

    private static final String TELEGRAM_API = "https://api.telegram.org/bot";

    public boolean isEnabled() {
        return enabled && botToken != null && !botToken.trim().isEmpty();
    }

    public boolean verifyToken() {
        if (!isEnabled()) {
            log.warn("Telegram is disabled or bot token not configured — skipping verifyToken");
            return false;
        }
        try {
            RestTemplate restTemplate = new RestTemplate();
            String url = TELEGRAM_API + botToken + "/getMe";
            log.info("Verifying Telegram bot token...");
            String response = restTemplate.getForObject(url, String.class);
            if (response != null && response.contains("\"ok\":true")) {
                log.info("Telegram bot token verified successfully");
                return true;
            } else {
                log.error("Telegram bot token verification failed — response: {}", response);
                return false;
            }
        } catch (Exception e) {
            log.error("Failed to verify Telegram bot token: {}", e.getMessage());
            return false;
        }
    }

    @Async
    public void sendMessage(String chatId, String message) {
        if (!isEnabled()) {
            log.debug("Telegram disabled or token not configured — not sending message to chatId={}", chatId);
            return;
        }
        if (chatId == null || chatId.trim().isEmpty()) {
            log.debug("No Telegram chatId provided — skipping message");
            return;
        }
        try {
            RestTemplate restTemplate = new RestTemplate();
            String url = TELEGRAM_API + botToken + "/sendMessage";

            Map<String, Object> body = Map.of(
                "chat_id", chatId,
                "text", message,
                "parse_mode", "HTML"
            );

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);

            ResponseEntity<String> response = restTemplate.postForEntity(url, request, String.class);
            if (response.getBody() != null && response.getBody().contains("\"ok\":true")) {
                log.info("Telegram message sent successfully to chatId={}", chatId);
            } else {
                log.warn("Telegram sendMessage returned unexpected response for chatId={}: {}", chatId, response.getBody());
            }
        } catch (Exception e) {
            log.error("Failed to send Telegram message to chatId={}: {}", chatId, e.getMessage());
        }
    }

    public boolean sendTestMessage(String chatId) {
        if (!isEnabled()) {
            log.warn("Telegram is disabled — cannot send test message");
            return false;
        }
        if (chatId == null || chatId.trim().isEmpty()) {
            log.warn("No chatId provided for test message");
            return false;
        }
        boolean verified = verifyToken();
        if (!verified) {
            log.warn("Bot token verification failed — test message may not be sent");
        }
        sendMessage(chatId, "\u2705 Test notification de MakeWebsite\n\nVotre bot Telegram est correctement configur\u00e9 !");
        return true;
    }
}
