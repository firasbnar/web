package io.makewebsite.service;

import io.makewebsite.dto.request.ReplyRequest;
import io.makewebsite.dto.request.SendMessageRequest;
import io.makewebsite.dto.response.ConversationResponse;
import io.makewebsite.dto.response.MessageResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Conversation;
import io.makewebsite.entity.Message;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.ConversationRepository;
import io.makewebsite.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MessageService {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final WebSocketService webSocketService;

    @Transactional(readOnly = true)
    public List<ConversationResponse> getConversations(UUID boutiqueId) {
        List<Conversation> conversations = conversationRepository.findByBoutiqueIdOrderByLastMessageAtDesc(boutiqueId);
        return conversations.stream()
                .map(this::mapToConversationResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<MessageResponse> getMessages(UUID conversationId) {
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
            throw new RuntimeException("La messagerie client est désactivée pour cette boutique");
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

        webSocketService.sendNewMessageNotification(boutiqueId, mapToConversationResponse(conversation));

        return mapToMessageResponse(message);
    }

    @Transactional
    public MessageResponse replyToConversation(UUID boutiqueId, UUID userId, ReplyRequest request) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
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
                .senderType("BOUTIQUE")
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

        webSocketService.sendNewMessageNotification(boutiqueId, mapToConversationResponse(conversation));

        return mapToMessageResponse(message);
    }

    @Transactional
    public void markAsRead(UUID conversationId) {
        messageRepository.markAllAsRead(conversationId);
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new RuntimeException("Conversation non trouvée"));
        conversation.setUnreadCount(0);
        conversationRepository.save(conversation);
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
