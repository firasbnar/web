package io.makewebsite.service;

import io.makewebsite.dto.request.GuestMessageRequest;
import io.makewebsite.dto.request.ReplyRequest;
import io.makewebsite.dto.request.SendMessageRequest;
import io.makewebsite.dto.response.ConversationResponse;
import io.makewebsite.dto.response.GuestConversationResponse;
import io.makewebsite.dto.response.MessageResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Conversation;
import io.makewebsite.entity.Message;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.ConversationRepository;
import io.makewebsite.repository.MessageRepository;
import io.makewebsite.security.Permission;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MessageService {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final WebSocketService webSocketService;
    private final TelegramNotificationService telegramNotificationService;
    private final BoutiquePermissionService boutiquePermissionService;

    @Transactional(readOnly = true)
    public List<ConversationResponse> getConversations(UUID boutiqueId, UUID userId) {
        boutiquePermissionService.requireBoutiquePermission(userId, boutiqueId, Permission.MESSAGE_READ);
        List<Conversation> conversations = conversationRepository.findByBoutiqueIdOrderByLastMessageAtDesc(boutiqueId);
        return conversations.stream()
                .map(this::mapToConversationResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<MessageResponse> getMessages(UUID conversationId, UUID userId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new RuntimeException("Conversation non trouvee"));
        boutiquePermissionService.requireBoutiquePermission(userId, conversation.getBoutique().getId(), Permission.MESSAGE_READ);
        List<Message> messages = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversationId);
        return messages.stream()
                .map(this::mapToMessageResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<MessageResponse> getGuestMessages(UUID conversationId) {
        List<Message> messages = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversationId);
        return messages.stream()
                .map(this::mapToMessageResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public MessageResponse sendMessage(UUID boutiqueId, SendMessageRequest request) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        if (Boolean.FALSE.equals(boutique.getClientMessagingEnabled())) {
            throw new AccessDeniedException("La messagerie client est desactivee pour cette boutique");
        }

        Optional<Conversation> existingConversation = conversationRepository
                .findByBoutiqueIdAndCustomerEmail(boutiqueId, request.getCustomerEmail());

        Conversation conversation = existingConversation.orElseGet(() -> {
            Conversation newConversation = Conversation.builder()
                    .boutique(boutique)
                    .customerName(request.getCustomerName())
                    .customerEmail(request.getCustomerEmail())
                    .customerPhone(request.getCustomerPhone())
                    .build();
            return conversationRepository.save(newConversation);
        });

        if (!existingConversation.isPresent()) {
            conversation.setCustomerName(request.getCustomerName());
            if (request.getCustomerPhone() != null) {
                conversation.setCustomerPhone(request.getCustomerPhone());
            }
        }

        if (Boolean.FALSE.equals(conversation.getBoutique().getClientMessagingEnabled())) {
            throw new AccessDeniedException("La messagerie client est desactivee pour cette boutique");
        }

        Message message = Message.builder()
                .boutique(boutique)
                .conversation(conversation)
                .customerName(request.getCustomerName())
                .customerEmail(request.getCustomerEmail())
                .customerPhone(request.getCustomerPhone())
                .senderType("CUSTOMER")
                .content(request.getContent())
                .build();
        message = messageRepository.save(message);

        conversation.setLastMessageAt(message.getCreatedAt());
        conversation.setLastMessagePreview(
                request.getContent().length() > 100
                        ? request.getContent().substring(0, 100) + "..."
                        : request.getContent()
        );
        conversation.setUnreadCount(
                (conversation.getUnreadCount() != null ? conversation.getUnreadCount() : 0) + 1
        );
        conversationRepository.save(conversation);

        ConversationResponse convResp = mapToConversationResponse(conversation);
        log.info("Broadcasting auth customer message to /topic/stores/{}/conversations", boutiqueId);
        webSocketService.sendNewMessageNotification(boutiqueId, convResp);
        webSocketService.sendMessageToConversation(conversation.getId(), Map.of(
            "type", "NEW_MESSAGE",
            "messageId", message.getId().toString(),
            "conversationId", conversation.getId().toString(),
            "senderType", "CUSTOMER",
            "content", request.getContent(),
            "unreadCount", conversation.getUnreadCount(),
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));
        telegramNotificationService.notifyNewCustomerMessage(conversation, request.getContent());

        return mapToMessageResponse(message);
    }

    @Transactional
    public MessageResponse replyToConversation(UUID boutiqueId, UUID userId, ReplyRequest request) {
        boutiquePermissionService.requireBoutiquePermission(userId, boutiqueId, Permission.MESSAGE_WRITE);
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        Conversation conversation = conversationRepository.findById(request.getConversationId())
                .orElseThrow(() -> new RuntimeException("Conversation non trouvée"));

        if (!conversation.getBoutique().getId().equals(boutiqueId)) {
            throw new RuntimeException("Conversation non trouvée");
        }

        messageRepository.markAllAsRead(request.getConversationId());

        Message message = Message.builder()
                .boutique(boutique)
                .conversation(conversation)
                .senderType("MERCHANT")
                .content(request.getContent())
                .build();
        message = messageRepository.save(message);

        conversation.setLastMessageAt(message.getCreatedAt());
        conversation.setLastMessagePreview(
                request.getContent().length() > 100
                        ? request.getContent().substring(0, 100) + "..."
                        : request.getContent()
        );
        conversation.setUnreadCount(0);
        conversationRepository.save(conversation);

        ConversationResponse convResp = mapToConversationResponse(conversation);
        log.info("Broadcasting merchant reply to /topic/stores/{}/conversations and /topic/public/conversations/{}", boutiqueId, conversation.getId());
        webSocketService.sendNewMessageNotification(boutiqueId, convResp);
        webSocketService.sendMessageToConversation(conversation.getId(), Map.of(
            "type", "NEW_MESSAGE",
            "messageId", message.getId().toString(),
            "conversationId", conversation.getId().toString(),
            "senderType", "MERCHANT",
            "content", request.getContent(),
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));
        webSocketService.sendMerchantReplyToVisitor(conversation.getId(), Map.of(
            "type", "NEW_MESSAGE",
            "messageId", message.getId().toString(),
            "conversationId", conversation.getId().toString(),
            "senderType", "MERCHANT",
            "content", request.getContent(),
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));

        return mapToMessageResponse(message);
    }

    @Transactional
    public void markAsRead(UUID conversationId, UUID userId) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new RuntimeException("Conversation non trouvée"));
        boutiquePermissionService.requireBoutiquePermission(userId, conversation.getBoutique().getId(), Permission.MESSAGE_READ);
        messageRepository.markAllAsRead(conversationId);
        conversation.setUnreadCount(0);
        conversationRepository.save(conversation);
    }

    // --- Guest conversation methods ---

    @Transactional
    public GuestConversationResponse sendGuestMessage(String slug, GuestMessageRequest request) {
        Boutique boutique = boutiqueRepository.findBySlug(slug)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        if (Boolean.FALSE.equals(boutique.getClientMessagingEnabled())) {
            throw new AccessDeniedException("La messagerie client est desactivee pour cette boutique");
        }

        String guestToken = UUID.randomUUID().toString();

        Conversation conversation = Conversation.builder()
                .boutique(boutique)
                .customerName(request.getCustomerName())
                .customerEmail(request.getEmail())
                .customerPhone(request.getPhone())
                .guestToken(guestToken)
                .status("OPEN")
                .build();
        conversation = conversationRepository.save(conversation);

        Message message = Message.builder()
                .boutique(boutique)
                .conversation(conversation)
                .customerName(request.getCustomerName())
                .customerEmail(request.getEmail())
                .customerPhone(request.getPhone())
                .senderType("CUSTOMER")
                .content(request.getMessage())
                .build();
        message = messageRepository.save(message);

        conversation.setLastMessageAt(message.getCreatedAt());
        conversation.setLastMessagePreview(
                request.getMessage().length() > 100
                        ? request.getMessage().substring(0, 100) + "..."
                        : request.getMessage()
        );
        conversation.setUnreadCount(1);
        conversationRepository.save(conversation);

        ConversationResponse convResp = mapToConversationResponse(conversation);
        UUID storeId = boutique.getId();
        log.info("Broadcasting merchant message to /topic/stores/{}/conversations", storeId);
        webSocketService.sendNewMessageNotification(storeId, convResp);
        webSocketService.sendNewConversationToMerchant(storeId, Map.of(
            "type", "NEW_CONVERSATION",
            "conversationId", conversation.getId().toString(),
            "storeId", storeId.toString(),
            "customerName", request.getCustomerName(),
            "message", request.getMessage(),
            "unreadCount", conversation.getUnreadCount(),
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));
        webSocketService.sendMessageToConversation(conversation.getId(), Map.of(
            "type", "NEW_MESSAGE",
            "messageId", message.getId().toString(),
            "conversationId", conversation.getId().toString(),
            "senderType", "CUSTOMER",
            "content", request.getMessage(),
            "unreadCount", conversation.getUnreadCount(),
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));
        telegramNotificationService.notifyNewCustomerMessage(conversation, request.getMessage());

        return GuestConversationResponse.builder()
                .success(true)
                .conversationId(conversation.getId())
                .guestToken(guestToken)
                .build();
    }

    @Transactional(readOnly = true)
    public Conversation getGuestConversation(UUID conversationId, String guestToken) {
        Conversation conversation = conversationRepository.findByIdAndGuestToken(conversationId, guestToken)
                .orElseThrow(() -> new RuntimeException("Conversation non trouvée"));
        return conversation;
    }

    @Transactional
    public MessageResponse replyAsGuest(UUID conversationId, String guestToken, String content) {
        Conversation conversation = conversationRepository.findByIdAndGuestToken(conversationId, guestToken)
                .orElseThrow(() -> new RuntimeException("Conversation non trouvée"));

        if (Boolean.FALSE.equals(conversation.getBoutique().getClientMessagingEnabled())) {
            throw new AccessDeniedException("La messagerie client est desactivee pour cette boutique");
        }

        Message message = Message.builder()
                .boutique(conversation.getBoutique())
                .conversation(conversation)
                .customerName(conversation.getCustomerName())
                .customerEmail(conversation.getCustomerEmail())
                .customerPhone(conversation.getCustomerPhone())
                .senderType("CUSTOMER")
                .content(content)
                .build();
        message = messageRepository.save(message);

        conversation.setLastMessageAt(message.getCreatedAt());
        conversation.setLastMessagePreview(
                content.length() > 100 ? content.substring(0, 100) + "..." : content
        );
        conversation.setUnreadCount(
                (conversation.getUnreadCount() != null ? conversation.getUnreadCount() : 0) + 1
        );
        conversationRepository.save(conversation);

        ConversationResponse convResp = mapToConversationResponse(conversation);
        UUID boutiqueId = conversation.getBoutique().getId();
        log.info("Broadcasting guest reply to /topic/stores/{}/conversations", boutiqueId);
        webSocketService.sendNewMessageNotification(boutiqueId, convResp);
        webSocketService.sendMessageToConversation(conversationId, Map.of(
            "type", "NEW_MESSAGE",
            "messageId", message.getId().toString(),
            "conversationId", conversationId.toString(),
            "senderType", "CUSTOMER",
            "content", content,
            "unreadCount", conversation.getUnreadCount(),
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));
        webSocketService.sendMerchantReplyToVisitor(conversationId, Map.of(
            "type", "NEW_MESSAGE",
            "messageId", message.getId().toString(),
            "conversationId", conversationId.toString(),
            "senderType", "CUSTOMER",
            "content", content,
            "createdAt", message.getCreatedAt() != null ? message.getCreatedAt().toString() : ""
        ));

        return mapToMessageResponse(message);
    }

    private ConversationResponse mapToConversationResponse(Conversation c) {
        return ConversationResponse.builder()
                .id(c.getId())
                .boutiqueId(c.getBoutique().getId())
                .customerName(c.getCustomerName())
                .customerEmail(c.getCustomerEmail())
                .customerPhone(c.getCustomerPhone())
                .lastMessageAt(c.getLastMessageAt())
                .lastMessagePreview(c.getLastMessagePreview())
                .unreadCount(c.getUnreadCount() != null ? c.getUnreadCount() : 0)
                .createdAt(c.getCreatedAt())
                .build();
    }

    private MessageResponse mapToMessageResponse(Message m) {
        return MessageResponse.builder()
                .id(m.getId())
                .conversationId(m.getConversation().getId())
                .senderType(m.getSenderType())
                .content(m.getContent())
                .isRead(m.getIsRead() != null ? m.getIsRead() : false)
                .createdAt(m.getCreatedAt())
                .build();
    }
}
