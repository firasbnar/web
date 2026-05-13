package io.makewebsite.dto.request;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdatePaymentRequest {
    private Boolean enablePaypal;
    private Boolean enableCod;
    private Boolean enableD17;
    private Boolean enableAdeex;
    private Boolean enableJax;
    private Boolean enableIntigo;
}
