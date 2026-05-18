package io.makewebsite.service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.*;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UploadService {
    private static final long MAX_IMAGE_BYTES = 5L * 1024L * 1024L;

    @Value("${upload.path:./uploads/}")
    private String uploadPath;
    @Value("${app.public-url:http://localhost:8080}")
    private String publicUrl;
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
        return uploadImage(file, "");
    }

    public String uploadImage(MultipartFile file, String folder) {
        validateImage(file);
        return uploadFile(file, folder);
    }

    public String uploadFile(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) throw new IllegalArgumentException("Fichier vide ou manquant");
        String originalName = Paths.get(file.getOriginalFilename() == null ? "" : file.getOriginalFilename())
                .getFileName()
                .toString();
        String extension = extensionFrom(originalName);
        if (extension.isBlank()) {
            extension = extensionFromContentType(file.getContentType());
        }
        if (extension.isBlank()) throw new IllegalArgumentException("Type de fichier non supporte");
        String fileName = UUID.randomUUID() + extension;
        String prefix = normalizeFolder(folder);

        Path basePath = absoluteUploadPath != null ? absoluteUploadPath : Paths.get(uploadPath).toAbsolutePath().normalize();
        Path targetDir = prefix.isBlank() ? basePath : basePath.resolve(prefix).normalize();
        if (!targetDir.startsWith(basePath)) {
            throw new IllegalArgumentException("Chemin d'upload invalide");
        }
        Path targetFile = targetDir.resolve(fileName).normalize();
        if (!targetFile.startsWith(targetDir)) {
            throw new IllegalArgumentException("Nom de fichier invalide");
        }

        try {
            Files.createDirectories(targetDir);
            Files.copy(file.getInputStream(), targetFile, StandardCopyOption.REPLACE_EXISTING);
            return publicUrl.replaceAll("/+$", "") + "/uploads/" + (prefix.isBlank() ? "" : prefix + "/") + fileName;
        } catch (FileAlreadyExistsException e) {
            return publicUrl.replaceAll("/+$", "") + "/uploads/" + (prefix.isBlank() ? "" : prefix + "/") + fileName;
        } catch (IOException e) {
            throw new RuntimeException("Erreur lors de l'upload: " + e.getMessage());
        }
    }

    public void deletePublicUrl(String url) {
        if (url == null || url.isBlank()) return;
        String marker = "/uploads/";
        int index = url.indexOf(marker);
        if (index < 0) return;
        String relative = url.substring(index + marker.length()).replace("\\", "/");
        if (relative.contains("..")) return;
        Path basePath = absoluteUploadPath != null ? absoluteUploadPath : Paths.get(uploadPath).toAbsolutePath().normalize();
        Path target = basePath.resolve(relative).normalize();
        if (!target.startsWith(basePath)) return;
        try {
            Files.deleteIfExists(target);
        } catch (IOException ignored) {
        }
    }

    private void validateImage(MultipartFile file) {
        if (file == null || file.isEmpty()) throw new IllegalArgumentException("Image vide ou manquante");
        if (file.getSize() > MAX_IMAGE_BYTES) throw new IllegalArgumentException("Image trop volumineuse (max 5MB)");

        String extension = extensionFrom(file.getOriginalFilename()).toLowerCase(Locale.ROOT);
        String contentType = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        if ((!contentType.isBlank() && !contentType.startsWith("image/"))
                || !(extension.equals(".jpg") || extension.equals(".jpeg")
                || extension.equals(".png") || extension.equals(".webp") || extension.equals(".gif"))) {
            throw new IllegalArgumentException("Seuls les fichiers image JPG, PNG, WEBP ou GIF sont acceptes");
        }

        try (InputStream input = file.getInputStream()) {
            byte[] header = input.readNBytes(12);
            if (!hasKnownImageSignature(header)) {
                throw new IllegalArgumentException("Fichier image invalide");
            }
        } catch (IOException e) {
            throw new RuntimeException("Impossible de lire l'image: " + e.getMessage());
        }
    }

    private boolean hasKnownImageSignature(byte[] bytes) {
        return bytes.length >= 3
                && ((bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF)
                || bytes.length >= 8
                && (bytes[0] & 0xFF) == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47
                || bytes.length >= 12
                && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46
                && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50
                || bytes.length >= 6
                && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
    }

    private String normalizeFolder(String folder) {
        if (folder == null || folder.isBlank()) return "";
        return folder.replace("\\", "/")
                .replaceAll("^/+", "")
                .replaceAll("/+$", "");
    }

    private String extensionFrom(String fileName) {
        if (fileName != null && fileName.contains(".")) {
            return fileName.substring(fileName.lastIndexOf(".")).toLowerCase(Locale.ROOT);
        }
        return "";
    }

    private String extensionFromContentType(String contentType) {
        if (contentType == null) return "";
        return switch (contentType.toLowerCase(Locale.ROOT)) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "image/gif" -> ".gif";
            default -> "";
        };
    }
}
