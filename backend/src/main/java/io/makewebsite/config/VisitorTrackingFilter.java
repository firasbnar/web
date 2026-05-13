package io.makewebsite.config;

import io.makewebsite.dto.response.TrafficStatsResponse;
import io.makewebsite.entity.Visitor;
import io.makewebsite.service.TrafficService;
import io.makewebsite.service.WebSocketService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class VisitorTrackingFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(VisitorTrackingFilter.class);
    private final TrafficService trafficService;
    private final WebSocketService webSocketService;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        // Skip static resources, websocket, auth, and health endpoints
        return path.startsWith("/ws/") ||
               path.startsWith("/api/auth/") ||
               path.startsWith("/api/traffic/") ||
               path.startsWith("/api/plans") ||
               path.startsWith("/uploads/") ||
               path.startsWith("/api/public/") ||
               path.startsWith("/store/") ||
               path.startsWith("/api/boutiques/public") ||
               path.startsWith("/favicon") ||
               (request.getMethod().equalsIgnoreCase("GET") &&
                (path.equals("/") || path.endsWith(".js") || path.endsWith(".css") ||
                 path.endsWith(".png") || path.endsWith(".jpg") || path.endsWith(".ico") ||
                 path.endsWith(".svg") || path.endsWith(".json") || path.endsWith(".map")));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        filterChain.doFilter(request, response);

        // Track the visit after the request is processed
        trackVisit(request);
    }

    private void trackVisit(HttpServletRequest request) {
        try {
            String path = request.getServletPath();
            String method = request.getMethod();

            // Only track meaningful API and page visits
            if (!path.startsWith("/api/") && !path.startsWith("/store/")) {
                return;
            }

            // Extract visitor info
            String ipHash = hashIp(request.getRemoteAddr());
            String userAgent = request.getHeader("User-Agent");
            String referrer = request.getHeader("Referer");
            String deviceType = detectDeviceType(userAgent);
            String browser = detectBrowser(userAgent);
            String os = detectOS(userAgent);
            String platform = detectPlatform(userAgent);

            // Determine boutique ID from request path or header
            UUID boutiqueId = extractBoutiqueId(request);
            if (boutiqueId == null) return;

            // Get authenticated user info if available
            UUID userId = null;
            String userEmail = null;
            String userName = null;
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && auth.getPrincipal() instanceof org.springframework.security.core.userdetails.UserDetails) {
                Object principal = auth.getPrincipal();
                if (principal instanceof io.makewebsite.security.UserPrincipal) {
                    userId = ((io.makewebsite.security.UserPrincipal) principal).getUserId();
                    userEmail = ((io.makewebsite.security.UserPrincipal) principal).getEmail();
                    userName = userEmail != null ? userEmail.split("@")[0] : null;
                }
            }

            // Determine referral source
            String referralSource = "Direct";
            if (referrer != null && !referrer.isEmpty()) {
                if (referrer.contains("google")) referralSource = "Google";
                else if (referrer.contains("facebook")) referralSource = "Facebook";
                else if (referrer.contains("instagram")) referralSource = "Instagram";
                else if (referrer.contains("linkedin")) referralSource = "LinkedIn";
                else if (referrer.contains("twitter") || referrer.contains("x.com")) referralSource = "X (Twitter)";
                else if (referrer.contains("tiktok")) referralSource = "TikTok";
                else if (referrer.contains("youtube")) referralSource = "YouTube";
                else if (referrer.contains("pinterest")) referralSource = "Pinterest";
                else referralSource = "External";
            }

// Geo-enrichment would go here (ip-api.com or MaxMind)
             // For now, we'll store what we can derive
             String country = null;
             String city = null;
             String region = null;
             Double latitude = null;
             Double longitude = null;

             Visitor visitor = trafficService.findOrCreateVisitor(
                     boutiqueId, ipHash, userAgent, country, city, region,
                     latitude, longitude, deviceType, browser, os, platform,
                     referralSource, userId, userEmail, userName
             );

             // Send real-time update via WebSocket
             try {
                 TrafficStatsResponse stats = trafficService.getStats(boutiqueId);
                 webSocketService.sendVisitorUpdate(boutiqueId, stats);
                 webSocketService.sendActiveVisitorCount(boutiqueId, stats.getActiveVisitors());
             } catch (Exception ex) {
                 logger.debug("WebSocket notification skipped: {}", ex.getMessage());
             }

        } catch (Exception e) {
            // Don't let tracking break the main request
            logger.error("Visitor tracking error", e);
        }
    }

    private String hashIp(String ip) {
        if (ip == null) return "unknown";
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(ip.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString().substring(0, 32);
        } catch (Exception e) {
            return ip;
        }
    }

    private UUID extractBoutiqueId(HttpServletRequest request) {
        // Try path: /api/boutiques/{id}/...
        String path = request.getServletPath();
        String[] parts = path.split("/");
        for (int i = 0; i < parts.length - 1; i++) {
            if ("boutiques".equals(parts[i])) {
                try {
                    return UUID.fromString(parts[i + 1]);
                } catch (Exception e) {
                    // not a UUID
                }
            }
        }

        // Try header
        String boutiqueHeader = request.getHeader("X-Boutique-Id");
        if (boutiqueHeader != null) {
            try {
                return UUID.fromString(boutiqueHeader);
            } catch (Exception e) {
                // ignore
            }
        }

        // Try query param
        String boutiqueParam = request.getParameter("boutiqueId");
        if (boutiqueParam != null) {
            try {
                return UUID.fromString(boutiqueParam);
            } catch (Exception e) {
                // ignore
            }
        }

        return null;
    }

    private String detectDeviceType(String userAgent) {
        if (userAgent == null) return "Desktop";
        String ua = userAgent.toLowerCase();
        if (ua.contains("mobile")) return "Mobile";
        if (ua.contains("tablet") || ua.contains("ipad")) return "Tablet";
        if (ua.contains("android") && !ua.contains("mobile")) return "Tablet";
        return "Desktop";
    }

    private String detectBrowser(String userAgent) {
        if (userAgent == null) return "Unknown";
        String ua = userAgent.toLowerCase();
        if (ua.contains("edg")) return "Edge";
        if (ua.contains("chrome")) return "Chrome";
        if (ua.contains("firefox")) return "Firefox";
        if (ua.contains("safari")) return "Safari";
        if (ua.contains("opera") || ua.contains("opr")) return "Opera";
        if (ua.contains("msie") || ua.contains("trident")) return "Internet Explorer";
        return "Unknown";
    }

    private String detectOS(String userAgent) {
        if (userAgent == null) return "Unknown";
        String ua = userAgent.toLowerCase();
        if (ua.contains("windows")) return "Windows";
        if (ua.contains("mac")) return "macOS";
        if (ua.contains("linux")) return "Linux";
        if (ua.contains("android")) return "Android";
        if (ua.contains("iphone") || ua.contains("ipad")) return "iOS";
        return "Unknown";
    }

    private String detectPlatform(String userAgent) {
        if (userAgent == null) return "Web";
        String ua = userAgent.toLowerCase();
        if (ua.contains("android") || ua.contains("iphone") || ua.contains("ipad")) return "Mobile";
        return "Web";
    }
}