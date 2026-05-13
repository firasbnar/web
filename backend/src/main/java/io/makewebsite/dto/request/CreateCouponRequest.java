package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateCouponRequest {
    @NotNull
    private UUID boutiqueId;

    @NotBlank
    private String code;

    private String discountType;

    @NotNull
    private BigDecimal discountValue;

    private BigDecimal minOrderAmount;

    private Integer maxUses;

    private LocalDateTime expiresAt;

    private Boolean isActive;
}
