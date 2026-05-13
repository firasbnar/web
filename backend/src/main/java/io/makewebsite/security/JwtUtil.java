package io.makewebsite.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import io.makewebsite.config.JwtConfig;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
public class JwtUtil {

    private final JwtConfig jwtConfig;
    private final SecretKey secretKey;

    public JwtUtil(JwtConfig jwtConfig) {
        this.jwtConfig = jwtConfig;
        this.secretKey = Keys.hmacShaKeyFor(jwtConfig.getSecret().getBytes(StandardCharsets.UTF_8));
    }

    public String generateAccessToken(UserDetails userDetails) {
        UserPrincipal principal = (UserPrincipal) userDetails;
        return Jwts.builder()
            .subject(principal.getUserId().toString())
            .claim("email", principal.getEmail())
            .claim("role", principal.getRole())
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + jwtConfig.getAccessExpiration()))
            .signWith(secretKey)
            .compact();
    }

    public String generateRefreshToken(UserDetails userDetails) {
        UserPrincipal principal = (UserPrincipal) userDetails;
        return Jwts.builder()
            .subject(principal.getUserId().toString())
            .claim("email", principal.getEmail())
            .claim("role", principal.getRole())
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + jwtConfig.getRefreshExpiration()))
            .signWith(secretKey)
            .compact();
    }

    public String extractUserId(String token) {
        return extractAllClaims(token).getSubject();
    }

    public String extractEmail(String token) {
        return extractAllClaims(token).get("email", String.class);
    }

    public String extractRole(String token) {
        return extractAllClaims(token).get("role", String.class);
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        try {
            String userId = extractUserId(token);
            return userId.equals(userDetails.getUsername()) && !isTokenExpired(token);
        } catch (Exception e) {
            return false;
        }
    }

    private boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }

    private Date extractExpiration(String token) {
        return extractAllClaims(token).getExpiration();
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser()
            .verifyWith(secretKey)
            .build()
            .parseSignedClaims(token)
            .getPayload();
    }
}
