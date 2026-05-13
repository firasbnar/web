package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateBoutiqueRequest {
    @NotBlank
    private String name;

    @NotBlank
    private String slug;

    private String description;

    @Builder.Default
    private String currency = "TND";

    @Builder.Default
    private String language = "fr";
}
