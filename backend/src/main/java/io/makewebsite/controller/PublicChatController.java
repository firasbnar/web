package io.makewebsite.controller;

import io.makewebsite.dto.request.PublicChatRequest;
import io.makewebsite.dto.response.AiResponse;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.service.AiService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicChatController {

    private static final Logger log = LoggerFactory.getLogger(PublicChatController.class);
    private static final int RATE_LIMIT_MAX = 30;
    private static final long RATE_LIMIT_WINDOW_MS = 3600_000;

    private final AiService aiService;

    private final Map<String, List<Long>> rateLimitMap = new ConcurrentHashMap<>();

    @PostMapping("/stores/{slug}/ai/chat")
    public ResponseEntity<?> storeAiChat(@PathVariable String slug, @RequestBody PublicChatRequest req, HttpServletRequest httpReq) {
        String clientIp = httpReq.getRemoteAddr();
        if (isRateLimited(clientIp)) {
            log.warn("Rate limit exceeded for IP: {}", clientIp);
            return ResponseEntity.status(429).body(Map.of(
                "success", false,
                "error", "Trop de requetes. Reessayez dans une heure."
            ));
        }
        AiResponse response = aiService.publicStoreChat(slug, req.getMessage(), req.getSessionId(), req.getMessages());
        return ResponseEntity.ok(ApiResponse.ok(response));
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
