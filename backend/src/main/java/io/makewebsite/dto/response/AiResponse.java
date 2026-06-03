package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiResponse {
    private String type;
    private String reply;
    private List<Map<String, Object>> products;
    private List<Map<String, Object>> recommendations;
    private Map<String, Object> analytics;
    private List<Map<String, Object>> history;
}
