package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeliveryZoneRequest {
    private String name;
    private String countries;
    private Double fee;
    private Double minOrderAmount;
    private Integer estimatedDays;
    private Boolean isActive;
}
