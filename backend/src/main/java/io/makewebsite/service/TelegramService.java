package io.makewebsite.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
@Slf4j
@RequiredArgsConstructor
public class TelegramService {
    @Value("${telegram.bot-token:}")
    private String botToken;

    @Async
    public void sendMessage(String chatId, String message) {
        if (chatId == null || chatId.isEmpty() || botToken == null || botToken.isEmpty()) {
            return;
        }
        try {
            RestTemplate restTemplate = new RestTemplate();
            String url = "https://api.telegram.org/bot" + botToken + "/sendMessage" +
                    "?chat_id=" + chatId + "&text=" + java.net.URLEncoder.encode(message, "UTF-8");
            restTemplate.getForObject(url, String.class);
        } catch (Exception e) {
            log.error("Failed to send Telegram message: {}", e.getMessage());
        }
    }
}
