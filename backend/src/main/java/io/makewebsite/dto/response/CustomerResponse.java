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
public class CustomerResponse {
    private UUID id;
    private UUID boutiqueId;
    private String fullName;
    private String email;
    private String phone;
    private String address;
    private String city;
    private String governorate;
    private String notes;
    private LocalDateTime createdAt;
    private long totalOrders;
    private double totalSpent;
    private LocalDateTime lastOrderDate;
}
