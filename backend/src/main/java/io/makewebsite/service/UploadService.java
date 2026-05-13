package io.makewebsite.service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.nio.file.*;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UploadService {
    @Value("${upload.path:./uploads/}")
    private String uploadPath;
    private Path absoluteUploadPath;

    @PostConstruct
    public void init() {
        try {
            absoluteUploadPath = Paths.get(uploadPath).toAbsolutePath().normalize();
            Files.createDirectories(absoluteUploadPath);
        } catch (IOException e) {
            throw new RuntimeException("Could not create upload directory: " + e.getMessage());
        }
    }

    public String getUploadPath() {
        if (absoluteUploadPath == null) {
            absoluteUploadPath = Paths.get(uploadPath).toAbsolutePath().normalize();
        }
        return absoluteUploadPath.toString().replace("\\", "/") + "/";
    }

    public String uploadImage(MultipartFile file) {
        return uploadFile(file, "");
    }

    public String uploadFile(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) throw new RuntimeException("Fichier vide ou manquant");
        String originalName = file.getOriginalFilename();
        String extension = "";
        if (originalName != null && originalName.contains(".")) {
            extension = originalName.substring(originalName.lastIndexOf("."));
        }
        String fileName = UUID.randomUUID().toString() + extension;
        String prefix = folder == null || folder.isBlank() ? "" : folder.replace("\\", "/") + "/";
        Path basePath = absoluteUploadPath != null ? absoluteUploadPath : Paths.get(uploadPath).toAbsolutePath().normalize();
        Path targetDir = folder == null || folder.isBlank()
                ? basePath
                : basePath.resolve(folder);
        try {
            Files.createDirectories(targetDir);
            Files.copy(file.getInputStream(), targetDir.resolve(fileName), StandardCopyOption.REPLACE_EXISTING);
            return "http://localhost:8080/uploads/" + prefix + fileName;
        } catch (FileAlreadyExistsException e) {
            return "http://localhost:8080/uploads/" + prefix + fileName;
        } catch (IOException e) {
            throw new RuntimeException("Erreur lors de l'upload: " + e.getMessage());
        }
    }
}
