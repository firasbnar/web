package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PublicChatRequest {
    private UUID boutiqueId;
    private String message;
    private String sessionId;
    private String systemPrompt;
    private List<Map<String, String>> messages;
}
