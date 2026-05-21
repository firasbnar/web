package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BoutiqueSummaryResponse {
    private UUID boutiqueId;
    private String boutiqueName;
    private String publicUrl;
    private long views;
    private long products;
    private long remainingDays;
    private String planName;
    private String subscriptionStatus;
    private String subscriptionEndDate;
    private String publicationStatus;
}