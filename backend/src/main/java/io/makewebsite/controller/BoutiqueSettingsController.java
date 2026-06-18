package io.makewebsite.controller;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.dto.response.ApiResponse;
import io.makewebsite.security.Permission;
import io.makewebsite.security.UserPrincipal;
import io.makewebsite.service.BoutiquePermissionService;
import io.makewebsite.service.StoreGeneratorService;
import io.makewebsite.service.StoreSettingsService;
import io.makewebsite.service.UploadService;
import io.makewebsite.util.StripeConfigUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/boutiques/{id}")
@RequiredArgsConstructor
@Slf4j
public class BoutiqueSettingsController {

    private final BoutiqueRepository boutiqueRepository;
    private final StoreSliderRepository sliderRepository;
    private final StoreVideoRepository videoRepository;
    private final StoreLanguageRepository languageRepository;
    private final BoutiqueCountryRepository countryRepository;
    private final ProductRepository productRepository;
    private final StoreGeneratorService storeGeneratorService;
    private final StoreSettingsService storeSettingsService;
    private final UploadService uploadService;
    private final BoutiquePermissionService boutiquePermissionService;

    private Boutique getBoutique(UUID id, UUID userId) {
        boutiquePermissionService.requireBoutiquePermission(userId, id, Permission.SETTINGS_WRITE);
        return boutiqueRepository.findByIdWithUser(id)
                .orElseThrow(() -> new RuntimeException("Boutique not found"));
    }

    private void regenerateSafely(UUID id) {
        try {
            storeGeneratorService.regenerate(id);
        } catch (Exception e) {
            log.warn("Store regeneration failed after settings save for boutique {}: {}", id, e.getMessage(), e);
        }
    }

    private String slugify(String value) {
        if (value == null) return "";
        return value.trim().toLowerCase()
                .replaceAll("[^a-z0-9\\s-]", "")
                .replaceAll("\\s+", "-")
                .replaceAll("-+", "-");
    }

    // ========== BASIC CONFIG ==========
    @PutMapping("/config")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateConfig(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        try {
            Boutique b = getBoutique(id, principal.getUserId());

            if (body.containsKey("email")) b.setEmail((String) body.get("email"));
            if (body.containsKey("address")) b.setAddress((String) body.get("address"));
            if (body.containsKey("phone")) b.setPhone((String) body.get("phone"));
            if (body.containsKey("companyName")) {
                b.setName((String) body.get("companyName"));
            }
            if (body.containsKey("topBarText")) b.setAnnouncementText((String) body.get("topBarText"));
            if (body.containsKey("tva")) b.setTva(Double.parseDouble(body.get("tva").toString()));
            if (body.containsKey("deliveryFees")) b.setDeliveryFees(Double.parseDouble(body.get("deliveryFees").toString()));
            if (body.containsKey("cashDelivery")) b.setCashOnDelivery(asBoolean(body.get("cashDelivery")));
            if (body.containsKey("stripeEnabled") || body.containsKey("stripeStatus")) {
                Boolean stripeEnabled = body.containsKey("stripeEnabled") ? asBoolean(body.get("stripeEnabled")) : null;
                String stripeStatus = body.containsKey("stripeStatus") ? Objects.toString(body.get("stripeStatus"), null) : null;
                StripeConfigUtils.applyStripeState(b, stripeEnabled, stripeStatus);
            }
            if (body.containsKey("simpleCheckout")) b.setSimpleCheckout(asBoolean(body.get("simpleCheckout")));
            if (body.containsKey("timezone")) b.setTimezone((String) body.get("timezone"));
            if (body.containsKey("freeShippingThreshold")) b.setFreeShippingThreshold(Double.parseDouble(body.get("freeShippingThreshold").toString()));
            if (body.containsKey("estimatedDeliveryDays")) b.setEstimatedDeliveryDays(Integer.parseInt(body.get("estimatedDeliveryDays").toString()));
            if (body.containsKey("enableLocalPickup")) b.setEnableLocalPickup(asBoolean(body.get("enableLocalPickup")));
            if (body.containsKey("enableEmailNotifications")) b.setEnableEmailNotifications(asBoolean(body.get("enableEmailNotifications")));
            if (body.containsKey("enableSmsNotifications")) b.setEnableSmsNotifications(asBoolean(body.get("enableSmsNotifications")));
            if (body.containsKey("enablePushNotifications")) b.setEnablePushNotifications(asBoolean(body.get("enablePushNotifications")));
            if (body.containsKey("enableMarketingEmails")) b.setEnableMarketingEmails(asBoolean(body.get("enableMarketingEmails")));
            if (body.containsKey("enableOrderAlerts")) b.setEnableOrderAlerts(asBoolean(body.get("enableOrderAlerts")));
            if (body.containsKey("clientMessagingEnabled")) b.setClientMessagingEnabled(asBoolean(body.get("clientMessagingEnabled")));
            boutiqueRepository.save(b);
            regenerateSafely(id);
            return ResponseEntity.ok(ApiResponse.ok("Configuration sauvegardée", Map.of("id", b.getId())));
        } catch (Exception e) {
            log.error("Config update failed for boutique {}: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("Erreur lors de la sauvegarde: " + e.getClass().getSimpleName() + " - " + e.getMessage()));
        }
    }

    @PatchMapping("/client-messaging")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateClientMessaging(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        b.setClientMessagingEnabled(asBoolean(body.get("enabled")));
        boutiqueRepository.save(b);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Messagerie client mise a jour", Map.of(
                "id", b.getId(),
                "clientMessagingEnabled", b.getClientMessagingEnabled()
        )));
    }

    // ========== LOGO ==========
    @PostMapping("/logo")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadLogo(
            @PathVariable UUID id,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        String url = uploadService.uploadImage(file);
        b.setLogoUrl(url);
        boutiqueRepository.save(b);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Logo mis à jour", Map.of("logoUrl", url)));
    }

    // ========== BANNER ==========
    @PostMapping("/banner")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadBanner(
            @PathVariable UUID id,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        String url = uploadService.uploadImage(file);
        b.setBannerUrl(url);
        boutiqueRepository.save(b);
        return ResponseEntity.ok(ApiResponse.ok("Bannière mise à jour", Map.of("bannerUrl", url)));
    }

    // ========== FAVICON ==========
    @PostMapping("/favicon")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadFavicon(
            @PathVariable UUID id,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        String url = uploadService.uploadImage(file);
        b.setFaviconUrl(url);
        boutiqueRepository.save(b);
        return ResponseEntity.ok(ApiResponse.ok("Favicon mis à jour", Map.of("faviconUrl", url)));
    }

    // ========== CURRENCY ==========
    @PutMapping("/currency")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateCurrency(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        if (body.containsKey("currency")) b.setCurrency(body.get("currency"));
        boutiqueRepository.save(b);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Devise mise à jour", Map.of("currency", b.getCurrency())));
    }

    // ========== DELIVERY SETTINGS ==========
    @PutMapping("/delivery-settings")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateDeliverySettings(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        if (body.containsKey("deliveryFees")) b.setDeliveryFees(Double.parseDouble(body.get("deliveryFees").toString()));
        if (body.containsKey("freeShippingThreshold")) b.setFreeShippingThreshold(Double.parseDouble(body.get("freeShippingThreshold").toString()));
        if (body.containsKey("estimatedDeliveryDays")) b.setEstimatedDeliveryDays(Integer.parseInt(body.get("estimatedDeliveryDays").toString()));
        if (body.containsKey("enableLocalPickup")) b.setEnableLocalPickup(asBoolean(body.get("enableLocalPickup")));
        boutiqueRepository.save(b);
        return ResponseEntity.ok(ApiResponse.ok("Paramètres de livraison sauvegardés", Map.of("id", b.getId())));
    }

    // ========== NOTIFICATION SETTINGS ==========
    @PutMapping("/notification-settings")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateNotificationSettings(
            @PathVariable UUID id,
            @RequestBody Map<String, Object> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        if (body.containsKey("enableEmailNotifications")) b.setEnableEmailNotifications(asBoolean(body.get("enableEmailNotifications")));
        if (body.containsKey("enableSmsNotifications")) b.setEnableSmsNotifications(asBoolean(body.get("enableSmsNotifications")));
        if (body.containsKey("enablePushNotifications")) b.setEnablePushNotifications(asBoolean(body.get("enablePushNotifications")));
        if (body.containsKey("enableMarketingEmails")) b.setEnableMarketingEmails(asBoolean(body.get("enableMarketingEmails")));
        if (body.containsKey("enableOrderAlerts")) b.setEnableOrderAlerts(asBoolean(body.get("enableOrderAlerts")));
        boutiqueRepository.save(b);
        return ResponseEntity.ok(ApiResponse.ok("Paramètres de notification sauvegardés", Map.of("id", b.getId())));
    }

    // ========== SLIDERS ==========
    @GetMapping("/sliders")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getSliders(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        List<Map<String, Object>> list = sliderRepository.findByBoutiqueIdOrderBySortOrderAsc(id).stream()
                .map(s -> { Map<String, Object> m = new LinkedHashMap<>(); m.put("id", s.getId()); m.put("imageUrl", s.getImageUrl()); m.put("sortOrder", s.getSortOrder()); return m; })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(list));
    }

    @PostMapping("/sliders")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> addSlider(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        String imageUrl = body.get("imageUrl");
        if (imageUrl == null || imageUrl.isBlank())
            return ResponseEntity.badRequest().body(ApiResponse.error("imageUrl is required"));
        StoreSlider slider = StoreSlider.builder().boutique(b).imageUrl(imageUrl).build();
        slider = sliderRepository.save(slider);
        regenerateSafely(id);
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("id", slider.getId()); res.put("imageUrl", slider.getImageUrl());
        return ResponseEntity.ok(ApiResponse.ok("Slider ajouté", res));
    }

    @DeleteMapping("/sliders/{sliderId}")
    @Transactional
    public ResponseEntity<ApiResponse<Void>> deleteSlider(
            @PathVariable UUID id, @PathVariable UUID sliderId,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        sliderRepository.deleteById(sliderId);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Slider supprimé", null));
    }

    // ========== VIDEOS ==========
    @GetMapping("/videos")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getVideos(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        List<Map<String, Object>> list = videoRepository.findByBoutiqueIdOrderBySortOrderAsc(id).stream()
                .map(v -> { Map<String, Object> m = new LinkedHashMap<>(); m.put("id", v.getId()); m.put("videoUrl", v.getVideoUrl()); return m; })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(list));
    }

    @PostMapping("/videos")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> addVideo(
            @PathVariable UUID id,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        String url = uploadService.uploadFile(file, "videos");
        StoreVideo video = StoreVideo.builder().boutique(b).videoUrl(url).build();
        video = videoRepository.save(video);
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("id", video.getId()); res.put("videoUrl", video.getVideoUrl());
        return ResponseEntity.ok(ApiResponse.ok("Vidéo ajoutée", res));
    }

    @DeleteMapping("/videos/{videoId}")
    @Transactional
    public ResponseEntity<ApiResponse<Void>> deleteVideo(
            @PathVariable UUID id, @PathVariable UUID videoId,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        videoRepository.deleteById(videoId);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Vidéo supprimée", null));
    }

    // ========== SOCIAL ==========
    @PutMapping("/store-social")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSocial(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        if (body.containsKey("facebookUrl")) b.setFacebookUrl(body.get("facebookUrl"));
        if (body.containsKey("twitterUrl")) b.setTwitterUrl(body.get("twitterUrl"));
        if (body.containsKey("instagramUrl")) b.setInstagramUrl(body.get("instagramUrl"));
        if (body.containsKey("tiktokUrl")) b.setTiktokUrl(body.get("tiktokUrl"));
        if (body.containsKey("linkedinUrl")) b.setLinkedinUrl(body.get("linkedinUrl"));
        boutiqueRepository.save(b);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Réseaux sociaux mis à jour", Map.of("id", b.getId())));
    }

    // ========== COUNTRIES ==========
    @GetMapping("/countries")
    public ResponseEntity<ApiResponse<List<String>>> getCountries(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        List<String> list = countryRepository.findByBoutiqueId(id).stream()
                .map(BoutiqueCountry::getCountryCode).collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(list));
    }

    @PostMapping("/countries")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> addCountry(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        String name = body.get("countryName");
        if (name == null || name.isBlank())
            return ResponseEntity.badRequest().body(ApiResponse.error("countryName is required"));
        String code = name.trim().toUpperCase(Locale.ROOT);
        String displayName = getCountryDisplayName(code);
        BoutiqueCountry bc = BoutiqueCountry.builder()
                .boutique(b)
                .countryCode(code)
                .countryName(displayName)
                .build();
        countryRepository.save(bc);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Pays ajouté", Map.of("countryName", displayName, "countryCode", code)));
    }

    @DeleteMapping("/countries/{countryName}")
    @Transactional
    public ResponseEntity<ApiResponse<Void>> deleteCountry(
            @PathVariable UUID id, @PathVariable String countryName,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        countryRepository.findByBoutiqueIdAndCountryCode(id, countryName.toUpperCase(Locale.ROOT))
                .ifPresent(c -> countryRepository.delete(c));
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Pays supprimé", null));
    }

    // ========== LANGUAGE ==========
    @GetMapping("/language")
    public ResponseEntity<ApiResponse<Map<String, String>>> getLanguage(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserPrincipal principal) {
        getBoutique(id, principal.getUserId());
        StoreLanguage lang = languageRepository.findByBoutiqueId(id).orElse(null);
        Map<String, String> m = new LinkedHashMap<>();
        if (lang != null) {
            m.put("addToCart", lang.getAddToCart()); m.put("checkoutTitle", lang.getCheckoutTitle());
            m.put("totalPriceLabel", lang.getTotalPriceLabel()); m.put("shippingCostLabel", lang.getShippingCostLabel());
            m.put("grandTotalLabel", lang.getGrandTotalLabel()); m.put("fullNamePlaceholder", lang.getFullNamePlaceholder());
            m.put("emailPlaceholder", lang.getEmailPlaceholder()); m.put("billingAddressPlaceholder", lang.getBillingAddressPlaceholder());
            m.put("cityPlaceholder", lang.getCityPlaceholder()); m.put("phonePlaceholder", lang.getPhonePlaceholder());
            m.put("paymentMethodLabel", lang.getPaymentMethodLabel()); m.put("placeOrderButton", lang.getPlaceOrderButton());
            m.put("noProducts", lang.getNoProducts()); m.put("footerText", lang.getFooterText());
            m.put("orderConfirmationTitle", lang.getOrderConfirmationTitle()); m.put("searchProducts", lang.getSearchProducts());
            m.put("seeAll", lang.getSeeAll()); m.put("cashOnDelivery", lang.getCashOnDelivery());
            m.put("followUs", lang.getFollowUs()); m.put("support", lang.getSupport());
            m.put("menuLabel", lang.getMenuLabel()); m.put("cartTitle", lang.getCartTitle());
            m.put("selectCountry", lang.getSelectCountry());
        }
        return ResponseEntity.ok(ApiResponse.ok(m));
    }

    @PutMapping("/language")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateLanguage(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        StoreLanguage lang = languageRepository.findByBoutiqueId(id).orElse(null);
        if (lang == null) {
            lang = StoreLanguage.builder().boutique(b).build();
        }
        if (body.containsKey("addToCart")) lang.setAddToCart(body.get("addToCart"));
        if (body.containsKey("checkoutTitle")) lang.setCheckoutTitle(body.get("checkoutTitle"));
        if (body.containsKey("totalPriceLabel")) lang.setTotalPriceLabel(body.get("totalPriceLabel"));
        if (body.containsKey("shippingCostLabel")) lang.setShippingCostLabel(body.get("shippingCostLabel"));
        if (body.containsKey("grandTotalLabel")) lang.setGrandTotalLabel(body.get("grandTotalLabel"));
        if (body.containsKey("fullNamePlaceholder")) lang.setFullNamePlaceholder(body.get("fullNamePlaceholder"));
        if (body.containsKey("emailPlaceholder")) lang.setEmailPlaceholder(body.get("emailPlaceholder"));
        if (body.containsKey("billingAddressPlaceholder")) lang.setBillingAddressPlaceholder(body.get("billingAddressPlaceholder"));
        if (body.containsKey("cityPlaceholder")) lang.setCityPlaceholder(body.get("cityPlaceholder"));
        if (body.containsKey("phonePlaceholder")) lang.setPhonePlaceholder(body.get("phonePlaceholder"));
        if (body.containsKey("paymentMethodLabel")) lang.setPaymentMethodLabel(body.get("paymentMethodLabel"));
        if (body.containsKey("placeOrderButton")) lang.setPlaceOrderButton(body.get("placeOrderButton"));
        if (body.containsKey("noProducts")) lang.setNoProducts(body.get("noProducts"));
        if (body.containsKey("footerText")) lang.setFooterText(body.get("footerText"));
        if (body.containsKey("orderConfirmationTitle")) lang.setOrderConfirmationTitle(body.get("orderConfirmationTitle"));
        if (body.containsKey("searchProducts")) lang.setSearchProducts(body.get("searchProducts"));
        if (body.containsKey("seeAll")) lang.setSeeAll(body.get("seeAll"));
        if (body.containsKey("cashOnDelivery")) lang.setCashOnDelivery(body.get("cashOnDelivery"));
        if (body.containsKey("followUs")) lang.setFollowUs(body.get("followUs"));
        if (body.containsKey("support")) lang.setSupport(body.get("support"));
        if (body.containsKey("menuLabel")) lang.setMenuLabel(body.get("menuLabel"));
        if (body.containsKey("cartTitle")) lang.setCartTitle(body.get("cartTitle"));
        if (body.containsKey("selectCountry")) lang.setSelectCountry(body.get("selectCountry"));
        languageRepository.save(lang);
        regenerateSafely(id);
        return ResponseEntity.ok(ApiResponse.ok("Langue mise à jour", Map.of("id", b.getId())));
    }

    // ========== FACEBOOK META ==========
    @PutMapping("/facebook")
    @Transactional
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateFacebook(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body,
            @AuthenticationPrincipal UserPrincipal principal) {
        Boutique b = getBoutique(id, principal.getUserId());
        if (body.containsKey("pageAccessToken")) b.setStoreConfig(body.get("pageAccessToken"));
        if (body.containsKey("pageId")) b.setFacebookPixelId(body.get("pageId"));
        boutiqueRepository.save(b);
        return ResponseEntity.ok(ApiResponse.ok("Configuration Facebook sauvegardée", Map.of("id", b.getId())));
    }

    // ========== CHECK NAME ==========
    @PostMapping("/check-name")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkName(
            @RequestBody Map<String, String> body) {
        String name = body.get("name");
        String currentId = body.get("currentBoutiqueId");
        Optional<Boutique> existing = boutiqueRepository.findBySlug(name);
        boolean available = existing.isEmpty() || (currentId != null && existing.get().getId().toString().equals(currentId));
        return ResponseEntity.ok(ApiResponse.ok(Map.of("available", available)));
    }

    private static String getCountryDisplayName(String code) {
        if (code == null || code.length() != 2) return code;
        Locale locale = new Locale("", code);
        String name = locale.getDisplayName(Locale.FRENCH);
        if (name == null || name.isBlank() || name.equals(code)) {
            name = locale.getDisplayName(Locale.ENGLISH);
        }
        return name;
    }

    private static boolean asBoolean(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        if (value == null) {
            return false;
        }
        String text = value.toString().trim();
        return "true".equalsIgnoreCase(text)
                || "yes".equalsIgnoreCase(text)
                || "1".equals(text)
                || "active".equalsIgnoreCase(text)
                || "enabled".equalsIgnoreCase(text);
    }
}
