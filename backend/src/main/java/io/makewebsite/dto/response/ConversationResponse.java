package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConversationResponse {
    private UUID id;
    private UUID boutiqueId;
    private String customerName;
    private String customerEmail;
    private String customerPhone;
    private LocalDateTime lastMessageAt;
    private String lastMessagePreview;
    private int unreadCount;
    private LocalDateTime createdAt;
}
