package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateThemeRequest {
    private String primaryColor;
    private String secondaryColor;
    private String customCss;
    private String logoUrl;
    private String fontFamily;
    private Boolean darkMode;
}
