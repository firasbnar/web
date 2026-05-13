package io.makewebsite.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateCustomerRequest {
    @NotNull
    private UUID boutiqueId;

    @NotBlank
    private String fullName;

    @Email
    private String email;

    private String phone;

    private String address;

    private String city;

    private String governorate;

    private String notes;
}
