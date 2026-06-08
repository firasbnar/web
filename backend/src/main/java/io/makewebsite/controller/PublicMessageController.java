package io.makewebsite.controller;

import io.makewebsite.dto.request.GuestMessageRequest;
import io.makewebsite.dto.response.ConversationResponse;
import io.makewebsite.dto.response.GuestConversationDetailResponse;
import io.makewebsite.dto.response.GuestConversationResponse;
import io.makewebsite.dto.response.MessageResponse;
import io.makewebsite.entity.Conversation;
import io.makewebsite.service.MessageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicMessageController {

    private final MessageService messageService;

    @PostMapping("/stores/{slug}/messages")
    public ResponseEntity<GuestConversationResponse> sendGuestMessage(
            @PathVariable String slug,
            @Valid @RequestBody GuestMessageRequest request) {
        log.info("Guest message from {} for store slug={}", request.getCustomerName(), slug);
        GuestConversationResponse response = messageService.sendGuestMessage(slug, request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/conversations/{conversationId}")
    public ResponseEntity<?> getGuestConversation(
            @PathVariable UUID conversationId,
            @RequestParam String token) {
        log.info("Guest fetching conversation id={}", conversationId);

        Conversation conversation;
        try {
            conversation = messageService.getGuestConversation(conversationId, token);
        } catch (RuntimeException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", "Conversation non trouvée"));
        }

        List<MessageResponse> messages = messageService.getMessages(conversationId);

        GuestConversationDetailResponse response = GuestConversationDetailResponse.builder()
                .id(conversation.getId())
                .customerName(conversation.getCustomerName())
                .customerEmail(conversation.getCustomerEmail())
                .customerPhone(conversation.getCustomerPhone())
                .status(conversation.getStatus())
                .createdAt(conversation.getCreatedAt())
                .messages(messages)
                .build();

        return ResponseEntity.ok(response);
    }

    @PostMapping("/conversations/{conversationId}/reply")
    public ResponseEntity<?> replyAsGuest(
            @PathVariable UUID conversationId,
            @RequestParam String token,
            @RequestBody Map<String, String> body) {
        String content = body.get("message");
        if (content == null || content.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Message requis"));
        }

        log.info("Guest replying to conversation id={}", conversationId);

        try {
            MessageResponse response = messageService.replyAsGuest(conversationId, token, content);
            return ResponseEntity.ok(Map.of("success", true, "data", response));
        } catch (RuntimeException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", "Conversation non trouvée"));
        }
    }
}
