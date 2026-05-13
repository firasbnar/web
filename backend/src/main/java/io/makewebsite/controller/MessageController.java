package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
public class MessageController {
    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getConversations(@RequestParam UUID boutiqueId) {
        return ResponseEntity.ok(ApiResponse.ok(List.of()));
    }
}
