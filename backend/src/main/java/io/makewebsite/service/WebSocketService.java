package io.makewebsite.service;

import io.makewebsite.dto.response.*;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class WebSocketService {
    private final SimpMessagingTemplate messagingTemplate;

    public void sendNewOrderNotification(UUID boutiqueId, OrderResponse order) {
        messagingTemplate.convertAndSend("/topic/orders/" + boutiqueId, order);
    }

    public void sendNewMessageNotification(UUID boutiqueId, ConversationResponse conversation) {
        messagingTemplate.convertAndSend("/topic/messages/" + boutiqueId, conversation);
    }

    public void sendVisitorUpdate(UUID boutiqueId, TrafficStatsResponse stats) {
        messagingTemplate.convertAndSend("/topic/traffic/" + boutiqueId + "/stats", stats);
    }

    public void sendActiveVisitorCount(UUID boutiqueId, long count) {
        messagingTemplate.convertAndSend("/topic/traffic/" + boutiqueId + "/active", count);
    }

    public void sendVisitorListUpdate(UUID boutiqueId, Object visitorPage) {
        messagingTemplate.convertAndSend("/topic/traffic/" + boutiqueId + "/visitors", visitorPage);
    }
}
