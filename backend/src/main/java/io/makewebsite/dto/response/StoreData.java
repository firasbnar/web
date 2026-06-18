package io.makewebsite.dto.response;

import io.makewebsite.entity.*;
import io.makewebsite.util.StripeConfigUtils;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class StoreData {
    private Boutique boutique;
    private List<PublicProductDto> products;
    private List<PublicCategoryDto> categories;
    private List<StoreSlider> sliders;
    private StoreLanguage language;
    private List<BoutiqueCountry> countries;
    private PublicProductDto detailProduct;

    private static final String DEFAULT_PRODUCT_IMAGE = "/images/default-product.png";

    public String getDetailProductImg() {
        if (detailProduct == null) return DEFAULT_PRODUCT_IMAGE;
        return resolveImageUrl(detailProduct.getFirstImage());
    }

    public List<String> getDetailProductImages() {
        if (detailProduct == null) return List.of(DEFAULT_PRODUCT_IMAGE);
        List<String> images = parseImageList(detailProduct.getImages());
        if (images.isEmpty()) return List.of(DEFAULT_PRODUCT_IMAGE);
        return images.stream().map(this::resolveImageUrl).collect(Collectors.toList());
    }

    public boolean isDetailHasMultipleImages() {
        if (detailProduct == null) return false;
        return parseImageList(detailProduct.getImages()).size() > 1;
    }

    public boolean isDetailHasColors() {
        if (detailProduct == null) return false;
        String colors = detailProduct.getColors();
        return colors != null && !colors.isBlank() && !colors.equals("[]");
    }

    public List<String> getDetailColorList() {
        if (!isDetailHasColors()) return List.of();
        return parseList(detailProduct.getColors());
    }

    public boolean isDetailHasSizes() {
        if (detailProduct == null) return false;
        String sizes = detailProduct.getSizes();
        return sizes != null && !sizes.isBlank() && !sizes.equals("[]");
    }

    public List<String> getDetailSizeList() {
        if (!isDetailHasSizes()) return List.of();
        return parseList(detailProduct.getSizes());
    }

    // ── Boutique fields ──
    public String getSlug() { return boutique != null ? boutique.getSlug() : ""; }
    public String getName() { return boutique != null ? boutique.getName() : ""; }
    public UUID getBoutiqueId() { return boutique != null ? boutique.getId() : null; }
    public String getBoutiqueDescription() { return boutique != null ? boutique.getDescription() : ""; }
    public String getWhatsappNumber() { return boutique != null ? boutique.getWhatsappNumber() : ""; }
    public String getFacebookUrl() { return boutique != null ? boutique.getFacebookUrl() : ""; }
    public String getInstagramUrl() { return boutique != null ? boutique.getInstagramUrl() : ""; }
    public String getTiktokUrl() { return boutique != null ? boutique.getTiktokUrl() : ""; }
    public String getFaviconUrl() { return boutique != null ? boutique.getFaviconUrl() : ""; }
    public String getEmail() { return boutique != null ? boutique.getEmail() : ""; }
    public String getPhone() { return boutique != null ? boutique.getPhone() : ""; }
    public String getAddress() { return boutique != null ? boutique.getAddress() : ""; }
    public double getTva() { return boutique != null && boutique.getTva() != null ? boutique.getTva() : 0.0; }

    public String getCurrencySymbol() {
        if (boutique == null || boutique.getCurrency() == null) return "DT";
        return switch (boutique.getCurrency()) {
            case "TND" -> "DT";
            case "EUR" -> "\u20AC";
            default -> "$";
        };
    }

    public String getStoreUrl() { return "/store/" + getSlug(); }
    public String getAnnouncement() { return boutique != null ? boutique.getAnnouncementText() : ""; }
    public String getLogoUrl() { return boutique != null ? boutique.getLogoUrl() : ""; }

    public String getPrimaryColor() { return resolveColor(boutique != null ? boutique.getPrimaryColor() : null, "#6A0DAD"); }
    public String getHeaderBg() { return resolveColor(boutique != null ? boutique.getHeaderColor() : null, "#ededed"); }
    public String getFooterBg() { return resolveColor(boutique != null ? boutique.getFooterColor() : null, "#dbdbdb"); }
    public String getBodyBg() { return resolveColor(boutique != null ? boutique.getBodyColor() : null, "#ffffff"); }
    public String getCardBg() { return resolveColor(boutique != null ? boutique.getCardProductColor() : null, "#fafafa"); }
    public String getAccent() { return resolveColor(boutique != null ? (boutique.getButtonColor() != null ? boutique.getButtonColor() : boutique.getPrimaryColor()) : null, "#6A0DAD"); }
    public String getTopBarBg() { return resolveColor(boutique != null ? (boutique.getTopBarColor() != null ? boutique.getTopBarColor() : boutique.getPrimaryColor()) : null, "#6A0DAD"); }
    public String getTextColor() { return resolveColor(boutique != null ? (boutique.getTextColor() != null ? boutique.getTextColor() : boutique.getPrimaryColor()) : null, "#751515"); }

    public double getDeliveryFees() { return boutique != null && boutique.getDeliveryFees() != null ? boutique.getDeliveryFees() : 7.0; }
    public boolean isCashOnDelivery() { return boutique != null && boutique.getCashOnDelivery() != null && boutique.getCashOnDelivery(); }
    public boolean isStripeEnabled() { return boutique != null && StripeConfigUtils.isStripeEnabled(boutique); }
    public boolean isStripeActive() { return isStripeEnabled(); }
    public String getStripeStatus() {
        return boutique != null
                ? StripeConfigUtils.normalizeStripeStatus(boutique.getStripeEnabled(), boutique.getStripeStatus())
                : "DISABLED";
    }
    public boolean isSimpleCheckout() { return boutique != null && boutique.getSimpleCheckout() != null && boutique.getSimpleCheckout(); }
    public boolean isClientMessagingEnabled() { return boutique == null || !Boolean.FALSE.equals(boutique.getClientMessagingEnabled()); }
    public String getCustomCss() { return boutique != null ? boutique.getCustomCss() : ""; }
    public String getCustomJs() { return boutique != null ? boutique.getCustomJs() : ""; }

    public String getOgTitle() {
        if (boutique == null) return "";
        if (boutique.getSeoTitle() != null && !boutique.getSeoTitle().isBlank()) return esc(boutique.getSeoTitle());
        return esc(boutique.getName()) + " | Boutique en ligne";
    }

    public String getOgDescription() {
        if (boutique == null) return "";
        if (boutique.getSeoDescription() != null && !boutique.getSeoDescription().isBlank()) return esc(boutique.getSeoDescription());
        if (boutique.getDescription() != null) return esc(boutique.getDescription());
        return esc(boutique.getName()) + " \u2013 D\u00E9couvrez nos produits en ligne.";
    }

    public String getOgImage() {
        if (boutique == null) return "";
        String og = boutique.getOgImageUrl();
        if (og != null && !og.isBlank()) return esc(resolveImageUrl(og));
        if (boutique.getLogoUrl() != null && !boutique.getLogoUrl().isBlank()) return esc(resolveImageUrl(boutique.getLogoUrl()));
        return "";
    }

    public static PublicProductDto toProductDto(Product p) {
        if (p == null) return null;
        return PublicProductDto.builder()
                .id(p.getId())
                .name(p.getName() != null ? p.getName() : "")
                .description(p.getDescription() != null ? p.getDescription() : "")
                .price(p.getPrice() != null ? p.getPrice() : BigDecimal.ZERO)
                .comparePrice(p.getComparePrice())
                .colors(p.getColors() != null ? p.getColors() : "")
                .sizes(p.getSizes() != null ? p.getSizes() : "")
                .images(p.getImages() != null ? p.getImages() : "")
                .stock(p.getStock() != null ? p.getStock() : 0)
                .categoryId(p.getCategory() != null ? p.getCategory().getId() : null)
                .categoryName(p.getCategory() != null ? p.getCategory().getName() : "")
                .firstImage(extractFirstImageStatic(p.getImages()))
                .build();
    }

    public static List<PublicProductDto> toProductDtoList(List<Product> products) {
        if (products == null) return List.of();
        return products.stream().map(StoreData::toProductDto).collect(Collectors.toList());
    }

    public static PublicCategoryDto toCategoryDto(Category c) {
        if (c == null) return null;
        return PublicCategoryDto.builder()
                .id(c.getId())
                .name(c.getName() != null ? c.getName() : "")
                .build();
    }

    public static List<PublicCategoryDto> toCategoryDtoList(List<Category> categories) {
        if (categories == null) return List.of();
        return categories.stream().map(StoreData::toCategoryDto).collect(Collectors.toList());
    }

    static String extractFirstImageStatic(String images) {
        if (images == null || images.isBlank() || images.equals("[]")) return "";
        try {
            String trimmed = images.trim();
            if (trimmed.startsWith("[")) {
                String content = trimmed.substring(1, trimmed.length() - 1).trim();
                if (content.startsWith("\"")) {
                    return content.substring(1, content.indexOf("\"", 1));
                }
                return content;
            }
            return trimmed;
        } catch (Exception e) { return ""; }
    }

    private String resolveColor(String color, String fallback) {
        if (color != null && !color.isBlank() && color.matches("#[0-9a-fA-F]{6}")) return color;
        return fallback;
    }

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private String resolveImageUrl(String url) {
        if (url == null || url.isBlank()) return DEFAULT_PRODUCT_IMAGE;
        String trimmed = url.trim();
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed;
        if (trimmed.startsWith("/")) return trimmed;
        if (trimmed.startsWith("images/") || trimmed.startsWith("uploads/")) return "/" + trimmed;
        return "/uploads/" + trimmed;
    }

    private List<String> parseList(String jsonArr) {
        if (jsonArr == null || jsonArr.isBlank() || jsonArr.equals("[]")) return List.of();
        String cleaned = jsonArr.replaceAll("[\\[\\]\"]", "");
        return Arrays.stream(cleaned.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toList());
    }

    private List<String> parseImageList(String jsonArr) {
        if (jsonArr == null || jsonArr.isBlank() || jsonArr.equals("[]")) return List.of();
        try {
            String trimmed = jsonArr.trim();
            if (trimmed.startsWith("[")) {
                String content = trimmed.substring(1, trimmed.length() - 1).trim();
                if (content.isEmpty()) return List.of();
                return Arrays.stream(content.split(","))
                        .map(s -> s.trim().replaceAll("^\"|\"$", ""))
                        .filter(s -> !s.isEmpty())
                        .collect(Collectors.toList());
            }
            return List.of(trimmed);
        } catch (Exception e) { return List.of(); }
    }
}
