package io.makewebsite.controller;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.InvoiceService;
import io.makewebsite.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {
    private final OrderService orderService;
    private final InvoiceService invoiceService;

    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<OrderResponse>>> getOrders(
            @RequestParam UUID boutiqueId,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<OrderResponse> page = orderService.getOrders(boutiqueId, status, search, startDate, endDate, pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/my-orders")
    public ResponseEntity<ApiResponse<PagedResponse<OrderResponse>>> getMyOrders(
            @AuthenticationPrincipal UserPrincipal principal,
            @PageableDefault(size = 20) Pageable pageable) {
        Page<OrderResponse> page = orderService.getMyOrders(principal.getUserId(), pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<OrderResponse>> getOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(orderService.getOrder(id)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<OrderResponse>> createOrder(
            @Valid @RequestBody CreateOrderRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Commande créée", orderService.createOrder(request, principal.getUserId())));
    }

    @PostMapping("/public")
    public ResponseEntity<ApiResponse<OrderResponse>> createPublicOrder(@Valid @RequestBody CreateOrderRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Commande créée", orderService.createOrder(request, null)));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<ApiResponse<OrderResponse>> updateStatus(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateOrderStatusRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Statut mis à jour", orderService.updateStatus(id, request)));
    }

    @PutMapping("/{id}/payment")
    public ResponseEntity<ApiResponse<OrderResponse>> updatePayment(
            @PathVariable UUID id,
            @Valid @RequestBody UpdatePaymentStatusRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Paiement mis à jour", orderService.updatePayment(id, request)));
    }

    @PutMapping("/{id}/tracking")
    public ResponseEntity<ApiResponse<OrderResponse>> updateTracking(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateTrackingRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Suivi mis à jour", orderService.updateTracking(id, request)));
    }

    @PutMapping("/{id}/refund")
    public ResponseEntity<ApiResponse<OrderResponse>> refundOrder(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok("Commande remboursée", orderService.refundOrder(id)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteOrder(@PathVariable UUID id) {
        orderService.deleteOrder(id);
        return ResponseEntity.ok(ApiResponse.ok("Commande supprimée", null));
    }

    @GetMapping("/export")
    public ResponseEntity<String> exportCsv(@RequestParam UUID boutiqueId) {
        String csv = orderService.exportCsv(boutiqueId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv"));
        headers.setContentDisposition(ContentDisposition.attachment().filename("commandes.csv").build());
        return new ResponseEntity<>(csv, headers, HttpStatus.OK);
    }

    @PostMapping("/{id}/invoice")
    public ResponseEntity<ApiResponse<String>> generateInvoice(@PathVariable UUID id) {
        String invoiceNumber = invoiceService.generateInvoice(id);
        return ResponseEntity.ok(ApiResponse.ok("Facture générée", invoiceNumber));
    }

    @GetMapping("/{id}/invoice")
    public ResponseEntity<String> getInvoice(@PathVariable UUID id) {
        String html = invoiceService.buildInvoiceHtml(id);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.TEXT_HTML);
        return new ResponseEntity<>(html, headers, HttpStatus.OK);
    }
}
