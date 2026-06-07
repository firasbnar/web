package io.makewebsite.controller;

import io.makewebsite.dto.request.AiChatRequest;
import io.makewebsite.dto.request.ChatRequest;
import io.makewebsite.dto.response.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.AiService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiController {
    private final AiService aiService;

    @PostMapping("/chat")
    public ResponseEntity<ApiResponse<AiResponse>> chat(@Valid @RequestBody ChatRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(aiService.ownerChat(
                principal.getUserId(),
                request.getBoutiqueId(),
                request.getMessage(),
                request.getSessionId()
        )));
    }

    @PostMapping("/merchant-chat")
    public ResponseEntity<ApiResponse<AiChatResponse>> merchantChat(@Valid @RequestBody AiChatRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(aiService.merchantChat(
                principal.getUserId(),
                request.getBoutiqueId(),
                request.getMessage()
        )));
    }

    @PostMapping("/owner/chat")
    public ResponseEntity<ApiResponse<AiResponse>> ownerChat(@Valid @RequestBody ChatRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(aiService.ownerChat(
                principal.getUserId(),
                request.getBoutiqueId(),
                request.getMessage(),
                request.getSessionId()
        )));
    }

    @GetMapping("/history")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getHistory(@AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok(aiService.getHistory(principal.getUserId())));
    }

    @DeleteMapping("/history")
    public ResponseEntity<ApiResponse<Void>> deleteHistory(@AuthenticationPrincipal UserPrincipal principal) {
        aiService.deleteHistory(principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok("Historique supprimé", null));
    }
}
