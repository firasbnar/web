package io.makewebsite.controller;

import io.makewebsite.dto.request.PublicChatRequest;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicChatController {

    private static final Logger log = LoggerFactory.getLogger(PublicChatController.class);
    private static final int RATE_LIMIT_MAX = 30;
    private static final long RATE_LIMIT_WINDOW_MS = 3600_000;

    private final RestTemplate restTemplate;

    @Value("${anthropic.api.key}")
    private String anthropicApiKey;

    private final Map<String, List<Long>> rateLimitMap = new ConcurrentHashMap<>();

    @PostMapping("/chat")
    public ResponseEntity<?> chat(@RequestBody PublicChatRequest req, HttpServletRequest httpReq) {

        String clientIp = httpReq.getRemoteAddr();
        if (isRateLimited(clientIp)) {
            log.warn("Rate limit exceeded for IP: {}", clientIp);
            return ResponseEntity.status(429).body(Map.of(
                "success", false,
                "error", "Trop de requetes. Reessayez dans une heure."
            ));
        }

        if (anthropicApiKey == null || anthropicApiKey.isBlank() || "YOUR_ANTHROPIC_API_KEY".equals(anthropicApiKey)) {
            return ResponseEntity.status(503).body(Map.of(
                "success", false,
                "error", "Claude API non configuree. Veuillez configurer ANTHROPIC_API_KEY."
            ));
        }

        try {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("model", "claude-haiku-4-5-20251001");
            body.put("max_tokens", 400);
            body.put("system", req.getSystemPrompt());
            body.put("messages", req.getMessages() != null ? req.getMessages() : List.of());

            HttpHeaders headers = new HttpHeaders();
            headers.set("x-api-key", anthropicApiKey);
            headers.set("anthropic-version", "2023-06-01");
            headers.setContentType(MediaType.APPLICATION_JSON);

            ResponseEntity<Map> response = restTemplate.exchange(
                "https://api.anthropic.com/v1/messages",
                HttpMethod.POST,
                new HttpEntity<>(body, headers),
                Map.class
            );

            return ResponseEntity.ok(response.getBody());

        } catch (Exception e) {
            log.error("Claude API call failed: {}", e.getMessage());
            return ResponseEntity.status(502).body(Map.of(
                "success", false,
                "error", "Erreur de communication avec l'assistant. Reessayez."
            ));
        }
    }

    private boolean isRateLimited(String ip) {
        long now = System.currentTimeMillis();
        long cutoff = now - RATE_LIMIT_WINDOW_MS;

        List<Long> timestamps = rateLimitMap.computeIfAbsent(ip, k -> Collections.synchronizedList(new ArrayList<>()));

        synchronized (timestamps) {
            timestamps.removeIf(t -> t < cutoff);
            if (timestamps.size() >= RATE_LIMIT_MAX) {
                return true;
            }
            timestamps.add(now);
            return false;
        }
    }
}
