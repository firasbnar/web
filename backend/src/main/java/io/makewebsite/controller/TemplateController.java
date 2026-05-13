package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/templates")
@RequiredArgsConstructor
public class TemplateController {
    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTemplates() {
        return ResponseEntity.ok(ApiResponse.ok(List.of()));
    }
}
