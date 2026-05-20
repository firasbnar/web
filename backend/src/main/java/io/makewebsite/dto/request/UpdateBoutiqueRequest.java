package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateBoutiqueRequest {
    private String name;
    private String description;
    private String email;
    private String phone;
    private String address;
    private String currency;
    private String language;
    private String timezone;
    private String customDomain;
    private String slug;
}
