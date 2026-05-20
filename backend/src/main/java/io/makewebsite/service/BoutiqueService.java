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
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class BoutiqueService {

    private static final Set<String> RESERVED_SLUGS = Set.of(
        "login", "register", "signup", "error", "api", "store", "stores",
        "checkout", "flutter", "assets", "uploads", "ws", "favicon",
        "admin", "super-admin", "superadmin", "dashboard", "plans",
        "home", "settings", "profile", "notifications", "messages",
        "orders", "products", "categories", "customers", "team",
        "analytics", "traffic", "pos", "reviews", "coupons",
        "delivery", "subscription", "billing", "payment",
        "index", "health", "status", "about", "contact",
        "privacy", "terms", "legal", "help", "support"
    );
    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final OrderRepository orderRepository;
    private final UserRepository userRepository;
    private final TenantRepository tenantRepository;

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
        Tenant tenant = user.getTenant();
        if (tenant == null) {
            tenant = tenantRepository.save(Tenant.builder()
                    .name((user.getFullName() != null ? user.getFullName() : "User") + "'s Tenant")
                    .build());
            user.setTenant(tenant);
            userRepository.save(user);
        }

        // Auto-generate slug from name if not provided
        String slug = request.getSlug();
        if (slug == null || slug.isBlank()) {
            slug = generateSlug(request.getName());
        } else {
            slug = slug.toLowerCase().trim().replaceAll("\\s+", "-").replaceAll("[^a-z0-9-]", "");
        }
        if (slug.isEmpty()) throw new RuntimeException("Impossible de générer un slug valide");
        if (RESERVED_SLUGS.contains(slug)) throw new RuntimeException("Ce slug est réservé et ne peut pas être utilisé");

        // Ensure uniqueness
        String finalSlug = slug;
        int counter = 1;
        while (boutiqueRepository.existsBySlug(finalSlug)) {
            finalSlug = slug + "-" + (++counter);
        }

        Boutique boutique = Boutique.builder()
                .user(user)
                .tenant(tenant)
                .name(request.getName())
                .slug(finalSlug)
                .description(request.getDescription())
                .currency(request.getCurrency() != null ? request.getCurrency() : "TND")
                .language(request.getLanguage() != null ? request.getLanguage() : "fr")
                .isActive(true)
                .enableCod(true)
                .build();
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    private String generateSlug(String name) {
        return name.toLowerCase().trim()
                .replaceAll("\\s+", "-")
                .replaceAll("[^a-z0-9-]", "")
                .replaceAll("-{2,}", "-")
                .replaceAll("^-|-$", "");
    }

    @Transactional
    public BoutiqueResponse updateBoutique(UUID id, UpdateBoutiqueRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (request.getName() != null) boutique.setName(request.getName());
        if (request.getDescription() != null) boutique.setDescription(request.getDescription());
        if (request.getEmail() != null) boutique.setEmail(request.getEmail());
        if (request.getPhone() != null) boutique.setPhone(request.getPhone());
        if (request.getAddress() != null) boutique.setAddress(request.getAddress());
        if (request.getCurrency() != null) boutique.setCurrency(request.getCurrency());
        if (request.getLanguage() != null) boutique.setLanguage(request.getLanguage());
        if (request.getTimezone() != null) boutique.setTimezone(request.getTimezone());
        if (request.getCustomDomain() != null) boutique.setCustomDomain(request.getCustomDomain());
        if (request.getSlug() != null) {
            String newSlug = request.getSlug().toLowerCase().trim().replaceAll("\\s+", "-").replaceAll("[^a-z0-9-]", "");
            if (newSlug.isEmpty()) throw new RuntimeException("Le slug ne peut pas être vide");
            if (RESERVED_SLUGS.contains(newSlug)) throw new RuntimeException("Ce slug est réservé");
            if (!newSlug.equals(boutique.getSlug()) && boutiqueRepository.existsBySlug(newSlug)) {
                throw new RuntimeException("Ce slug est déjà utilisé par une autre boutique");
            }
            boutique.setSlug(newSlug);
        }
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse publishBoutique(UUID id, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        boutique.setIsPublished(true);
        boutique.setPublishedAt(LocalDateTime.now());
        boutique = boutiqueRepository.save(boutique);
        return mapToResponse(boutique);
    }

    @Transactional
    public BoutiqueResponse unpublishBoutique(UUID id, UUID userId) {
        Boutique boutique = boutiqueRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        boutique.setIsPublished(false);
        boutique.setPublishedAt(null);
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
        if (request.getFontFamily() != null) boutique.setFontFamily(request.getFontFamily());
        if (request.getDarkMode() != null) boutique.setDarkMode(request.getDarkMode());
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
        if (request.getOgImageUrl() != null) boutique.setOgImageUrl(request.getOgImageUrl());
        if (request.getFacebookPixelId() != null) boutique.setFacebookPixelId(request.getFacebookPixelId());
        if (request.getGoogleAnalyticsId() != null) boutique.setGoogleAnalyticsId(request.getGoogleAnalyticsId());
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
        if (request.getStripePublishableKey() != null) boutique.setStripePublishableKey(request.getStripePublishableKey());
        if (request.getStripeSecretKey() != null) boutique.setStripeSecretKey(request.getStripeSecretKey());
        if (request.getStripeWebhookSecret() != null) boutique.setStripeWebhookSecret(request.getStripeWebhookSecret());
        if (request.getPaypalClientId() != null) boutique.setPaypalClientId(request.getPaypalClientId());
        if (request.getPaypalSecret() != null) boutique.setPaypalSecret(request.getPaypalSecret());
        if (request.getPaypalWebhookId() != null) boutique.setPaypalWebhookId(request.getPaypalWebhookId());
        if (request.getKonnectMerchantId() != null) boutique.setKonnectMerchantId(request.getKonnectMerchantId());
        if (request.getKonnectApiKey() != null) boutique.setKonnectApiKey(request.getKonnectApiKey());
        if (request.getKonnectStatus() != null) boutique.setKonnectStatus(request.getKonnectStatus());
        if (request.getD17MerchantNumber() != null) boutique.setD17MerchantNumber(request.getD17MerchantNumber());
        if (request.getD17QrCodeUrl() != null) boutique.setD17QrCodeUrl(request.getD17QrCodeUrl());
        if (request.getD17Status() != null) boutique.setD17Status(request.getD17Status());
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

    @Transactional
    public BoutiqueResponse updateTelegramSettings(UUID boutiqueId, TelegramSettingsRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        if (!boutique.getUser().getId().equals(userId)) {
            throw new RuntimeException("Accès refusé");
        }
        User owner = boutique.getUser();

        if (request.getTelegramChatId() != null) {
            String cleaned = request.getTelegramChatId().replaceAll("[^0-9]", "");
            if (cleaned.isEmpty()) {
                throw new RuntimeException("L'ID Chat Telegram doit être un nombre valide");
            }
            owner.setTelegramChatId(cleaned);
        }

        if (request.getTelegramEnabled() != null) {
            if (Boolean.TRUE.equals(request.getTelegramEnabled()) && owner.getTelegramChatId() == null) {
                throw new RuntimeException("Veuillez d'abord saisir un ID Chat Telegram");
            }
            owner.setTelegramEnabled(request.getTelegramEnabled());
        }

        userRepository.save(owner);
        return mapToResponse(boutique);
    }

    private BoutiqueResponse mapToResponse(Boutique b) {
        String publicUrl = "/store/" + b.getSlug();
        String publicationStatus;
        if ("FROZEN".equals(b.getStoreStatus())) publicationStatus = "FROZEN";
        else if ("SUSPENDED".equals(b.getStoreStatus())) publicationStatus = "SUSPENDED";
        else if (Boolean.FALSE.equals(b.getIsPublished())) publicationStatus = "DRAFT";
        else publicationStatus = "PUBLISHED";
        return BoutiqueResponse.builder()
                .id(b.getId()).name(b.getName()).slug(b.getSlug())
                .logoUrl(b.getLogoUrl()).description(b.getDescription())
                .email(b.getEmail()).phone(b.getPhone()).address(b.getAddress())
                .primaryColor(b.getPrimaryColor()).secondaryColor(b.getSecondaryColor())
                .currency(b.getCurrency()).language(b.getLanguage()).timezone(b.getTimezone())
                .storeConfig(b.getStoreConfig())
                .headerColor(b.getHeaderColor()).footerColor(b.getFooterColor())
                .bodyColor(b.getBodyColor()).cardProductColor(b.getCardProductColor())
                .buttonColor(b.getButtonColor()).topBarColor(b.getTopBarColor())
                .textColor(b.getTextColor())
                .isActive(b.getIsActive()).customDomain(b.getCustomDomain())
                .seoTitle(b.getSeoTitle()).seoDescription(b.getSeoDescription()).seoKeywords(b.getSeoKeywords())
                .ogImageUrl(b.getOgImageUrl())
                .facebookUrl(b.getFacebookUrl()).instagramUrl(b.getInstagramUrl())
                .tiktokUrl(b.getTiktokUrl()).twitterUrl(b.getTwitterUrl())
                .linkedinUrl(b.getLinkedinUrl()).whatsappNumber(b.getWhatsappNumber())
                .customCss(b.getCustomCss()).customJs(b.getCustomJs())
                .enablePaypal(b.getEnablePaypal()).enableCod(b.getEnableCod())
                .enableD17(b.getEnableD17()).enableAdeex(b.getEnableAdeex())
                .enableJax(b.getEnableJax()).enableIntigo(b.getEnableIntigo())
                .bannerUrl(b.getBannerUrl()).faviconUrl(b.getFaviconUrl())
                .fontFamily(b.getFontFamily()).darkMode(b.getDarkMode())
                .announcementText(b.getAnnouncementText())
                .deliveryFees(b.getDeliveryFees()).tva(b.getTva())
                .simpleCheckout(b.getSimpleCheckout()).cashOnDelivery(b.getCashOnDelivery())
                .konnectMerchantId(b.getKonnectMerchantId()).konnectApiKey(b.getKonnectApiKey()).konnectStatus(b.getKonnectStatus())
                .d17MerchantNumber(b.getD17MerchantNumber()).d17QrCodeUrl(b.getD17QrCodeUrl()).d17Status(b.getD17Status())
                .facebookPixelId(b.getFacebookPixelId()).googleAnalyticsId(b.getGoogleAnalyticsId())
                .stripePublishableKey(b.getStripePublishableKey()).paypalClientId(b.getPaypalClientId())
                .freeShippingThreshold(b.getFreeShippingThreshold()).estimatedDeliveryDays(b.getEstimatedDeliveryDays())
                .enableLocalPickup(b.getEnableLocalPickup())
                .enableEmailNotifications(b.getEnableEmailNotifications()).enableSmsNotifications(b.getEnableSmsNotifications())
                .enablePushNotifications(b.getEnablePushNotifications()).enableMarketingEmails(b.getEnableMarketingEmails())
                .enableOrderAlerts(b.getEnableOrderAlerts())
                .teamEnabled(b.getTeamEnabled()).clientMessagingEnabled(b.getClientMessagingEnabled())
                .telegramChatId(b.getUser().getTelegramChatId())
                .telegramEnabled(b.getUser().getTelegramEnabled())
                .storeStatus(b.getStoreStatus())
                .publicationStatus(publicationStatus)
                .frozenAt(b.getFrozenAt() != null ? b.getFrozenAt().toString() : null)
                .freezeReason(b.getFreezeReason())
                .isPublished(b.getIsPublished())
                .publishedAt(b.getPublishedAt() != null ? b.getPublishedAt().toString() : null)
                .publicUrl(publicUrl)
                .createdAt(b.getCreatedAt())
                .build();
    }
}
