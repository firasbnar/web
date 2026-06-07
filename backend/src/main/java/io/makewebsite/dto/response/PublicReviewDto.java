package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class PublicReviewDto {
    private String customerName;
    private Integer rating;
    private String comment;
    private LocalDateTime createdAt;
}
