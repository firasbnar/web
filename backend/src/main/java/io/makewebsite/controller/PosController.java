package io.makewebsite.controller;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.service.PosService;
import io.makewebsite.security.UserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/pos")
@RequiredArgsConstructor
public class PosController {
    private final PosService posService;

    @PostMapping("/sessions/open")
    public ResponseEntity<ApiResponse<PosSessionResponse>> openSession(@Valid @RequestBody OpenPosSessionRequest request, @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(ApiResponse.ok("Session ouverte", posService.openSession(request, principal.getUserId())));
    }

    @PostMapping("/sessions/{id}/close")
    public ResponseEntity<ApiResponse<PosSessionResponse>> closeSession(@PathVariable UUID id, @Valid @RequestBody ClosePosSessionRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Session fermée", posService.closeSession(id, request)));
    }

    @GetMapping("/sessions/active")
    public ResponseEntity<ApiResponse<PosSessionResponse>> getActiveSession(@RequestParam UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(posService.getActiveSession(boutiqueId)));
    }

    @GetMapping("/sessions/{id}/summary")
    public ResponseEntity<ApiResponse<PosSessionResponse>> getSessionSummary(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(posService.getSessionSummary(id)));
    }

    @PostMapping("/transactions")
    public ResponseEntity<ApiResponse<PosTransactionResponse>> createTransaction(@Valid @RequestBody CreatePosTransactionRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Transaction effectuée", posService.createTransaction(request)));
    }
}
