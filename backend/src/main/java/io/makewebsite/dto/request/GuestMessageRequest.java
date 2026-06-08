package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GuestMessageRequest {

    @NotBlank
    @Size(max = 150)
    private String customerName;

    @Size(max = 150)
    private String email;

    @Size(max = 20)
    private String phone;

    @NotBlank
    private String message;
}
