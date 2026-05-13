package io.makewebsite.service;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class BoutiqueService {
    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final OrderRepository orderRepository;
    private final UserRepository userRepository;

    @Transactional
    public List<BoutiqueResponse> getMyBoutiques(UUID userId) {
        List<Boutique> boutiques = boutiqueRepository.findByUserId(userId);
        if (!boutiques.isEmpty()) {
            User user = boutiques.get(0).getUser();
            if (user.getActiveBoutiqueId() == null) {
                user.setActiveBoutiqueId(boutiques.get(0).getId());
                userRepository.save(user);
            }
        }
        return boutiques.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public BoutiqueResponse getBoutique(UUID id, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse createBoutique(CreateBoutiqueRequest request, UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Boutique boutique = Boutique.builder()
                .user(user)
                .name(request.getName())
                .slug(request.getSlug())
                .description(request.getDescription())
                .currency(request.getCurrency() != null ? request.getCurrency() : "TND")
                .language(request.getLanguage() != null ? request.getLanguage() : "fr")
                .isActive(true)
                .enableCod(true)
                .build();
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse updateBoutique(UUID id, UpdateBoutiqueRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (request.getName() != null) boutique.setName(request.getName());
        if (request.getDescription() != null) boutique.setDescription(request.getDescription());
        if (request.getCurrency() != null) boutique.setCurrency(request.getCurrency());
        if (request.getLanguage() != null) boutique.setLanguage(request.getLanguage());
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse updateTheme(UUID id, UpdateThemeRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (request.getPrimaryColor() != null) boutique.setPrimaryColor(request.getPrimaryColor());
        if (request.getSecondaryColor() != null) boutique.setSecondaryColor(request.getSecondaryColor());
        if (request.getCustomCss() != null) boutique.setCustomCss(request.getCustomCss());
        if (request.getLogoUrl() != null) boutique.setLogoUrl(request.getLogoUrl());
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse updateSeo(UUID id, UpdateSeoRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (request.getSeoTitle() != null) boutique.setSeoTitle(request.getSeoTitle());
        if (request.getSeoDescription() != null) boutique.setSeoDescription(request.getSeoDescription());
        if (request.getSeoKeywords() != null) boutique.setSeoKeywords(request.getSeoKeywords());
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse updateSocial(UUID id, UpdateSocialRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (request.getFacebookUrl() != null) boutique.setFacebookUrl(request.getFacebookUrl());
        if (request.getInstagramUrl() != null) boutique.setInstagramUrl(request.getInstagramUrl());
        if (request.getTiktokUrl() != null) boutique.setTiktokUrl(request.getTiktokUrl());
        if (request.getWhatsappNumber() != null) boutique.setWhatsappNumber(request.getWhatsappNumber());
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse updatePayments(UUID id, UpdatePaymentRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (request.getEnablePaypal() != null) boutique.setEnablePaypal(request.getEnablePaypal());
        if (request.getEnableCod() != null) boutique.setEnableCod(request.getEnableCod());
        if (request.getEnableD17() != null) boutique.setEnableD17(request.getEnableD17());
        if (request.getEnableAdeex() != null) boutique.setEnableAdeex(request.getEnableAdeex());
        if (request.getEnableJax() != null) boutique.setEnableJax(request.getEnableJax());
        if (request.getEnableIntigo() != null) boutique.setEnableIntigo(request.getEnableIntigo());
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    public List<BoutiqueResponse> getPublicBoutiques() {
        return boutiqueRepository.findAllByIsActiveTrue().stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public BoutiqueStatsResponse getStats(UUID id, UUID userId) {
        boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.atTime(LocalTime.MAX);

        long totalOrders = orderRepository.countByBoutiqueId(id);
        long todayOrders = orderRepository.countByBoutiqueIdAndCreatedAtBetween(id, startOfDay, endOfDay);
        BigDecimal totalRevenue = orderRepository.sumRevenueByBoutiqueId(id);
        BigDecimal todayRevenue = orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(id, startOfDay, endOfDay);
        long totalProducts = productRepository.countByBoutiqueId(id);
        long pendingOrders = orderRepository.countByBoutiqueIdAndStatus(id, "PENDING");

        return BoutiqueStatsResponse.builder()
                .totalOrders(totalOrders)
                .todayOrders(todayOrders)
                .totalRevenue(totalRevenue != null ? totalRevenue : BigDecimal.ZERO)
                .todayRevenue(todayRevenue != null ? todayRevenue : BigDecimal.ZERO)
                .totalProducts(totalProducts)
                .pendingOrders(pendingOrders)
                .build();
    }

    @Transactional(readOnly = true)
    public DashboardResponse getDashboard(UUID boutiqueId, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));

        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.atTime(LocalTime.MAX);

        long productCount = productRepository.countByBoutiqueId(boutiqueId);
        long totalOrders = orderRepository.countByBoutiqueId(boutiqueId);
        long todayOrders = orderRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, startOfDay, endOfDay);
        BigDecimal todayRevenue = orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, startOfDay, endOfDay);
        long pendingOrders = orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "PENDING");

        Page<Order> recentOrdersPage = orderRepository.findByBoutiqueId(boutiqueId, PageRequest.of(0, 5));
        List<OrderResponse> recentOrders = recentOrdersPage.getContent().stream()
                .map(o -> OrderResponse.builder()
                        .id(o.getId()).boutiqueId(o.getBoutique().getId())
                        .userId(o.getUser() != null ? o.getUser().getId() : null)
                        .customerId(o.getCustomer() != null ? o.getCustomer().getId() : null)
                        .customerName(o.getCustomer() != null ? o.getCustomer().getFullName() : "Client inconnu")
                        .orderNumber(o.getOrderNumber()).status(o.getStatus())
                        .subtotal(o.getSubtotal()).shippingFee(o.getShippingFee())
                        .discount(o.getDiscount()).total(o.getTotal())
                        .paymentMethod(o.getPaymentMethod()).paymentStatus(o.getPaymentStatus())
                        .shippingAddress(o.getShippingAddress()).notes(o.getNotes())
                        .createdAt(o.getCreatedAt())
                        .items(List.of())
                        .build()).collect(Collectors.toList());

        List<Product> lowStock = productRepository.findByBoutiqueIdAndStockLessThan(boutiqueId, 5);
        List<ProductResponse> lowStockProducts = lowStock.stream().limit(10).map(p -> ProductResponse.builder()
                .id(p.getId()).boutiqueId(p.getBoutique().getId())
                .categoryId(p.getCategory() != null ? p.getCategory().getId() : null)
                .name(p.getName()).price(p.getPrice()).stock(p.getStock())
                .sku(p.getSku()).images(p.getImages())
                .isActive(p.getIsActive()).isFeatured(p.getIsFeatured()).build()
        ).collect(Collectors.toList());

        List<BoutiqueResponse> allBoutiques = boutiqueRepository.findByUserId(userId).stream()
                .map(this::mapToResponse).collect(Collectors.toList());

        DashboardResponse.BoutiqueInfo boutiqueInfo = DashboardResponse.BoutiqueInfo.builder()
                .id(boutique.getId()).name(boutique.getName()).slug(boutique.getSlug())
                .logoUrl(boutique.getLogoUrl()).customDomain(boutique.getCustomDomain())
                .planName("Free").build();

        DashboardResponse.DailyStats dailyStats = DashboardResponse.DailyStats.builder()
                .ordersToday(todayOrders)
                .revenueToday(todayRevenue != null ? todayRevenue.doubleValue() : 0.0)
                .pendingOrders(pendingOrders)
                .build();

        List<DashboardResponse.QuickAction> quickActions = List.of(
                DashboardResponse.QuickAction.builder().label("Nouveau produit").icon("plus-circle").route("/products/new").build(),
                DashboardResponse.QuickAction.builder().label("Nouvelle commande").icon("shopping-cart").route("/orders/new").build(),
                DashboardResponse.QuickAction.builder().label("Voir les stats").icon("bar-chart").route("/analytics").build(),
                DashboardResponse.QuickAction.builder().label("Paramètres").icon("settings").route("/settings").build()
        );

        return DashboardResponse.builder()
                .boutique(boutiqueInfo)
                .views(0)
                .productCount(productCount)
                .subscriptionDaysLeft(0)
                .subscriptionPlan("Free")
                .quickActions(quickActions)
                .recentOrders(recentOrders)
                .lowStockProducts(lowStockProducts)
                .todayStats(dailyStats)
                .allBoutiques(allBoutiques)
                .build();
    }

    private BoutiqueResponse mapToResponse(Boutique b) {
        return BoutiqueResponse.builder()
                .id(b.getId()).name(b.getName()).slug(b.getSlug())
                .logoUrl(b.getLogoUrl()).description(b.getDescription())
                .primaryColor(b.getPrimaryColor()).secondaryColor(b.getSecondaryColor())
                .currency(b.getCurrency()).language(b.getLanguage())
                .isActive(b.getIsActive()).customDomain(b.getCustomDomain())
                .seoTitle(b.getSeoTitle()).seoDescription(b.getSeoDescription()).seoKeywords(b.getSeoKeywords())
                .facebookUrl(b.getFacebookUrl()).instagramUrl(b.getInstagramUrl())
                .tiktokUrl(b.getTiktokUrl()).whatsappNumber(b.getWhatsappNumber())
                .customCss(b.getCustomCss())
                .enablePaypal(b.getEnablePaypal()).enableCod(b.getEnableCod())
                .enableD17(b.getEnableD17()).enableAdeex(b.getEnableAdeex())
                .enableJax(b.getEnableJax()).enableIntigo(b.getEnableIntigo())
                .createdAt(b.getCreatedAt())
                .build();
    }
}
