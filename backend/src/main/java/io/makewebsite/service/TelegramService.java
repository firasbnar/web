package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
@Slf4j
public class TelegramService {

    @Value("${telegram.bot-token:}")
    private String botToken;

    @Value("${telegram.bot-username:}")
    private String botUsername;

    @Value("${telegram.enabled:false}")
    private boolean enabled;

    private static final String TELEGRAM_API = "https://api.telegram.org/bot";

    private final ObjectMapper objectMapper = new ObjectMapper();

    public String getBotUsername() {
        return botUsername;
    }

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
        sendMessage(chatId, "\u2705 Telegram connect\u00E9 avec succ\u00E8s\n\nVous recevrez d\u00E9sormais les notifications de votre boutique MakeWebsite.io.");
        return true;
    }

    public List<TelegramUpdate> getUpdates() {
        List<TelegramUpdate> result = new ArrayList<>();
        if (!isEnabled()) {
            log.warn("Telegram is disabled — cannot get updates");
            return result;
        }
        try {
            RestTemplate restTemplate = new RestTemplate();
            String url = TELEGRAM_API + botToken + "/getUpdates?timeout=5&limit=100";
            String json = restTemplate.getForObject(url, String.class);
            if (json == null || !json.contains("\"ok\":true")) {
                log.warn("Telegram getUpdates returned unexpected response");
                return result;
            }
            JsonNode root = objectMapper.readTree(json);
            JsonNode updates = root.get("result");
            if (updates == null || !updates.isArray()) {
                return result;
            }
            for (JsonNode update : updates) {
                JsonNode message = update.get("message");
                if (message == null) continue;
                JsonNode chat = message.get("chat");
                if (chat == null) continue;
                JsonNode chatIdNode = chat.get("id");
                JsonNode textNode = message.get("text");
                if (chatIdNode == null) continue;
                String chatId = chatIdNode.asText();
                String text = textNode != null ? textNode.asText("") : "";
                result.add(new TelegramUpdate(chatId, text));
            }
            log.info("Telegram getUpdates returned {} messages", result.size());
        } catch (Exception e) {
            log.error("Failed to get Telegram updates: {}", e.getMessage());
        }
        return result;
    }

    public static class TelegramUpdate {
        private final String chatId;
        private final String text;

        public TelegramUpdate(String chatId, String text) {
            this.chatId = chatId;
            this.text = text;
        }

        public String getChatId() { return chatId; }
        public String getText() { return text; }
    }
}
