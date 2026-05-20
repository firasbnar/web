package io.makewebsite.config;

import io.makewebsite.repository.BoutiqueRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Set;

@Component
@RequiredArgsConstructor
public class StoreSlugFilter extends OncePerRequestFilter {

    private final BoutiqueRepository boutiqueRepository;

    private static final Set<String> RESERVED_PATHS = Set.of(
        "login", "register", "error", "api", "store", "checkout",
        "flutter", "assets", "uploads", "ws", "favicon",
        "admin", "super-admin", "dashboard", "plans"
    );

    private static final Set<String> FILE_EXTENSIONS = Set.of(
        ".js", ".json", ".png", ".jpg", ".jpeg", ".ico", ".css",
        ".map", ".svg", ".wasm", ".webp", ".gif", ".woff", ".woff2",
        ".ttf", ".eot", ".pdf", ".xml", ".txt"
    );

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if (!"GET".equalsIgnoreCase(request.getMethod())) return true;

        String path = request.getServletPath();

        // Root or empty path
        if (path.isEmpty() || "/".equals(path) || "/index.html".equals(path)) return true;

        // Only single-segment paths (no / after the first)
        if (path.indexOf('/', 1) >= 0) return true;

        // Strip leading /
        String segment = path.substring(1);

        // Reserved paths
        if (RESERVED_PATHS.contains(segment)) return true;

        // File extensions
        int dot = segment.lastIndexOf('.');
        if (dot >= 0 && FILE_EXTENSIONS.contains(segment.substring(dot))) return true;

        return false;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String path = request.getServletPath();
        String slug = path.substring(1);

        if (boutiqueRepository.existsBySlug(slug)) {
            response.sendRedirect("/store/" + slug);
            return;
        }

        filterChain.doFilter(request, response);
    }
}
