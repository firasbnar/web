package io.makewebsite.security;

import io.makewebsite.entity.User;
import io.makewebsite.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.UUID;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    public JwtAuthFilter(JwtUtil jwtUtil, UserRepository userRepository) {
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        return path.startsWith("/api/auth/") || path.startsWith("/ws/") || path.startsWith("/api/plans");
    }

    private String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(token.getBytes());
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            return token.substring(0, Math.min(64, token.length()));
        }
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }
        String token = authHeader.substring(7);
        try {
            UUID userId = UUID.fromString(jwtUtil.extractUserId(token));
            User user = userRepository.findByIdWithTenant(userId).orElse(null);
            if (user != null) {
                UserPrincipal userPrincipal = new UserPrincipal(
                        user.getId(), user.getEmail(), user.getPasswordHash(),
                        user.getRole(), user.getTenant().getId(), hashToken(token));
                if (jwtUtil.isTokenValid(token, userPrincipal)) {
                    String tokenTenantId = jwtUtil.extractTenantId(token);
                    UUID principalTenantId = userPrincipal.getTenantId();
                    boolean superAdmin = "SUPER_ADMIN".equals(userPrincipal.getRole());
                    if (!superAdmin && (tokenTenantId == null || principalTenantId == null || !tokenTenantId.equals(principalTenantId.toString()))) {
                        throw new SecurityException("Tenant token mismatch");
                    }
                    UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                        userPrincipal, null, userPrincipal.getAuthorities()
                    );
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                    try {
                        TenantContext.set(principalTenantId, superAdmin);
                        filterChain.doFilter(request, response);
                    } finally {
                        TenantContext.clear();
                    }
                    return;
                }
            }
        } catch (Exception e) {
            // invalid token
        }
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.getWriter().write("{\"success\":false,\"message\":\"Token invalide ou expiré\"}");
    }
}
