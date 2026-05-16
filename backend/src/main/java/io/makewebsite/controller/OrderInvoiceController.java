package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.InvoiceResponse;
import io.makewebsite.service.InvoiceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/boutiques/{boutiqueId}/orders/{orderId}/invoice")
@RequiredArgsConstructor
@Slf4j
public class OrderInvoiceController {
    private final InvoiceService invoiceService;

    @GetMapping
    public ResponseEntity<ApiResponse<InvoiceResponse>> getInvoice(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID orderId) {
        return ResponseEntity.ok(ApiResponse.ok(invoiceService.getInvoice(boutiqueId, orderId)));
    }

    @GetMapping("/print")
    public ResponseEntity<String> printInvoice(
            @PathVariable UUID boutiqueId,
            @PathVariable UUID orderId) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.TEXT_HTML);
        headers.setContentDisposition(ContentDisposition.inline().filename("facture.html").build());
        try {
            String html = invoiceService.buildInvoiceHtml(boutiqueId, orderId);
            return new ResponseEntity<>(html, headers, HttpStatus.OK);
        } catch (RuntimeException e) {
            log.error("Unable to render invoice for boutique {} order {}", boutiqueId, orderId, e);
            return new ResponseEntity<>(errorHtml(e.getMessage()), headers, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private String errorHtml(String message) {
        String safeMessage = message == null ? "Impossible de generer la facture." : message
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
        return """
                <!DOCTYPE html>
                <html lang="fr">
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Facture indisponible</title>
                  <style>
                    body { margin: 0; padding: 32px; font-family: Arial, sans-serif; color: #172033; background: #f4f6fb; }
                    main { max-width: 640px; margin: 80px auto; background: #fff; border: 1px solid #dde3ef; padding: 28px; }
                    h1 { margin: 0 0 12px; color: #2710BF; font-size: 22px; }
                    p { margin: 0; color: #536176; }
                  </style>
                </head>
                <body><main><h1>Facture indisponible</h1><p>${message}</p></main></body>
                </html>
                """.replace("${message}", safeMessage);
    }
}
