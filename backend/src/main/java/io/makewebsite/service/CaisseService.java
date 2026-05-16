package io.makewebsite.service;

import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CaisseService {
    private final OrderRepository orderRepository;
    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final PosSessionRepository posSessionRepository;
    private final PosTransactionRepository posTransactionRepository;
    private final UserSessionRepository userSessionRepository;
    private final ActivityLogRepository activityLogRepository;
    private final WebSocketService webSocketService;
    private final ActivityLogService activityLogService;

    @Transactional(readOnly = true)
    public CaisseDashboardResponse getDashboard(UUID boutiqueId) {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime todayEnd = LocalDate.now().atTime(LocalTime.MAX);

        BigDecimal totalVentes = orderRepository.sumRevenueByBoutiqueId(boutiqueId);
        if (totalVentes == null) totalVentes = BigDecimal.ZERO;

        BigDecimal ventesAujourdhui = orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, todayEnd);
        if (ventesAujourdhui == null) ventesAujourdhui = BigDecimal.ZERO;

        long commandesAujourdhui = orderRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, todayEnd);
        long caissesActives = posSessionRepository.findByBoutiqueIdAndClosedAtIsNull(boutiqueId).isPresent() ? 1 : 0;
        long totalCommandes = orderRepository.countByBoutiqueId(boutiqueId);

        long utilisateursConnectes = 0;
        Boutique boutique = boutiqueRepository.findById(boutiqueId).orElse(null);
        if (boutique != null) {
            utilisateursConnectes = userSessionRepository.countByUserIdAndIsActiveTrue(boutique.getUser().getId());
            List<TeamMember> team = teamMemberRepository.findByBoutiqueId(boutiqueId);
            for (TeamMember tm : team) {
                if (tm.getUser() != null) {
                    utilisateursConnectes += userSessionRepository.countByUserIdAndIsActiveTrue(tm.getUser().getId());
                }
            }
        }

        return CaisseDashboardResponse.builder()
                .totalVentes(totalVentes)
                .commandesAujourdhui(commandesAujourdhui)
                .caissesActives(caissesActives)
                .utilisateursConnectes(utilisateursConnectes)
                .ventesAujourdhui(ventesAujourdhui)
                .totalCommandes(totalCommandes)
                .build();
    }

    @Transactional(readOnly = true)
    public Page<CashierResponse> getCashiers(UUID boutiqueId, String search, Pageable pageable) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        Map<UUID, CashierResponse.CashierResponseBuilder> map = new LinkedHashMap<>();

        User owner = boutique.getUser();
        CashierResponse.CashierResponseBuilder ownerBuilder = buildCashierResponse(owner, boutiqueId);
        if (ownerBuilder != null) map.put(owner.getId(), ownerBuilder);

        List<TeamMember> team = teamMemberRepository.findByBoutiqueId(boutiqueId);
        for (TeamMember tm : team) {
            if (tm.getUser() != null) {
                CashierResponse.CashierResponseBuilder cb = buildCashierResponse(tm.getUser(), boutiqueId);
                if (cb != null) map.put(tm.getUser().getId(), cb);
            }
        }

        List<CashierResponse> cashiers = map.values().stream()
                .map(CashierResponse.CashierResponseBuilder::build)
                .filter(c -> search == null || search.isEmpty()
                        || c.getFullName().toLowerCase().contains(search.toLowerCase())
                        || c.getEmail().toLowerCase().contains(search.toLowerCase()))
                .collect(Collectors.toList());

        int start = (int) pageable.getOffset();
        int end = Math.min(start + pageable.getPageSize(), cashiers.size());
        List<CashierResponse> pageContent = start >= cashiers.size() ? List.of() : cashiers.subList(start, end);

        return new org.springframework.data.domain.PageImpl<>(pageContent, pageable, cashiers.size());
    }

    private CashierResponse.CashierResponseBuilder buildCashierResponse(User user, UUID boutiqueId) {
        if (user == null) return null;

        BigDecimal totalVentes = orderRepository.sumRevenueByBoutiqueId(boutiqueId);
        long commandesCount = orderRepository.countByBoutiqueId(boutiqueId);
        long activeSessions = userSessionRepository.countByUserIdAndIsActiveTrue(user.getId());
        List<PosSession> sessions = posSessionRepository.findByBoutiqueIdOrderByOpenedAtDesc(boutiqueId);
        Optional<PosSession> activeSession = sessions.stream()
                .filter(s -> s.getClosedAt() == null && user.getId().equals(s.getUser().getId()))
                .findFirst();

        return CashierResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .isActive(user.getEnabled())
                .isSuspended(user.getIsSuspended())
                .phone(user.getPhone())
                .totalVentes(totalVentes)
                .commandesCount(commandesCount)
                .online(activeSessions > 0)
                .lastActivity(activeSession.map(s -> s.getOpenedAt().toString()).orElse(null));
    }

    @Transactional
    public CashierResponse toggleCashierStatus(UUID boutiqueId, UUID cashierId, boolean suspend) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        User cashier = userRepository.findById(cashierId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        cashier.setIsSuspended(suspend);
        if (!suspend) cashier.setSuspendedReason(null);
        userRepository.save(cashier);

        CashierResponse.CashierResponseBuilder builder = buildCashierResponse(cashier, boutiqueId);
        return builder != null ? builder.build() : null;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getCashierStats(UUID boutiqueId) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        long totalCashiers = 1 + teamMemberRepository.countByBoutiqueId(boutiqueId);
        long onlineCashiers = 0;
        BigDecimal totalSales = orderRepository.sumRevenueByBoutiqueId(boutiqueId);

        if (userSessionRepository.countByUserIdAndIsActiveTrue(boutique.getUser().getId()) > 0) {
            onlineCashiers++;
        }
        List<TeamMember> team = teamMemberRepository.findByBoutiqueId(boutiqueId);
        for (TeamMember tm : team) {
            if (tm.getUser() != null && userSessionRepository.countByUserIdAndIsActiveTrue(tm.getUser().getId()) > 0) {
                onlineCashiers++;
            }
        }

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalCashiers", totalCashiers);
        stats.put("onlineCashiers", onlineCashiers);
        stats.put("totalSales", totalSales);
        stats.put("totalOrders", orderRepository.countByBoutiqueId(boutiqueId));
        return stats;
    }

    @Transactional
    public CashierResponse createCashier(UUID boutiqueId, String email, String fullName, String role) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) {
            throw new RuntimeException("Utilisateur avec cet email non trouvé");
        }

        if (teamMemberRepository.existsByBoutiqueIdAndUserId(boutiqueId, user.getId())) {
            throw new RuntimeException("Cet utilisateur est déjà membre de la boutique");
        }

        TeamMember member = TeamMember.builder()
                .boutique(boutique)
                .user(user)
                .name(fullName != null ? fullName : user.getFullName())
                .invitedEmail(email)
                .role(role != null ? role : "STAFF")
                .status("ACTIVE")
                .invitedAt(LocalDateTime.now())
                .joinedAt(LocalDateTime.now())
                .build();
        teamMemberRepository.save(member);

        CashierResponse.CashierResponseBuilder builder = buildCashierResponse(user, boutiqueId);
        return builder != null ? builder.build() : null;
    }

    @Transactional
    public void deleteCashier(UUID boutiqueId, UUID userId) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        if (boutique.getUser().getId().equals(userId)) {
            throw new RuntimeException("Impossible de supprimer le propriétaire de la boutique");
        }

        teamMemberRepository.findByBoutiqueIdAndUserId(boutiqueId, userId)
                .ifPresentOrElse(
                        teamMemberRepository::delete,
                        () -> { throw new RuntimeException("Membre non trouvé"); }
                );
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> searchUsers(UUID boutiqueId, String query) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        List<User> allUsers = userRepository.findAll();
        Set<UUID> existingIds = new HashSet<>();
        existingIds.add(boutique.getUser().getId());
        teamMemberRepository.findByBoutiqueId(boutiqueId).stream()
                .filter(tm -> tm.getUser() != null)
                .forEach(tm -> existingIds.add(tm.getUser().getId()));

        return allUsers.stream()
                .filter(u -> !existingIds.contains(u.getId()))
                .filter(u -> query == null || query.isEmpty()
                        || u.getFullName().toLowerCase().contains(query.toLowerCase())
                        || u.getEmail().toLowerCase().contains(query.toLowerCase()))
                .limit(20)
                .map(u -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", u.getId());
                    m.put("fullName", u.getFullName());
                    m.put("email", u.getEmail());
                    m.put("role", u.getRole());
                    return m;
                })
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Page<OrderResponse> getCaisseOrders(UUID boutiqueId, String status, String startDate, String endDate, UUID userId, Pageable pageable) {
        boolean hasDate = startDate != null && !startDate.isEmpty();
        boolean hasUserId = userId != null;

        if (hasUserId) {
            if (status != null && !status.isEmpty() && !"ALL".equals(status)) {
                return orderRepository.findByBoutiqueIdAndUserIdAndStatus(boutiqueId, userId, status, pageable)
                        .map(this::mapOrderToResponse);
            }
            return orderRepository.findByBoutiqueIdAndUserId(boutiqueId, userId, pageable)
                    .map(this::mapOrderToResponse);
        }

        if (hasDate) {
            LocalDateTime from = LocalDate.parse(startDate).atStartOfDay();
            LocalDateTime to = endDate != null && !endDate.isEmpty()
                    ? LocalDate.parse(endDate).atTime(LocalTime.MAX)
                    : LocalDateTime.now();

            if (status != null && !status.isEmpty() && !"ALL".equals(status)) {
                return orderRepository.findByBoutiqueIdAndStatusAndCreatedAtBetween(boutiqueId, status, from, to, pageable)
                        .map(this::mapOrderToResponse);
            }
            return orderRepository.findByBoutiqueIdAndCreatedAtBetween(boutiqueId, from, to, pageable)
                    .map(this::mapOrderToResponse);
        }

        if (status != null && !status.isEmpty() && !"ALL".equals(status)) {
            return orderRepository.findByBoutiqueIdAndStatus(boutiqueId, status, pageable)
                    .map(this::mapOrderToResponse);
        }
        return orderRepository.findByBoutiqueId(boutiqueId, pageable)
                .map(this::mapOrderToResponse);
    }

    @Transactional(readOnly = true)
    public Page<ActivityLogResponse> getActivities(UUID boutiqueId, String action, Pageable pageable) {
        Page<ActivityLog> logs;
        if (action != null && !action.isEmpty() && !"ALL".equals(action)) {
            logs = activityLogRepository.findByBoutiqueIdAndActionOrderByCreatedAtDesc(boutiqueId, action, pageable);
        } else {
            logs = activityLogRepository.findByBoutiqueIdOrderByCreatedAtDesc(boutiqueId, pageable);
        }
        return logs.map(this::mapActivityToResponse);
    }

    @Transactional
    public ActivityLogResponse recordActivity(UUID boutiqueId, UUID userId, String userName, String action, String details) {
        return recordActivity(boutiqueId, userId, userName, action, "SUCCESS", details, null, null);
    }

    @Transactional
    public ActivityLogResponse recordActivity(UUID boutiqueId, UUID userId, String userName,
                                               String action, String status, String details,
                                               String ipAddress, String deviceInfo) {
        ActivityLogResponse response = activityLogService.record(
                boutiqueId, userId, userName, action,
                status != null ? status : "SUCCESS",
                details, ipAddress, deviceInfo);
        try {
            webSocketService.sendCaisseActivityUpdate(boutiqueId, response);
        } catch (Exception e) {
            // non-blocking
        }
        return response;
    }

    private OrderResponse mapOrderToResponse(Order o) {
        return OrderResponse.builder()
                .id(o.getId()).boutiqueId(o.getBoutique().getId())
                .userId(o.getUser() != null ? o.getUser().getId() : null)
                .customerId(o.getCustomer() != null ? o.getCustomer().getId() : null)
                .customerName(o.getCustomer() != null ? o.getCustomer().getFullName() : "Client inconnu")
                .orderNumber(o.getOrderNumber()).status(o.getStatus())
                .subtotal(o.getSubtotal()).shippingFee(o.getShippingFee())
                .discount(o.getDiscount()).total(o.getTotal())
                .paymentMethod(o.getPaymentMethod()).paymentStatus(o.getPaymentStatus())
                .paymentRef(o.getPaymentRef()).shippingAddress(o.getShippingAddress())
                .deliveryCompany(o.getDeliveryCompany()).trackingNumber(o.getTrackingNumber())
                .notes(o.getNotes()).invoiceNumber(o.getInvoiceNumber())
                .invoiceCreatedAt(o.getInvoiceCreatedAt()).createdAt(o.getCreatedAt())
                .build();
    }

    private ActivityLogResponse mapActivityToResponse(ActivityLog log) {
        return ActivityLogResponse.builder()
                .id(log.getId())
                .boutiqueId(log.getBoutiqueId())
                .userId(log.getUserId())
                .userName(log.getUserName())
                .action(log.getAction())
                .details(log.getDetails())
                .createdAt(log.getCreatedAt())
                .build();
    }
}
