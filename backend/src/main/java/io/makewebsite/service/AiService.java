package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.makewebsite.dto.response.AiResponse;
import io.makewebsite.entity.AiConversation;
import io.makewebsite.entity.User;
import io.makewebsite.repository.AiConversationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.*;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class AiService {
    private final AiConversationRepository aiConversationRepository;
    private final ObjectMapper objectMapper;

    @Value("${openai.api-key:}")
    private String apiKey;

    @Value("${openai.model:gpt-4o}")
    private String model;

    private static final String SYSTEM_PROMPT = "Tu es un assistant e-commerce expert pour boutiques tunisiennes. Tu aides les propriétaires de boutiques en ligne à gérer leurs ventes, optimiser leur catalogue, améliorer leur SEO, et analyser leurs performances. Réponds en français.";

    @Transactional
    public AiResponse chat(UUID userId, String message) {
        AiConversation userMsg = AiConversation.builder()
                .user(User.builder().id(userId).build())
                .role("user")
                .content(message)
                .createdAt(LocalDateTime.now())
                .build();
        aiConversationRepository.save(userMsg);

        List<AiConversation> history = aiConversationRepository.findByUserIdOrderByCreatedAtAsc(userId);

        if (apiKey == null || apiKey.isEmpty() || "YOUR_OPENAI_API_KEY".equals(apiKey)) {
            return AiResponse.builder()
                    .reply("L'assistant IA n'est pas configuré. Ajoutez votre clé OpenAI dans application.properties.")
                    .history(Collections.emptyList())
                    .build();
        }

        try {
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("model", model);

            ArrayNode messages = requestBody.putArray("messages");
            ObjectNode systemMsg = objectMapper.createObjectNode();
            systemMsg.put("role", "system");
            systemMsg.put("content", SYSTEM_PROMPT);
            messages.add(systemMsg);

            for (AiConversation conv : history) {
                ObjectNode msg = objectMapper.createObjectNode();
                msg.put("role", conv.getRole());
                msg.put("content", conv.getContent());
                messages.add(msg);
            }

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);

            HttpEntity<String> entity = new HttpEntity<>(objectMapper.writeValueAsString(requestBody), headers);
            RestTemplate restTemplate = new RestTemplate();

            ResponseEntity<String> response = restTemplate.postForEntity(
                    "https://api.openai.com/v1/chat/completions", entity, String.class);

            JsonNode responseJson = objectMapper.readTree(response.getBody());
            String reply = responseJson.get("choices").get(0).get("message").get("content").asText();

            AiConversation aiMsg = AiConversation.builder()
                    .user(User.builder().id(userId).build())
                    .role("assistant")
                    .content(reply)
                    .createdAt(LocalDateTime.now())
                    .build();
            aiConversationRepository.save(aiMsg);

            List<Map<String, Object>> historyList = new ArrayList<>();
            for (AiConversation conv : history) {
                Map<String, Object> item = new HashMap<>();
                item.put("role", conv.getRole());
                item.put("content", conv.getContent());
                historyList.add(item);
            }
            Map<String, Object> replyItem = new HashMap<>();
            replyItem.put("role", "assistant");
            replyItem.put("content", reply);
            historyList.add(replyItem);

            return AiResponse.builder().reply(reply).history(historyList).build();
        } catch (Exception e) {
            return AiResponse.builder()
                    .reply("Désolé, je n'ai pas pu traiter votre demande. Veuillez réessayer.")
                    .history(Collections.emptyList())
                    .build();
        }
    }

    public List<Map<String, Object>> getHistory(UUID userId) {
        List<AiConversation> history = aiConversationRepository.findByUserIdOrderByCreatedAtAsc(userId);
        List<Map<String, Object>> result = new ArrayList<>();
        for (AiConversation conv : history) {
            Map<String, Object> item = new HashMap<>();
            item.put("role", conv.getRole());
            item.put("content", conv.getContent());
            result.add(item);
        }
        return result;
    }

    @Transactional
    public void deleteHistory(UUID userId) {
        aiConversationRepository.deleteByUserId(userId);
    }
}
