package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateRoleRequest {
    @NotBlank
    @Pattern(regexp = "(?i)^(ADMIN|MANAGER|STAFF|CAISSIER|CASHIER|PRODUCT_MANAGER|SUPPORT)$", message = "Role d'equipe invalide")
    private String role;
}
