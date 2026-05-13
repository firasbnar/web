package io.makewebsite.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class SetActiveBoutiqueRequest {
    @NotNull
    private UUID boutiqueId;
}
