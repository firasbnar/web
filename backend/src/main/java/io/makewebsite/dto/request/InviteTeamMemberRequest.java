package io.makewebsite.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InviteTeamMemberRequest {
    @NotBlank
    @Email
    private String email;

    @Pattern(regexp = "(?i)^(ADMIN|MANAGER|STAFF)$", message = "Role d'equipe invalide")
    private String role;

    @NotNull
    private UUID boutiqueId;
}
