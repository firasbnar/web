package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserResponse {
    private UUID id;
    private String fullName;
    private String email;
    private String phone;
    private String role;
    private UUID tenantId;
    private String language;
    private String avatarUrl;
    private boolean emailVerified;
    private String authProvider;
    private String providerId;
}
