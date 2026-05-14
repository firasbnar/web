package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.dto.response.UploadResponse;
import io.makewebsite.service.UploadService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/upload")
@RequiredArgsConstructor
public class UploadController {
    private final UploadService uploadService;

    @PostMapping("/image")
    public ResponseEntity<ApiResponse<UploadResponse>> uploadImage(@RequestParam(value = "file", required = false) MultipartFile file) {
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Fichier vide ou manquant"));
        }
        String url = uploadService.uploadImage(file);
        return ResponseEntity.ok(ApiResponse.ok(UploadResponse.builder().url(url).build()));
    }
}
