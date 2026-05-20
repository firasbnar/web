package io.makewebsite.service;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.util.CsvUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SuperAdminService {

    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final AdminAuditLogRepository auditLogRepository;

    @Transactional(readOnly = true)
    public Map<String, Object> getDashboard() {
        long totalUsers = userRepository.count();
        long totalOwners = userRepository.countByRole("OWNER");
        long totalBoutiques = boutiqueRepository.count();
        long totalProducts = productRepository.count();
        long totalOrders = orderRepository.count();
        BigDecimal totalRevenue = orderRepository.sumAllRevenue();
        long totalSubscriptions = subscriptionRepository.count();
        long activeSubscriptions = subscriptionRepository.countByStatus("ACTIVE");
        long frozenStores = boutiqueRepository.countByStoreStatus("FROZEN");
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", totalUsers);
        stats.put("totalOwners", totalOwners);
        stats.put("totalBoutiques", totalBoutiques);
        stats.put("totalProducts", totalProducts);
        stats.put("totalOrders", totalOrders);
        stats.put("totalRevenue", totalRevenue != null ? totalRevenue : BigDecimal.ZERO);
        stats.put("totalSubscriptions", totalSubscriptions);
        stats.put("activeSubscriptions", activeSubscriptions);
        stats.put("frozenStores", frozenStores);
        return stats;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getStores(Pageable pageable) {
        Page<Boutique> page = boutiqueRepository.findAllWithUser(pageable);
        List<Map<String, Object>> stores = page.getContent().stream().map(b -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", b.getId());
            m.put("name", b.getName());
            m.put("slug", b.getSlug());
            m.put("currency", b.getCurrency());
            m.put("isActive", b.getIsActive());
            m.put("storeStatus", b.getStoreStatus());
            m.put("frozenAt", b.getFrozenAt());
            m.put("freezeReason", b.getFreezeReason());
            m.put("isPublished", b.getIsPublished());
            m.put("publishedAt", b.getPublishedAt());
            m.put("publicUrl", "/store/" + b.getSlug());
            m.put("createdAt", b.getCreatedAt());
            m.put("ownerId", b.getUser().getId());
            m.put("ownerName", b.getUser().getFullName());
            m.put("ownerEmail", b.getUser().getEmail());
            m.put("productCount", productRepository.countByBoutiqueId(b.getId()));
            m.put("orderCount", orderRepository.countByBoutiqueId(b.getId()));
            BigDecimal rev = orderRepository.sumRevenueByBoutiqueId(b.getId());
            m.put("totalRevenue", rev != null ? rev : BigDecimal.ZERO);
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", stores);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        return result;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getStoreDetail(UUID id) {
        Boutique b = boutiqueRepository.findByIdWithUser(id)
                .orElseThrow(() -> new NoSuchElementException("Boutique non trouvée"));
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", b.getId());
        m.put("name", b.getName());
        m.put("slug", b.getSlug());
        m.put("isActive", b.getIsActive());
        m.put("storeStatus", b.getStoreStatus());
        m.put("frozenAt", b.getFrozenAt());
        m.put("freezeReason", b.getFreezeReason());
        m.put("createdAt", b.getCreatedAt());
        m.put("ownerId", b.getUser().getId());
        m.put("ownerName", b.getUser().getFullName());
        m.put("ownerEmail", b.getUser().getEmail());
        m.put("productCount", productRepository.countByBoutiqueId(b.getId()));
        m.put("orderCount", orderRepository.countByBoutiqueId(b.getId()));
        BigDecimal rev = orderRepository.sumRevenueByBoutiqueId(b.getId());
        m.put("totalRevenue", rev != null ? rev : BigDecimal.ZERO);
        return m;
    }

    @Transactional
    public Map<String, Object> freezeStore(UUID storeId, String reason, UUID adminId, String adminEmail) {
        Boutique b = boutiqueRepository.findById(storeId)
                .orElseThrow(() -> new NoSuchElementException("Boutique non trouvée"));
        b.setStoreStatus("FROZEN");
        b.setFrozenAt(LocalDateTime.now());
        b.setFreezeReason(reason != null ? reason : "Action super admin");
        boutiqueRepository.save(b);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("FREEZE_STORE").targetType("STORE")
                .targetId(storeId).details("Raison: " + (reason != null ? reason : ""))
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", b.getId());
        result.put("storeStatus", b.getStoreStatus());
        result.put("frozenAt", b.getFrozenAt());
        result.put("freezeReason", b.getFreezeReason());
        return result;
    }

    @Transactional
    public Map<String, Object> unfreezeStore(UUID storeId, UUID adminId, String adminEmail) {
        Boutique b = boutiqueRepository.findById(storeId)
                .orElseThrow(() -> new NoSuchElementException("Boutique non trouvée"));
        b.setStoreStatus("ACTIVE");
        b.setFrozenAt(null);
        b.setFreezeReason(null);
        boutiqueRepository.save(b);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("UNFREEZE_STORE").targetType("STORE")
                .targetId(storeId).details("Boutique dégelée")
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", b.getId());
        result.put("storeStatus", b.getStoreStatus());
        return result;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getUsers(Pageable pageable) {
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
            m.put("emailVerified", u.getEmailVerified());
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
        return result;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getUserDetail(UUID id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new NoSuchElementException("Utilisateur non trouvé"));
        List<Boutique> boutiques = boutiqueRepository.findByUserId(id);
        List<Map<String, Object>> boutiqueData = boutiques.stream().map(b -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", b.getId());
            m.put("name", b.getName());
            m.put("slug", b.getSlug());
            m.put("isActive", b.getIsActive());
            m.put("storeStatus", b.getStoreStatus());
            m.put("frozenAt", b.getFrozenAt());
            m.put("freezeReason", b.getFreezeReason());
            m.put("productCount", productRepository.countByBoutiqueId(b.getId()));
            m.put("orderCount", orderRepository.countByBoutiqueId(b.getId()));
            m.put("createdAt", b.getCreatedAt());
            return m;
        }).toList();

        List<Subscription> subs = subscriptionRepository.findByUserId(id);
        List<Map<String, Object>> subData = subs.stream().map(s -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", s.getId());
            m.put("planName", s.getPlan() != null ? s.getPlan().getName() : null);
            m.put("status", s.getStatus());
            m.put("startedAt", s.getStartedAt());
            m.put("expiresAt", s.getExpiresAt());
            return m;
        }).toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("fullName", user.getFullName());
        result.put("email", user.getEmail());
        result.put("phone", user.getPhone());
        result.put("role", user.getRole());
        result.put("isSuspended", user.getIsSuspended());
        result.put("suspendedReason", user.getSuspendedReason());
        result.put("emailVerified", user.getEmailVerified());
        result.put("lastLoginAt", user.getLastLoginAt());
        result.put("createdAt", user.getCreatedAt());
        result.put("boutiques", boutiqueData);
        result.put("subscriptions", subData);
        return result;
    }

    @Transactional
    public Map<String, Object> updateUserRole(UUID userId, String newRole, UUID adminId, String adminEmail) {
        if ("SUPER_ADMIN".equalsIgnoreCase(newRole)) {
            throw new IllegalArgumentException("Impossible d'attribuer le rôle SUPER_ADMIN via cette API");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("Utilisateur non trouvé"));
        String oldRole = user.getRole();
        user.setRole(newRole);
        userRepository.save(user);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("UPDATE_USER_ROLE").targetType("USER")
                .targetId(userId)
                .details("Ancien rôle: " + oldRole + " → Nouveau rôle: " + newRole)
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("email", user.getEmail());
        result.put("role", user.getRole());
        result.put("oldRole", oldRole);
        return result;
    }

    @Transactional
    public Map<String, Object> verifyUserEmail(UUID userId, UUID adminId, String adminEmail) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("Utilisateur non trouvé"));
        user.setEmailVerified(true);
        user.setEnabled(true);
        userRepository.save(user);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("VERIFY_EMAIL").targetType("USER")
                .targetId(userId).details("Email vérifié par super admin")
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("email", user.getEmail());
        result.put("emailVerified", true);
        return result;
    }

    @Transactional
    public Map<String, Object> suspendUser(UUID userId, String reason, UUID adminId, String adminEmail) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("Utilisateur non trouvé"));
        user.setIsSuspended(true);
        user.setSuspendedReason(reason);
        userRepository.save(user);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("SUSPEND_USER").targetType("USER")
                .targetId(userId).details("Raison: " + (reason != null ? reason : ""))
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("isSuspended", true);
        return result;
    }

    @Transactional
    public Map<String, Object> activateUser(UUID userId, UUID adminId, String adminEmail) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("Utilisateur non trouvé"));
        user.setIsSuspended(false);
        user.setSuspendedReason(null);
        userRepository.save(user);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("ACTIVATE_USER").targetType("USER")
                .targetId(userId).details("Utilisateur réactivé")
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", user.getId());
        result.put("isSuspended", false);
        return result;
    }

    @Transactional
    public void deleteUser(UUID userId, UUID adminId, String adminEmail) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("Utilisateur non trouvé"));
        String email = user.getEmail();
        userRepository.delete(user);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("DELETE_USER").targetType("USER")
                .targetId(userId).details("Email: " + email)
                .build());
    }

    @Transactional
    public void deleteStore(UUID storeId, UUID adminId, String adminEmail) {
        Boutique b = boutiqueRepository.findById(storeId)
                .orElseThrow(() -> new NoSuchElementException("Boutique non trouvée"));
        boutiqueRepository.delete(b);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("DELETE_STORE").targetType("STORE")
                .targetId(storeId).details("Boutique: " + b.getName())
                .build());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getSubscriptions(Pageable pageable) {
        Page<Subscription> page = subscriptionRepository.findAllWithUserAndPlan(pageable);
        List<Map<String, Object>> subs = page.getContent().stream().map(s -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", s.getId());
            m.put("userId", s.getUser().getId());
            m.put("userName", s.getUser().getFullName());
            m.put("userEmail", s.getUser().getEmail());
            m.put("planName", s.getPlan() != null ? s.getPlan().getName() : null);
            m.put("planPrice", s.getPlan() != null ? s.getPlan().getPriceDt() : null);
            m.put("status", s.getStatus());
            m.put("startedAt", s.getStartedAt());
            m.put("expiresAt", s.getExpiresAt());
            m.put("paymentMethod", s.getPaymentMethod());
            m.put("paymentRef", s.getPaymentRef());
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", subs);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        return result;
    }

    @Transactional
    public Map<String, Object> overrideSubscriptionStatus(UUID subId, String newStatus, UUID adminId, String adminEmail) {
        Subscription s = subscriptionRepository.findById(subId)
                .orElseThrow(() -> new NoSuchElementException("Abonnement non trouvé"));
        String oldStatus = s.getStatus();
        s.setStatus(newStatus);
        subscriptionRepository.save(s);

        auditLogRepository.save(AdminAuditLog.builder()
                .adminId(adminId).adminEmail(adminEmail)
                .action("OVERRIDE_SUBSCRIPTION").targetType("SUBSCRIPTION")
                .targetId(subId)
                .details("Ancien statut: " + oldStatus + " → Nouveau statut: " + newStatus)
                .build());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", s.getId());
        result.put("status", s.getStatus());
        result.put("oldStatus", oldStatus);
        return result;
    }

    @Transactional(readOnly = true)
    public String exportStoresCsv() {
        List<Boutique> stores = boutiqueRepository.findAll();
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("ID,Nom,Slug,Devise,Actif,Statut,Publié,Propriétaire,Email,Produits,Commandes,Revenu,Créé le\n");
        for (Boutique b : stores) {
            BigDecimal rev = orderRepository.sumRevenueByBoutiqueId(b.getId());
            sb.append(b.getId()).append(",")
              .append(CsvUtil.escapeCsv(b.getName())).append(",")
              .append(CsvUtil.escapeCsv(b.getSlug())).append(",")
              .append(CsvUtil.escapeCsv(b.getCurrency())).append(",")
              .append(b.getIsActive()).append(",")
              .append(CsvUtil.escapeCsv(b.getStoreStatus())).append(",")
              .append(b.getIsPublished()).append(",")
              .append(CsvUtil.escapeCsv(b.getUser().getFullName())).append(",")
              .append(CsvUtil.escapeCsv(b.getUser().getEmail())).append(",")
              .append(productRepository.countByBoutiqueId(b.getId())).append(",")
              .append(orderRepository.countByBoutiqueId(b.getId())).append(",")
              .append(rev != null ? rev : BigDecimal.ZERO).append(",")
              .append(b.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public String exportUsersCsv() {
        List<User> users = userRepository.findAll();
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("ID,Nom,Email,Téléphone,Rôle,Langue,Suspendu,Email vérifié,Dernière connexion,Boutiques,Créé le\n");
        for (User u : users) {
            sb.append(u.getId()).append(",")
              .append(CsvUtil.escapeCsv(u.getFullName())).append(",")
              .append(CsvUtil.escapeCsv(u.getEmail())).append(",")
              .append(CsvUtil.escapeCsv(u.getPhone())).append(",")
              .append(CsvUtil.escapeCsv(u.getRole())).append(",")
              .append(CsvUtil.escapeCsv(u.getLanguage())).append(",")
              .append(u.getIsSuspended() != null && u.getIsSuspended()).append(",")
              .append(u.getEmailVerified() != null && u.getEmailVerified()).append(",")
              .append(u.getLastLoginAt() != null ? u.getLastLoginAt().toString() : "").append(",")
              .append(boutiqueRepository.findByUserId(u.getId()).size()).append(",")
              .append(u.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public String exportSubscriptionsCsv() {
        Page<Subscription> page = subscriptionRepository.findAllWithUserAndPlan(Pageable.unpaged());
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("ID,Utilisateur,Email,Plan,Prix,Statut,Début,Expiration,Paiement,Référence\n");
        for (Subscription s : page.getContent()) {
            sb.append(s.getId()).append(",")
              .append(CsvUtil.escapeCsv(s.getUser().getFullName())).append(",")
              .append(CsvUtil.escapeCsv(s.getUser().getEmail())).append(",")
              .append(CsvUtil.escapeCsv(s.getPlan().getName())).append(",")
              .append(s.getPlan().getPriceDt() != null ? s.getPlan().getPriceDt() : "0").append(",")
              .append(CsvUtil.escapeCsv(s.getStatus())).append(",")
              .append(s.getStartedAt() != null ? s.getStartedAt().toString() : "").append(",")
              .append(s.getExpiresAt()).append(",")
              .append(CsvUtil.escapeCsv(s.getPaymentMethod())).append(",")
              .append(CsvUtil.escapeCsv(s.getPaymentRef())).append("\n");
        }
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public String exportAuditLogsCsv() {
        List<AdminAuditLog> logs = auditLogRepository.findAll();
        logs.sort((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()));
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("ID,Admin,Email,Action,Cible,ID Cible,Détails,Date\n");
        for (AdminAuditLog l : logs) {
            sb.append(l.getId()).append(",")
              .append(l.getAdminId()).append(",")
              .append(CsvUtil.escapeCsv(l.getAdminEmail())).append(",")
              .append(CsvUtil.escapeCsv(l.getAction())).append(",")
              .append(CsvUtil.escapeCsv(l.getTargetType())).append(",")
              .append(l.getTargetId() != null ? l.getTargetId() : "").append(",")
              .append(CsvUtil.escapeCsv(l.getDetails())).append(",")
              .append(l.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getAuditLogs(Pageable pageable) {
        Page<AdminAuditLog> page = auditLogRepository.findAllByOrderByCreatedAtDesc(pageable);
        List<Map<String, Object>> logs = page.getContent().stream().map(l -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", l.getId());
            m.put("adminId", l.getAdminId());
            m.put("adminEmail", l.getAdminEmail());
            m.put("action", l.getAction());
            m.put("targetType", l.getTargetType());
            m.put("targetId", l.getTargetId());
            m.put("details", l.getDetails());
            m.put("createdAt", l.getCreatedAt());
            return m;
        }).toList();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", logs);
        result.put("totalElements", page.getTotalElements());
        result.put("totalPages", page.getTotalPages());
        result.put("currentPage", page.getNumber());
        return result;
    }
}
