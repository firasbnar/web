package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CashierResponse {
    private UUID id;
    private String fullName;
    private String email;
    private String role;
    private boolean isActive;
    private boolean isSuspended;
    private String phone;
    private BigDecimal totalVentes;
    private long commandesCount;
    private boolean online;
    private String lastActivity;
}
