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
public class DeliveryZoneResponse {
    private UUID id;
    private UUID boutiqueId;
    private String name;
    private String countries;
    private Double fee;
    private Double minOrderAmount;
    private Integer estimatedDays;
    private Boolean isActive;
    private LocalDateTime createdAt;
}
