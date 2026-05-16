package io.makewebsite.dto.request;

import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TelegramSettingsRequest {

    @Pattern(regexp = "^\\d*$", message = "L'ID Chat Telegram doit être numérique")
    private String telegramChatId;

    private Boolean telegramEnabled;
}
