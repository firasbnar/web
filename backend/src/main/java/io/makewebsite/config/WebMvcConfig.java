package io.makewebsite.config;

import io.makewebsite.service.UploadService;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final UploadService uploadService;

    public WebMvcConfig(UploadService uploadService) {
        this.uploadService = uploadService;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String uploadPath = uploadService.getUploadPath();
        String resourceLocation = new java.io.File(uploadPath).toURI().toString();
        registry.addResourceHandler("/uploads/**")
            .addResourceLocations(resourceLocation)
            .setCachePeriod(3600);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/uploads/**")
            .allowedOriginPatterns("*")
            .allowedMethods("GET", "HEAD", "OPTIONS")
            .allowedHeaders("*")
            .maxAge(3600);
    }
}
