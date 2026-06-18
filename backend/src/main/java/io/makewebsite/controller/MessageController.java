package io.makewebsite.controller;

import io.makewebsite.dto.request.ReplyRequest;
import io.makewebsite.dto.request.SendMessageRequest;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.ConversationResponse;
import io.makewebsite.dto.response.MessageResponse;
import io.makewebsite.service.MessageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;

    @PostMapping("/public")
    public ResponseEntity<ApiResponse<MessageResponse>> sendMessage(
            @RequestParam UUID boutiqueId,
            @Valid @RequestBody SendMessageRequest request) {
        MessageResponse response = messageService.sendMessage(boutiqueId, request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<ConversationResponse>>> getConversations(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal io.makewebsite.security.UserPrincipal principal) {
        List<ConversationResponse> conversations = messageService.getConversations(boutiqueId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok(conversations));
    }

    @GetMapping("/{conversationId}")
    public ResponseEntity<ApiResponse<List<MessageResponse>>> getMessages(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal io.makewebsite.security.UserPrincipal principal) {
        List<MessageResponse> messages = messageService.getMessages(conversationId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok(messages));
    }

    @PostMapping("/reply")
    public ResponseEntity<ApiResponse<MessageResponse>> reply(
            @RequestParam UUID boutiqueId,
            @AuthenticationPrincipal io.makewebsite.security.UserPrincipal principal,
            @Valid @RequestBody ReplyRequest request) {
        MessageResponse response = messageService.replyToConversation(boutiqueId, principal.getUserId(), request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @PutMapping("/{conversationId}/read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable UUID conversationId,
            @AuthenticationPrincipal io.makewebsite.security.UserPrincipal principal) {
        messageService.markAsRead(conversationId, principal.getUserId());
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
