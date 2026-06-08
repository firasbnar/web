package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GuestConversationDetailResponse {
    private UUID id;
    private String customerName;
    private String customerEmail;
    private String customerPhone;
    private String status;
    private LocalDateTime createdAt;
    private List<MessageResponse> messages;
}
