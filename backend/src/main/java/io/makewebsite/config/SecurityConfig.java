package io.makewebsite.config;

import io.makewebsite.repository.UserRepository;
import io.makewebsite.security.JwtAuthFilter;
import io.makewebsite.security.UserPrincipal;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.http.HttpMethod;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.io.IOException;
import java.util.Arrays;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(SecurityConfig.class);
    private final JwtAuthFilter jwtAuthFilter;
    private final UserRepository userRepository;
    private final VisitorTrackingFilter visitorTrackingFilter;
    private final StoreSlugFilter storeSlugFilter;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter, UserRepository userRepository, VisitorTrackingFilter visitorTrackingFilter, StoreSlugFilter storeSlugFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.userRepository = userRepository;
        this.visitorTrackingFilter = visitorTrackingFilter;
        this.storeSlugFilter = storeSlugFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint((request, response, authException) -> {
                    log.warn("AUTH ENTRY POINT FIRED for {} {} (message: {})",
                        request.getMethod(), request.getServletPath(), authException.getMessage());
                    response.setContentType("application/json;charset=UTF-8");
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    response.getWriter().write("{\"success\":false,\"message\":\"Email ou mot de passe incorrect\"}");
                })
                .accessDeniedHandler((request, response, accessDeniedException) -> {
                    response.setContentType("application/json;charset=UTF-8");
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.getWriter().write("{\"success\":false,\"message\":\"Accès refusé\"}");
                })
            )
            .authorizeHttpRequests(auth -> auth
                // === CORS preflight: always allow ===
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                // === PUBLIC: no authentication required ===
                .requestMatchers(
                    // SPA root — serve Flutter web app without auth
                    "/", "/index.html",
                    // Auth pages
                    "/login", "/register", "/error",
                    // Auth API
                    "/api/auth/**",
                    // Public team API
                    "/api/team/public/**",
                    // General public API
                    "/api/public/**",
                    "/api/plans",
                    "/api/boutiques/public",
                    "/api/payments/d17/webhook",  // kept for existing unpaid orders
                    "/api/payments/stripe/webhook",
                    "/api/webhooks/stripe",         // Stripe webhook via stripe listen
                    // WebSocket
                    "/ws/**",
                    // Static assets
                    "/uploads/**",
                    "/images/**",
                    "/store/**",
                    "/checkout/**",
                    "/favicon*",
                    // Flutter web static assets
                    "/flutter/**",
                    "/assets/**",
                    "/*.js",
                    "/*.json",
                    "/*.png",
                    "/*.jpg",
                    "/*.ico",
                    "/*.css",
                    "/*.map"
                ).permitAll()
                .requestMatchers(HttpMethod.POST, "/api/traffic/track").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/messages/public").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/products/**", "/api/categories/**").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/products/*/reviews").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/orders/public").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/coupons/validate").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/orders/*/invoice").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/boutiques/*/orders/*/invoice/print").permitAll()
                // === AUTHENTICATED: role-restricted ===
                .requestMatchers("/api/super-admin/**").hasRole("SUPER_ADMIN")
                .requestMatchers("/api/admin/**").hasAnyRole("ADMIN", "SUPER_ADMIN")
                .requestMatchers("/api/boutiques/**").hasAnyRole("OWNER", "ADMIN", "SUPER_ADMIN", "TEAM_MEMBER")
                .requestMatchers("/api/stores/**").hasAnyRole("OWNER", "ADMIN", "SUPER_ADMIN", "TEAM_MEMBER")
                .requestMatchers("/api/team/**").hasAnyRole("OWNER", "ADMIN", "SUPER_ADMIN", "TEAM_MEMBER")
                // === EVERYTHING ELSE: just authenticated (any role) ===
                .anyRequest().authenticated()
            )
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .addFilterBefore(storeSlugFilter, UsernamePasswordAuthenticationFilter.class)
            .addFilterBefore(visitorTrackingFilter, UsernamePasswordAuthenticationFilter.class)
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(Arrays.asList(
            "http://localhost:*",
            "http://127.0.0.1:*",
            "http://192.168.*:*",
            "http://10.*:*",
            "http://172.16.*:*",
            "http://172.17.*:*",
            "http://172.18.*:*",
            "http://172.19.*:*",
            "http://172.20.*:*",
            "http://172.21.*:*",
            "http://172.22.*:*",
            "http://172.23.*:*",
            "http://172.24.*:*",
            "http://172.25.*:*",
            "http://172.26.*:*",
            "http://172.27.*:*",
            "http://172.28.*:*",
            "http://172.29.*:*",
            "http://172.30.*:*",
            "http://172.31.*:*",
            "https://*.ngrok-free.dev",
            "https://*.ngrok-free.app"
        ));
        config.setAllowedMethods(Arrays.asList(
            "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"
        ));
        config.setAllowedHeaders(Arrays.asList(
            "Authorization",
            "Content-Type",
            "Accept",
            "Origin",
            "X-Requested-With",
            "ngrok-skip-browser-warning"
        ));
        config.setExposedHeaders(Arrays.asList(
            "Authorization",
            "Content-Disposition"
        ));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration authConfig) throws Exception {
        return authConfig.getAuthenticationManager();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return email -> {
            log.debug("Loading user by email: '{}'", email);
            return userRepository.findByEmailIgnoreCaseWithTenant(email)
                    .map(user -> {
                        log.info("UserDetailsService: FOUND user id={} email='{}' role={} hashPrefix={} enabled={}",
                            user.getId(), user.getEmail(), user.getRole(),
                            user.getPasswordHash() != null ? user.getPasswordHash().substring(0, Math.min(10, user.getPasswordHash().length())) : "null",
                            user.getEnabled());
                        return new UserPrincipal(
                            user.getId(), user.getEmail(), user.getPasswordHash(),
                            user.getRole(), user.getTenant().getId());
                    })
                    .orElseThrow(() -> {
                        log.warn("UserDetailsService: user NOT FOUND for email: '{}'", email);
                        return new UsernameNotFoundException("Utilisateur non trouvé");
                    });
        };
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
