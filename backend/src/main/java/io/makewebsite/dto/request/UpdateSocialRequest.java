package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateSocialRequest {
    private String facebookUrl;
    private String instagramUrl;
    private String tiktokUrl;
    private String whatsappNumber;
}
