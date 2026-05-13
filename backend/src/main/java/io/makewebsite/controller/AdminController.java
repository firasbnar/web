package io.makewebsite.controller;

import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.User;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {
    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final SubscriptionRepository subscriptionRepository;

    @GetMapping("/overview")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getOverview() {
        long totalUsers = userRepository.count();
        long totalBoutiques = boutiqueRepository.count();
        long totalOrders = orderRepository.count();
        long totalProducts = productRepository.count();
        BigDecimal totalRevenue = orderRepository.sumAllRevenue();
        long totalSubscriptions = subscriptionRepository.count();
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", totalUsers);
        stats.put("totalBoutiques", totalBoutiques);
        stats.put("totalOrders", totalOrders);
        stats.put("totalProducts", totalProducts);
        stats.put("totalRevenue", totalRevenue != null ? totalRevenue : BigDecimal.ZERO);
        stats.put("totalSubscriptions", totalSubscriptions);
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getUsers(Pageable pageable) {
        Page<User> page = userRepository.findAll(pageable);
        List<Map<String, Object>> users = page.getContent().stream().map(u -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", u.getId());
            m.put("fullName", u.getFullName());
            m.put("email", u.getEmail());
            m.put("phone", u.getPhone());
            m.put("role", u.getRole());
            m.put("language", u.getLanguage());
            m.put("isSuspended", u.getIsSuspended());
            m.put("suspendedReason", u.getSuspendedReason());
            m.put("lastLoginAt", u.getLastLoginAt());
            m.put("createdAt", u.getCreatedAt());
            m.put("boutiqueCount", boutiqueRepository.findByUserId(u.getId()).size());
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", users);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getUserDetail(@PathVariable UUID id) {
        User user = userRepository.findById(id).orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        List<Boutique> boutiques = boutiqueRepository.findByUserId(id);
        List<Map<String, Object>> boutiqueData = boutiques.stream().map(b -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", b.getId());
            m.put("name", b.getName());
            m.put("slug", b.getSlug());
            m.put("isActive", b.getIsActive());
            m.put("productCount", productRepository.countByBoutiqueId(b.getId()));
            m.put("orderCount", orderRepository.countByBoutiqueId(b.getId()));
            m.put("createdAt", b.getCreatedAt());
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("fullName", user.getFullName());
        result.put("email", user.getEmail());
        result.put("role", user.getRole());
        result.put("isSuspended", user.getIsSuspended());
        result.put("suspendedReason", user.getSuspendedReason());
        result.put("createdAt", user.getCreatedAt());
        result.put("boutiques", boutiqueData);
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/boutiques")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBoutiques(Pageable pageable) {
        Page<Boutique> page = boutiqueRepository.findAll(pageable);
        List<Map<String, Object>> boutiques = page.getContent().stream().map(b -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", b.getId());
            m.put("name", b.getName());
            m.put("slug", b.getSlug());
            m.put("currency", b.getCurrency());
            m.put("isActive", b.getIsActive());
            m.put("createdAt", b.getCreatedAt());
            m.put("ownerName", b.getUser().getFullName());
            m.put("ownerEmail", b.getUser().getEmail());
            m.put("productCount", productRepository.countByBoutiqueId(b.getId()));
            m.put("orderCount", orderRepository.countByBoutiqueId(b.getId()));
            BigDecimal rev = orderRepository.sumRevenueByBoutiqueId(b.getId());
            m.put("totalRevenue", rev != null ? rev : BigDecimal.ZERO);
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", boutiques);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        return ResponseEntity.ok(ApiResponse.ok(result));
    }

    @GetMapping("/boutiques/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getBoutiqueDetail(@PathVariable UUID id) {
        Boutique b = boutiqueRepository.findById(id).orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", b.getId());
        m.put("name", b.getName());
        m.put("slug", b.getSlug());
        m.put("isActive", b.getIsActive());
        m.put("createdAt", b.getCreatedAt());
        m.put("ownerName", b.getUser().getFullName());
        m.put("ownerEmail", b.getUser().getEmail());
        m.put("productCount", productRepository.countByBoutiqueId(b.getId()));
        m.put("orderCount", orderRepository.countByBoutiqueId(b.getId()));
        BigDecimal rev = orderRepository.sumRevenueByBoutiqueId(b.getId());
        m.put("totalRevenue", rev != null ? rev : BigDecimal.ZERO);
        return ResponseEntity.ok(ApiResponse.ok(m));
    }

    @PutMapping("/users/{id}/suspend")
    public ResponseEntity<ApiResponse<Map<String, Object>>> suspendUser(@PathVariable UUID id, @RequestBody Map<String, String> body) {
        User user = userRepository.findById(id).orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        user.setIsSuspended(true);
        user.setSuspendedReason(body.get("reason"));
        userRepository.save(user);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("isSuspended", true);
        return ResponseEntity.ok(ApiResponse.ok("Utilisateur suspendu", result));
    }

    @PutMapping("/users/{id}/activate")
    public ResponseEntity<ApiResponse<Map<String, Object>>> activateUser(@PathVariable UUID id) {
        User user = userRepository.findById(id).orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        user.setIsSuspended(false);
        user.setSuspendedReason(null);
        userRepository.save(user);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("isSuspended", false);
        return ResponseEntity.ok(ApiResponse.ok("Utilisateur activé", result));
    }

    @PutMapping("/users/{id}/role")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateUserRole(@PathVariable UUID id, @RequestBody Map<String, String> body) {
        User user = userRepository.findById(id).orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        user.setRole(body.get("role"));
        userRepository.save(user);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("email", user.getEmail());
        result.put("role", user.getRole());
        return ResponseEntity.ok(ApiResponse.ok("Rôle mis à jour", result));
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(@PathVariable UUID id) {
        userRepository.deleteById(id);
        return ResponseEntity.ok(ApiResponse.ok("Utilisateur supprimé", null));
    }

    @DeleteMapping("/boutiques/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteBoutique(@PathVariable UUID id) {
        boutiqueRepository.deleteById(id);
        return ResponseEntity.ok(ApiResponse.ok("Boutique supprimée", null));
    }

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStats() {
        long totalOwners = userRepository.countByRole("OWNER");
        long totalBoutiques = boutiqueRepository.count();
        long totalOrders = orderRepository.count();
        BigDecimal totalRevenue = orderRepository.sumAllRevenue();
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalOwners", totalOwners);
        stats.put("totalBoutiques", totalBoutiques);
        stats.put("totalOrders", totalOrders);
        stats.put("totalRevenue", totalRevenue != null ? totalRevenue : BigDecimal.ZERO);
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }
}
