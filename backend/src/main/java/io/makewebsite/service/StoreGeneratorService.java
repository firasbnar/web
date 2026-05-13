package io.makewebsite.service;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.File;
import java.io.IOException;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Year;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class StoreGeneratorService {

    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    private final StoreSliderRepository sliderRepository;
    private final StoreLanguageRepository languageRepository;
    private final BoutiqueCountryRepository countryRepository;

    private static final String STORE_FILES_DIR = "store-files";

    @Transactional
    public void regenerate(UUID boutiqueId) {
        Boutique b = boutiqueRepository.findById(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Boutique not found: " + boutiqueId));
        List<Product> products = productRepository.findByBoutiqueIdAndIsActiveTrue(boutiqueId);
        List<Category> categories = categoryRepository.findByBoutiqueIdOrderBySortOrderAsc(boutiqueId);
        String html = generateHtml(b, products, categories);
        b.setGeneratedHtml(html);
        boutiqueRepository.save(b);
        saveHtmlFile(b.getSlug(), html);
    }

    public void saveHtmlFile(String slug, String html) {
        try {
            Path dir = Paths.get(STORE_FILES_DIR, slug);
            Files.createDirectories(dir);
            Files.writeString(dir.resolve("index.html"), html);
        } catch (IOException e) {
            throw new RuntimeException("Failed to save HTML file for store: " + slug, e);
        }
    }

    public String loadHtml(String slug) {
        try {
            Path file = Paths.get(STORE_FILES_DIR, slug, "index.html");
            if (Files.exists(file)) return Files.readString(file);
        } catch (IOException ignored) {}
        Boutique b = boutiqueRepository.findBySlug(slug).orElse(null);
        if (b != null && b.getGeneratedHtml() != null) return b.getGeneratedHtml();
        return null;
    }

    public String generateHtml(Boutique b, List<Product> products, List<Category> categories) {
        String slug = b.getSlug();
        String currencySymbol = b.getCurrency() != null ? (b.getCurrency().equals("TND") ? "د.ت" : b.getCurrency().equals("EUR") ? "€" : "$") : "د.ت";
        String announcement = b.getAnnouncementText() != null ? b.getAnnouncementText() : "";
        String logoUrl = b.getLogoUrl() != null ? b.getLogoUrl() : "";
        String headerBg = b.getHeaderColor() != null ? b.getHeaderColor() : "#ededed";
        String footerBg = b.getFooterColor() != null ? b.getFooterColor() : "#dbdbdb";
        String bodyBg = b.getBodyColor() != null ? b.getBodyColor() : "#ffffff";
        String cardBg = b.getCardProductColor() != null ? b.getCardProductColor() : "#fafafa";
        String accent = b.getButtonColor() != null ? b.getButtonColor() : "#b551c2";
        String topBarBg = b.getTopBarColor() != null ? b.getTopBarColor() : "#3b0086";
        String textColor = b.getTextColor() != null ? b.getTextColor() : "#751515";
        Double deliveryFees = b.getDeliveryFees() != null ? b.getDeliveryFees() : 7.0;
        boolean cashOnDelivery = b.getCashOnDelivery() != null ? b.getCashOnDelivery() : true;
        boolean konnectActive = "active".equals(b.getKonnectStatus());
        boolean d17Active = "active".equals(b.getD17Status());
        String customCss = b.getCustomCss() != null ? b.getCustomCss() : "";
        String customJs = b.getCustomJs() != null ? b.getCustomJs() : "";

        // Language
        StoreLanguage lang = languageRepository.findByBoutiqueId(b.getId()).orElse(null);
        String addToCart = lang != null ? lang.getAddToCart() : "Ajouter au panier";
        String checkoutTitle = lang != null ? lang.getCheckoutTitle() : "Commande";
        String totalPriceLabel = lang != null ? lang.getTotalPriceLabel() : "Prix Total :";
        String shippingCostLabel = lang != null ? lang.getShippingCostLabel() : "Frais de livraison";
        String grandTotalLabel = lang != null ? lang.getGrandTotalLabel() : "Total Général";
        String fullNamePlaceholder = lang != null ? lang.getFullNamePlaceholder() : "Entrez votre nom complet";
        String emailPlaceholder = lang != null ? lang.getEmailPlaceholder() : "Entrez votre e-mail";
        String billingAddressPlaceholder = lang != null ? lang.getBillingAddressPlaceholder() : "Entrez votre adresse de livraison";
        String cityPlaceholder = lang != null ? lang.getCityPlaceholder() : "Sélectionnez votre gouvernorat";
        String phonePlaceholder = lang != null ? lang.getPhonePlaceholder() : "Entrez votre numéro de téléphone";
        String paymentMethodLabel = lang != null ? lang.getPaymentMethodLabel() : "Méthode de paiement :";
        String placeOrderButton = lang != null ? lang.getPlaceOrderButton() : "Passer la commande";
        String noProducts = lang != null ? lang.getNoProducts() : "Aucun produit disponible pour le moment.";
        String footerText = lang != null ? lang.getFooterText() : "Tous droits réservés.";
        String orderConfirmationTitle = lang != null ? lang.getOrderConfirmationTitle() : "Confirmation de commande";
        String searchPlaceholder = lang != null ? lang.getSearchProducts() : "Rechercher des produits...";
        String seeAll = lang != null ? lang.getSeeAll() : "Voir tout";
        String codLabel = lang != null ? lang.getCashOnDelivery() : "Paiement à la livraison";
        String followUsLabel = lang != null ? lang.getFollowUs() : "Suivez-nous";
        String supportLabel = lang != null ? lang.getSupport() : "Support";
        String menuLabel = lang != null ? lang.getMenuLabel() : "Menu";
        String cartTitle = lang != null ? lang.getCartTitle() : "Panier";
        String selectCountry = lang != null ? lang.getSelectCountry() : "Sélectionnez votre pays";

        // Categories HTML
        String catHtml = categories.stream().map(c ->
            "<a href=\"?menu_item_id=" + c.getId() + "\" class=\"\">" + esc(c.getName()) + "</a>"
        ).collect(Collectors.joining("\n        "));

        // Sliders
        List<StoreSlider> sliders = sliderRepository.findByBoutiqueIdOrderBySortOrderAsc(b.getId());
        String slidersHtml = sliders.stream().map(s ->
            "<div class=\"slide\"><img src=\"" + esc(s.getImageUrl()) + "\" alt=\"" + esc(b.getName()) + "\" loading=\"lazy\"></div>"
        ).collect(Collectors.joining("\n        "));

        // Countries
        List<BoutiqueCountry> countries = countryRepository.findByBoutiqueId(b.getId());
        String countriesHtml = countries.stream().map(c ->
            "<option value=\"" + esc(c.getCountryName()) + "\">" + esc(c.getCountryName()) + "</option>"
        ).collect(Collectors.joining("\n        "));

        // Products HTML
        String productsHtml;
        if (products.isEmpty()) {
            productsHtml = "<div style=\"grid-column:1/-1;text-align:center;padding:48px;color:#737373;\"><i class=\"fas fa-box-open\" style=\"font-size:3rem;opacity:0.3;display:block;margin-bottom:16px;\"></i><p>" + esc(noProducts) + "</p></div>";
        } else {
            productsHtml = products.stream().map(p -> {
                String firstImg = extractFirstImage(p.getImages());
                boolean hasCompare = p.getComparePrice() != null && p.getComparePrice().compareTo(BigDecimal.ZERO) > 0;
                String price = hasCompare ?
                    "<p class=\"price\"><old>" + currencySymbol + String.format("%.2f", p.getComparePrice()) + "</old> " + currencySymbol + String.format("%.2f", p.getPrice()) + "</p>" :
                    "<p class=\"price\">" + currencySymbol + String.format("%.2f", p.getPrice()) + "</p>";
                String badge = hasCompare ? "<div class=\"product-badges\"><span class=\"badge badge-sale\">Promo</span></div>" : "";
                return "<article class=\"product-card\" data-product-id=\"" + p.getId() + "\">" +
                    "<a href=\"?product_id=" + p.getId() + "\" class=\"product-card-link\" style=\"text-decoration:none;color:inherit;display:block;\">" +
                    "<div class=\"image-wrap\">" + badge +
                    "<div class=\"quick-actions\"><button type=\"button\" class=\"quick-btn wishlist-toggle\" onclick=\"event.preventDefault();event.stopPropagation();toggleFavorite('" + p.getId() + "');\">" +
                    "<i class=\"far fa-heart\"></i><i class=\"fas fa-heart\" style=\"display:none;\"></i></button></div>" +
                    "<img src=\"" + esc(firstImg) + "\" alt=\"" + esc(p.getName()) + "\" loading=\"lazy\" onerror=\"this.src='https://via.placeholder.com/400x400?text=Image'\">" +
                    "</div><div class=\"info\"><h3 class=\"name\">" + esc(p.getName()) + "</h3>" +
                    "<div class=\"price-wrap\">" + price + "</div>" +
                    "<span class=\"add-cart\" style=\"background:" + accent + ";\"><i class=\"fas fa-cart-plus\"></i> " + esc(addToCart) + "</span>" +
                    "</div></a></article>";
            }).collect(Collectors.joining("\n        "));
        }

        boolean hasSliders = !sliders.isEmpty();
        String sliderSection = hasSliders ? 
            "<section class=\"slider-section\"><div class=\"slider-container\"><div class=\"slider-track\" id=\"sliderTrack\">" + slidersHtml +
            "</div><div class=\"slider-nav\"><button id=\"prevSlide\"><i class=\"fas fa-chevron-left\"></i></button><button id=\"nextSlide\"><i class=\"fas fa-chevron-right\"></i></button></div>" +
            "<div class=\"slider-dots\" id=\"sliderDots\"></div></div></section>" : "";

        String navCatHtml = catHtml.isEmpty() ? "" : catHtml;

        String paymentIcons = "";
        if (cashOnDelivery) paymentIcons += "<i class=\"fas fa-money-bill-wave\" title=\"COD\"></i>";
        if (konnectActive) paymentIcons += "<i class=\"fas fa-credit-card\" title=\"Konnect\"></i>";
        if (d17Active) paymentIcons += "<i class=\"fas fa-mobile-alt\" title=\"D17\"></i>";

        String codOption = cashOnDelivery ? "<option value=\"cash-on-delivery\">" + esc(codLabel) + "</option>" : "";
        String konnectOption = konnectActive ? "<option value=\"konnect\">Paiement par carte (Konnect)</option>" : "";
        String d17Option = d17Active ? "<option value=\"d17\">D17</option>" : "";

        boolean simpleCheckout = b.getSimpleCheckout() != null && b.getSimpleCheckout();

        return "<!DOCTYPE html>\n" +
        "<html lang=\"fr\">\n<head>\n" +
        "<meta charset=\"UTF-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" +
        "<title>" + esc(b.getName()) + " | Boutique en ligne</title>\n" +
        "<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.2/css/all.min.css\">\n" +
        "<link href=\"https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&display=swap\" rel=\"stylesheet\">\n" +
        "<style>\n" +
        ":root{--bg:" + bodyBg + ";--white:#ffffff;--text:" + textColor + ";--text-soft:#444444;--muted:#737373;" +
        "--accent:" + accent + ";--header-bg:" + headerBg + ";--footer-bg:" + footerBg + ";--card-bg:" + cardBg + ";--top-bar-bg:" + topBarBg + ";" +
        "--border:#e5e5e5;--radius:12px;--radius-sm:8px;--radius-full:9999px;--shadow:0 4px 6px -1px rgba(0,0,0,0.06);" +
        "--shadow-lg:0 10px 40px -10px rgba(0,0,0,0.1);--font:'DM Sans',-apple-system,sans-serif;--transition:0.25s cubic-bezier(0.4,0,0.2,1)}\n" +
        "*{margin:0;padding:0;box-sizing:border-box}\n" +
        "body{font-family:var(--font);background:var(--bg);color:var(--text);-webkit-font-smoothing:antialiased;line-height:1.6}\n" +
        "a{color:inherit;text-decoration:none}\n" +
        "img{max-width:100%;display:block}\n" +
        ".announcement{background:var(--top-bar-bg);color:#fff;text-align:center;padding:8px 16px;font-size:0.8125rem;font-weight:500;letter-spacing:0.3px}\n" +
        ".header{background:var(--header-bg);position:sticky;top:0;z-index:100;box-shadow:var(--shadow)}\n" +
        ".header-inner{max-width:var(--max-width,1280px);margin:0 auto;display:flex;align-items:center;justify-content:space-between;padding:0 20px;height:64px}\n" +
        ".logo a{display:flex;align-items:center;gap:10px;font-weight:700;font-size:1.125rem}\n" +
        ".logo img{height:36px;width:auto}\n" +
        ".nav{display:flex;gap:24px}\n" +
        ".nav a{font-size:0.9375rem;font-weight:500;padding:4px 0;border-bottom:2px solid transparent;transition:var(--transition)}\n" +
        ".nav a:hover,.nav a.active{border-bottom-color:var(--accent);color:var(--accent)}\n" +
        ".header-actions{display:flex;gap:12px;align-items:center}\n" +
        ".header-actions button{background:none;border:none;cursor:pointer;position:relative;padding:8px;font-size:1.2rem;color:var(--text);border-radius:var(--radius-sm);transition:var(--transition)}\n" +
        ".header-actions button:hover{background:rgba(0,0,0,0.05)}\n" +
        ".cart-count,.wishlist-count{position:absolute;top:0;right:0;background:var(--accent);color:#fff;font-size:0.625rem;min-width:18px;height:18px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:600;padding:0 4px}\n" +
        ".slider-section{overflow:hidden}\n" +
        ".slider-container{position:relative;max-width:1200px;margin:0 auto}\n" +
        ".slider-track{display:flex;transition:transform 0.6s cubic-bezier(0.4,0,0.2,1);will-change:transform}\n" +
        ".slide{min-width:100%;position:relative}\n" +
        ".slide img{width:100%;height:420px;object-fit:cover}\n" +
        ".slide-caption{position:absolute;bottom:40px;left:40px;color:#fff;text-shadow:0 2px 8px rgba(0,0,0,0.3)}\n" +
        ".slide-caption h2{font-size:2rem;margin-bottom:8px}\n" +
        ".slide-caption p{font-size:1rem;opacity:0.9}\n" +
        ".slider-nav{position:absolute;top:50%;width:100%;display:flex;justify-content:space-between;transform:translateY(-50%);padding:0 16px;pointer-events:none}\n" +
        ".slider-nav button{pointer-events:auto;background:rgba(255,255,255,0.9);border:none;width:40px;height:40px;border-radius:50%;cursor:pointer;font-size:1rem;box-shadow:var(--shadow);transition:var(--transition)}\n" +
        ".slider-nav button:hover{background:#fff;transform:scale(1.05)}\n" +
        ".slider-dots{display:flex;justify-content:center;gap:8px;padding:12px 0}\n" +
        ".slider-dots span{width:8px;height:8px;border-radius:50%;background:#ccc;cursor:pointer;transition:var(--transition)}\n" +
        ".slider-dots span.active{background:var(--accent);width:24px;border-radius:4px}\n" +
        ".trust-strip{background:var(--bg-alt,#f5f5f5);border-top:1px solid var(--border);border-bottom:1px solid var(--border)}\n" +
        ".trust-inner{max-width:var(--max-width,1280px);margin:0 auto;display:flex;justify-content:center;gap:48px;padding:16px 20px}\n" +
        ".trust-item{display:flex;align-items:center;gap:8px;font-size:0.875rem;color:var(--text-soft);font-weight:500}\n" +
        ".trust-item i{color:var(--accent);font-size:1.1rem}\n" +
        ".main{max-width:var(--max-width,1280px);margin:0 auto;padding:40px 20px}\n" +
        ".section-head{text-align:center;margin-bottom:32px}\n" +
        ".section-title{font-size:1.75rem;font-weight:700}\n" +
        ".section-subtitle{color:var(--muted);margin-top:6px;font-size:0.9375rem}\n" +
        ".products-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:20px}\n" +
        ".product-card{background:var(--card-bg);border-radius:var(--radius);overflow:hidden;transition:var(--transition);border:1px solid var(--border)}\n" +
        ".product-card:hover{transform:translateY(-4px);box-shadow:var(--shadow-lg)}\n" +
        ".image-wrap{position:relative;overflow:hidden;aspect-ratio:1/1;background:#f0f0f0}\n" +
        ".image-wrap img{width:100%;height:100%;object-fit:cover;transition:var(--transition)}\n" +
        ".product-card:hover .image-wrap img{transform:scale(1.05)}\n" +
        ".product-badges{position:absolute;top:8px;left:8px;z-index:2}\n" +
        ".badge{padding:4px 10px;border-radius:var(--radius-full);font-size:0.6875rem;font-weight:600;text-transform:uppercase}\n" +
        ".badge-sale{background:#ef4444;color:#fff}\n" +
        ".quick-actions{position:absolute;top:8px;right:8px;z-index:2;display:flex;flex-direction:column;gap:6px;opacity:0;transition:var(--transition)}\n" +
        ".product-card:hover .quick-actions{opacity:1}\n" +
        ".quick-btn{width:32px;height:32px;border-radius:50%;background:#fff;border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:0.875rem;box-shadow:var(--shadow);transition:var(--transition);color:var(--text)}\n" +
        ".quick-btn:hover{background:var(--accent);color:#fff}\n" +
        ".info{padding:16px}\n" +
        ".name{font-size:0.9375rem;font-weight:600;margin-bottom:8px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}\n" +
        ".price-wrap{margin-bottom:12px}\n" +
        ".price{font-size:1.125rem;font-weight:700;color:var(--accent)}\n" +
        ".price old{font-size:0.8125rem;color:var(--muted);text-decoration:line-through;margin-right:6px;font-weight:400}\n" +
        ".add-cart{display:inline-flex;align-items:center;gap:6px;color:#fff;padding:8px 16px;border-radius:var(--radius-full);font-size:0.8125rem;font-weight:600;cursor:pointer;transition:var(--transition);border:none}\n" +
        ".add-cart:hover{filter:brightness(1.1)}\n" +
        ".newsletter-section{background:var(--bg-alt,#f5f5f5);padding:60px 20px;text-align:center}\n" +
        ".newsletter-inner{max-width:480px;margin:0 auto}\n" +
        ".newsletter-inner h3{font-size:1.5rem;margin-bottom:8px}\n" +
        ".newsletter-inner p{color:var(--muted);margin-bottom:20px;font-size:0.9375rem}\n" +
        ".newsletter-form{display:flex;gap:8px}\n" +
        ".newsletter-form input{flex:1;padding:12px 16px;border:1px solid var(--border);border-radius:var(--radius-full);font-family:var(--font);font-size:0.9375rem;outline:none}\n" +
        ".newsletter-form input:focus{border-color:var(--accent)}\n" +
        ".newsletter-form button{padding:12px 24px;background:var(--accent);color:#fff;border:none;border-radius:var(--radius-full);font-weight:600;cursor:pointer;transition:var(--transition)}\n" +
        ".newsletter-form button:hover{filter:brightness(1.1)}\n" +
        ".footer{background:var(--footer-bg);padding:48px 20px 0}\n" +
        ".footer-inner{max-width:var(--max-width,1280px);margin:0 auto}\n" +
        ".footer-top{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:40px;padding-bottom:32px}\n" +
        ".footer-brand .logo{margin-bottom:12px}\n" +
        ".footer-brand p{color:var(--text-soft);font-size:0.875rem;line-height:1.7}\n" +
        ".footer-col h4{font-size:0.9375rem;font-weight:600;margin-bottom:16px}\n" +
        ".footer-col ul{list-style:none;padding:0}\n" +
        ".footer-col ul li{margin-bottom:10px}\n" +
        ".footer-col ul a{font-size:0.875rem;color:var(--text-soft);transition:var(--transition);display:flex;align-items:center;gap:6px}\n" +
        ".footer-col ul a:hover{color:var(--accent)}\n" +
        ".footer-payments{display:flex;align-items:center;justify-content:center;gap:12px;padding:16px 0;border-top:1px solid var(--border);font-size:0.8125rem;color:var(--muted)}\n" +
        ".footer-payments .icons{display:flex;gap:12px;font-size:1.5rem;color:var(--text-soft)}\n" +
        ".footer-bottom{display:flex;justify-content:space-between;padding:16px 0;border-top:1px solid var(--border);font-size:0.8125rem;color:var(--muted)}\n" +
        ".footer-bottom a{color:var(--accent)}\n" +
        ".t2-cart-drawer{position:fixed;top:0;right:-420px;width:420px;max-width:100vw;height:100%;background:#fff;z-index:1000;box-shadow:-4px 0 40px rgba(0,0,0,0.1);transition:right 0.35s cubic-bezier(0.4,0,0.2,1);display:flex;flex-direction:column;overflow:hidden}\n" +
        ".t2-cart-drawer.open{right:0}\n" +
        ".t2-cart-drawer__header{display:flex;justify-content:space-between;align-items:center;padding:20px 24px;border-bottom:1px solid var(--border)}\n" +
        ".t2-cart-drawer__title{font-size:1.25rem;font-weight:600}\n" +
        ".t2-cart-drawer__close{background:none;border:none;cursor:pointer;padding:4px;color:var(--text);border-radius:6px;transition:var(--transition)}\n" +
        ".t2-cart-drawer__close:hover{background:#f0f0f0}\n" +
        ".t2-cart-drawer__body{flex:1;overflow-y:auto;padding:20px 24px}\n" +
        ".t2-cart-item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid var(--border-light,#f0f0f0)}\n" +
        ".t2-cart-item img{width:64px;height:64px;object-fit:cover;border-radius:var(--radius-sm)}\n" +
        ".t2-cart-item__info{flex:1}\n" +
        ".t2-cart-item__name{font-weight:500;font-size:0.875rem}\n" +
        ".t2-cart-item__price{color:var(--accent);font-weight:600;font-size:0.875rem;margin-top:4px}\n" +
        ".t2-cart-item__qty{display:flex;align-items:center;gap:8px;margin-top:6px}\n" +
        ".t2-cart-item__qty button{width:26px;height:26px;border-radius:50%;border:1px solid var(--border);background:none;cursor:pointer;font-size:0.75rem;transition:var(--transition)}\n" +
        ".t2-cart-item__qty button:hover{background:var(--accent);color:#fff;border-color:var(--accent)}\n" +
        ".t2-cart-item__remove{background:none;border:none;cursor:pointer;color:var(--muted);padding:4px;font-size:0.875rem;transition:var(--transition)}\n" +
        ".t2-cart-item__remove:hover{color:#ef4444}\n" +
        ".t2-cart-drawer__totals{padding:16px 0;border-top:1px solid var(--border);margin-top:12px}\n" +
        ".t2-cart-drawer__row{display:flex;justify-content:space-between;padding:4px 0;font-size:0.875rem}\n" +
        ".t2-cart-drawer__row--total{font-weight:700;font-size:1rem;padding-top:8px;border-top:1px solid var(--border);margin-top:8px}\n" +
        ".t2-cart-drawer__form{display:flex;flex-direction:column;gap:10px;margin-top:12px}\n" +
        ".t2-cart-drawer__input{padding:10px 12px;border:1px solid var(--border);border-radius:var(--radius-sm);font-family:var(--font);font-size:0.875rem;outline:none;width:100%}\n" +
        ".t2-cart-drawer__input:focus{border-color:var(--accent)}\n" +
        ".t2-cart-drawer__submit{padding:14px;background:var(--accent);color:#fff;border:none;border-radius:var(--radius-sm);font-weight:600;cursor:pointer;font-size:0.9375rem;transition:var(--transition)}\n" +
        ".t2-cart-drawer__submit:hover{filter:brightness(1.1)}\n" +
        ".t2-cart-drawer__overlay{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.4);z-index:999;opacity:0;pointer-events:none;transition:opacity 0.35s ease}\n" +
        ".t2-cart-drawer__overlay.show{opacity:1;pointer-events:auto}\n" +
        ".wishlist-sidebar{position:fixed;top:0;right:-420px;width:420px;max-width:100vw;height:100%;background:#fff;z-index:1000;box-shadow:-4px 0 40px rgba(0,0,0,0.1);transition:right 0.35s cubic-bezier(0.4,0,0.2,1);display:flex;flex-direction:column;overflow:hidden}\n" +
        ".wishlist-sidebar.open{right:0}\n" +
        ".custom-modal{position:fixed;top:0;left:0;width:100%;height:100%;z-index:2000;display:none;align-items:center;justify-content:center}\n" +
        ".custom-modal.open{display:flex}\n" +
        ".custom-modal::before{content:'';position:absolute;width:100%;height:100%;background:rgba(0,0,0,0.4)}\n" +
        ".custom-modal-content{background:#fff;border-radius:var(--radius);padding:32px;max-width:440px;width:90%;position:relative;box-shadow:var(--shadow-lg);text-align:center}\n" +
        ".modal-header{margin-bottom:20px}\n" +
        ".modal-header .success-icon{width:48px;height:48px;border-radius:50%;background:#ecfdf5;color:#16a34a;display:flex;align-items:center;justify-content:center;margin:0 auto 12px}\n" +
        ".modal-header h2{font-size:1.25rem;font-weight:600}\n" +
        ".order-summary{text-align:left;margin:16px 0}\n" +
        ".order-item{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border-light,#f0f0f0);font-size:0.875rem}\n" +
        ".order-label{color:var(--muted)}\n" +
        ".order-value{font-weight:500}\n" +
        ".modal-footer{margin-top:20px}\n" +
        ".close-modal-btn{padding:10px 24px;background:var(--accent);color:#fff;border:none;border-radius:var(--radius-sm);font-weight:600;cursor:pointer;font-size:0.875rem}\n" +
        "@media(max-width:768px){.nav{display:none}.footer-top{grid-template-columns:1fr}.products-grid{grid-template-columns:repeat(auto-fill,minmax(160px,1fr))}.slide img{height:240px}.trust-inner{gap:24px;flex-wrap:wrap;justify-content:center}.t2-cart-drawer{width:100vw;right:-100vw}}\n" +
        customCss + "\n</style>\n</head>\n<body>\n" +

        "<div class=\"announcement\">" + esc(announcement) + "</div>\n" +

        "<header class=\"header\"><div class=\"header-inner\">" +
        "<div class=\"logo\"><a href=\"./\"><img src=\"" + esc(logoUrl) + "\" alt=\"" + esc(b.getName()) + "\"><span>" + esc(b.getName()) + "</span></a></div>" +
        "<nav class=\"nav\"><a href=\"./\" class=\"active\">" + esc(seeAll) + "</a>" + navCatHtml + "</nav>" +
        "<div class=\"header-actions\"><button class=\"wishlist-btn\" id=\"wishlistNavBtn\"><i class=\"far fa-heart\"></i><span class=\"wishlist-count\" id=\"wishlistBadge\"></span></button>" +
        "<button class=\"cart-btn\" onclick=\"toggleCartSidebar()\"><i class=\"fas fa-shopping-bag\"></i><span class=\"cart-count\" id=\"cartCount\">0</span></button></div>" +
        "</div></header>\n" +

        sliderSection +
        "<div class=\"trust-strip\"><div class=\"trust-inner\">" +
        "<div class=\"trust-item\"><i class=\"fas fa-truck-fast\"></i> Livraison 24-48h</div>" +
        "<div class=\"trust-item\"><i class=\"fas fa-shield-halved\"></i> Paiement sécurisé</div>" +
        "<div class=\"trust-item\"><i class=\"fas fa-headset\"></i> Service client 7j/7</div></div></div>\n" +

        "<main class=\"main\">" +
        "<div class=\"section-head\"><h2 class=\"section-title\">Nos produits</h2><p class=\"section-subtitle\">" + esc(b.getName()) + " – Qualité et livraison rapide.</p></div>" +
        "<div style=\"margin-bottom:24px;\"><input type=\"text\" id=\"search-input\" placeholder=\"" + esc(searchPlaceholder) + "\" style=\"width:100%;padding:12px 16px;border:1px solid var(--border);border-radius:var(--radius-full);font-family:var(--font);font-size:0.9375rem;\"></div>" +
        "<div class=\"products-grid\" id=\"productsGrid\">" + productsHtml + "</div></main>\n" +

        "<section class=\"newsletter-section\"><div class=\"newsletter-inner\">" +
        "<h3>Restez informé</h3><p>Inscrivez-vous pour recevoir nos nouveautés et offres exclusives.</p>" +
        "<form class=\"newsletter-form\" action=\"/api/public/subscribe\" method=\"POST\">" +
        "<input type=\"hidden\" name=\"boutique_id\" value=\"" + b.getId() + "\">" +
        "<input type=\"email\" name=\"email\" placeholder=\"Votre adresse email\" required>" +
        "<button type=\"submit\">S'inscrire</button></form></div></section>\n" +

        "<footer class=\"footer\"><div class=\"footer-inner\">" +
        "<div class=\"footer-top\">" +
        "<div class=\"footer-brand\"><div class=\"logo\"><a href=\"./\"><img src=\"" + esc(logoUrl) + "\" alt=\"" + esc(b.getName()) + "\"><span>" + esc(b.getName()) + "</span></a></div><p>" + esc(b.getDescription()) + "</p></div>" +
        "<div class=\"footer-col\"><h4>" + esc(menuLabel) + "</h4><ul><li><a href=\"./\">" + esc(seeAll) + "</a></li>" + navCatHtml.replaceAll("?menu_item_id=", "?menu_item_id=").replaceAll("</a>", "</a></li>") + "</ul></div>" +
        "<div class=\"footer-col\"><h4>" + esc(supportLabel) + "</h4><ul>" +
        (b.getWhatsappNumber() != null && !b.getWhatsappNumber().isEmpty() ? "<li><a href=\"https://wa.me/" + b.getWhatsappNumber() + "\"><i class=\"fab fa-whatsapp\"></i> WhatsApp</a></li>" : "") +
        "</ul></div>" +
        "<div class=\"footer-col\"><h4>" + esc(followUsLabel) + "</h4><ul>" +
        (b.getFacebookUrl() != null && !b.getFacebookUrl().isEmpty() ? "<li><a href=\"" + esc(b.getFacebookUrl()) + "\" target=\"_blank\"><i class=\"fab fa-facebook\"></i> Facebook</a></li>" : "") +
        (b.getInstagramUrl() != null && !b.getInstagramUrl().isEmpty() ? "<li><a href=\"" + esc(b.getInstagramUrl()) + "\" target=\"_blank\"><i class=\"fab fa-instagram\"></i> Instagram</a></li>" : "") +
        (b.getTiktokUrl() != null && !b.getTiktokUrl().isEmpty() ? "<li><a href=\"" + esc(b.getTiktokUrl()) + "\" target=\"_blank\"><i class=\"fab fa-tiktok\"></i> TikTok</a></li>" : "") +
        "</ul></div></div>" +
        "<div class=\"footer-payments\"><span>Paiement sécurisé</span><div class=\"icons\">" + paymentIcons + "</div></div>" +
        "<div class=\"footer-bottom\"><span>&copy; " + Year.now() + " " + esc(b.getName()) + ". " + esc(footerText) + "</span><span>Créé par <a href=\"https://makewebsite.io\" target=\"_blank\">MakeWebsite.io</a></span></div>" +
        "</div></footer>\n" +

        // Cart overlay + drawer
        "<div class=\"t2-cart-drawer__overlay\" id=\"cartOverlay\" onclick=\"toggleCartSidebar()\"></div>\n" +
        "<div id=\"cartSidebar\" class=\"t2-cart-drawer\">" +
        "<div class=\"t2-cart-drawer__header\"><h2 class=\"t2-cart-drawer__title\">" + esc(cartTitle) + "</h2>" +
        "<button id=\"closeCartSidebar\" class=\"t2-cart-drawer__close\" onclick=\"toggleCartSidebar()\"><svg width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M18 6L6 18M6 6l12 12\"/></svg></button></div>" +
        "<div class=\"t2-cart-drawer__body\">" +
        "<div id=\"cartItems\"></div>" +
        "<div class=\"t2-cart-drawer__totals\">" +
        "<div class=\"t2-cart-drawer__row\"><span>" + esc(totalPriceLabel) + "</span><span id=\"total-price\">" + currencySymbol + "0.00</span></div>" +
        "<div class=\"t2-cart-drawer__row\"><span>" + esc(shippingCostLabel) + "</span><span id=\"shipping-cost\">" + currencySymbol + String.format("%.2f", deliveryFees) + "</span></div>" +
        "<div class=\"t2-cart-drawer__row t2-cart-drawer__row--total\"><span>" + esc(grandTotalLabel) + "</span><span id=\"grand-total\">" + currencySymbol + "0.00</span></div></div>" +
        "<form id=\"checkout-form\" class=\"t2-cart-drawer__form\" onsubmit=\"return submitOrder(event)\">" +
        "<input type=\"text\" name=\"full-name\" placeholder=\"" + esc(fullNamePlaceholder) + "\" required class=\"t2-cart-drawer__input\">" +
        "<input type=\"text\" name=\"billing-address\" placeholder=\"" + esc(billingAddressPlaceholder) + "\" required class=\"t2-cart-drawer__input\">" +
        "<select name=\"city\" required class=\"t2-cart-drawer__input\"><option value=\"\">" + esc(cityPlaceholder) + "</option>" +
        "<option value=\"Ariana\">Ariana</option><option value=\"Béja\">Béja</option><option value=\"Ben Arous\">Ben Arous</option>" +
        "<option value=\"Bizerte\">Bizerte</option><option value=\"Gabès\">Gabès</option><option value=\"Gafsa\">Gafsa</option>" +
        "<option value=\"Jendouba\">Jendouba</option><option value=\"Kairouan\">Kairouan</option><option value=\"Kasserine\">Kasserine</option>" +
        "<option value=\"Kébili\">Kébili</option><option value=\"Le Kef\">Le Kef</option><option value=\"Mahdia\">Mahdia</option>" +
        "<option value=\"La Manouba\">La Manouba</option><option value=\"Médenine\">Médenine</option><option value=\"Monastir\">Monastir</option>" +
        "<option value=\"Nabeul\">Nabeul</option><option value=\"Sfax\">Sfax</option><option value=\"Sidi Bouzid\">Sidi Bouzid</option>" +
        "<option value=\"Siliana\">Siliana</option><option value=\"Sousse\">Sousse</option><option value=\"Tataouine\">Tataouine</option>" +
        "<option value=\"Tozeur\">Tozeur</option><option value=\"Tunis\">Tunis</option><option value=\"Zaghouan\">Zaghouan</option>" +
        "</select>" +
        (simpleCheckout ? "" :
        "<input type=\"email\" name=\"email\" placeholder=\"" + esc(emailPlaceholder) + "\" class=\"t2-cart-drawer__input\">" +
        "<select name=\"country\" class=\"t2-cart-drawer__input\"><option value=\"\">" + esc(selectCountry) + "</option>" + countriesHtml + "</select>") +
        "<input type=\"tel\" name=\"phone_number\" placeholder=\"" + esc(phonePlaceholder) + "\" required class=\"t2-cart-drawer__input\">" +
        "<div><label>" + esc(paymentMethodLabel) + "</label>" +
        "<select name=\"payment-method\" required class=\"t2-cart-drawer__input\">" + codOption + konnectOption + d17Option + "</select></div>" +
        "<button type=\"submit\" class=\"t2-cart-drawer__submit\" style=\"background:" + accent + ";\">" + esc(placeOrderButton) + "</button>" +
        "</form></div></div>\n" +

        // Order confirmation modal
        "<div id=\"customOrderConfirmationModal\" class=\"custom-modal\">" +
        "<div class=\"custom-modal-content\">" +
        "<div class=\"modal-header\"><div class=\"success-icon\"><svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\"><path d=\"M9 12L11 14L15 10M21 12C21 16.97 16.97 21 12 21C7.03 21 3 16.97 3 12C3 7.03 7.03 3 12 3C16.97 3 21 7.03 21 12Z\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg></div>" +
        "<h2>" + esc(orderConfirmationTitle) + "</h2></div>" +
        "<div class=\"order-summary\">" +
        "<div class=\"order-item\"><div class=\"order-label\">Nom complet :</div><div class=\"order-value\" id=\"customUserFullName\"></div></div>" +
        "<div class=\"order-item\"><div class=\"order-label\">Adresse :</div><div class=\"order-value\" id=\"customUserBillingAddress\"></div></div>" +
        "<div class=\"order-item\"><div class=\"order-label\">Ville</div><div class=\"order-value\" id=\"customUserCity\"></div></div>" +
        "<div class=\"order-item\"><div class=\"order-label\">Téléphone</div><div class=\"order-value\" id=\"customUserPhoneNumber\"></div></div>" +
        "<div class=\"order-item\"><div class=\"order-label\">Méthode de paiement :</div><div class=\"order-value\" id=\"customUserPaymentMethod\"></div></div></div>" +
        "<div class=\"modal-footer\"><button class=\"close-modal-btn\" onclick=\"document.getElementById('customOrderConfirmationModal').classList.remove('open')\">Fermer</button></div></div></div>\n" +

        customJs + "\n" +
        "<script>\n" +
        "const API_BASE='';const CURRENCY_SYMBOL='" + currencySymbol + "';const DELIVERY_FEES=" + deliveryFees + ";\n" +
        "let cart=JSON.parse(localStorage.getItem('cart')||'[]');let wishlist=JSON.parse(localStorage.getItem('wishlist')||'[]');\n" +
        "function saveCart(){localStorage.setItem('cart',JSON.stringify(cart));updateCartUI()}\n" +
        "function toggleCartSidebar(){document.getElementById('cartSidebar').classList.toggle('open');document.getElementById('cartOverlay').classList.toggle('show')}\n" +
        "function addToCart(id,name,price,img){const existing=cart.find(i=>i.id===id);if(existing)existing.qty+=1;else cart.push({id,name,price,img,qty:1});saveCart()}\n" +
        "function removeFromCart(id){cart=cart.filter(i=>i.id!==id);saveCart()}\n" +
        "function changeQty(id,delta){const item=cart.find(i=>i.id===id);if(item){item.qty=Math.max(1,item.qty+delta);saveCart()}}\n" +
        "function updateCartUI(){const count=cart.reduce((s,i)=>s+i.qty,0);document.getElementById('cartCount').textContent=count;" +
        "const container=document.getElementById('cartItems');if(!cart.length){container.innerHTML='<div style=\"text-align:center;padding:40px;color:var(--muted)\"><i class=\"fas fa-shopping-bag\" style=\"font-size:2.5rem;opacity:0.3;display:block;margin-bottom:12px\"></i><p>Votre panier est vide</p></div>';" +
        "document.getElementById('total-price').textContent=CURRENCY_SYMBOL+'0.00';document.getElementById('grand-total').textContent=CURRENCY_SYMBOL+'0.00';return}" +
        "let html='';let sub=0;cart.forEach(i=>{sub+=i.price*i.qty;html+='<div class=\"t2-cart-item\">" +
        "<img src=\"'+i.img+'\" alt=\"'+i.name+'\"><div class=\"t2-cart-item__info\">" +
        "<div class=\"t2-cart-item__name\">'+i.name+'</div><div class=\"t2-cart-item__price\">'+CURRENCY_SYMBOL+(i.price*i.qty).toFixed(2)+'</div>" +
        "<div class=\"t2-cart-item__qty\"><button onclick=\"changeQty(\\''+i.id+'\\',-1)\">-</button><span>'+i.qty+'</span><button onclick=\"changeQty(\\''+i.id+'\\',1)\">+</button></div></div>" +
        "<button class=\"t2-cart-item__remove\" onclick=\"removeFromCart(\\''+i.id+'\\')\"><i class=\"fas fa-trash-alt\"></i></button></div>'});" +
        "container.innerHTML=html;const total=sub+DELIVERY_FEES;document.getElementById('total-price').textContent=CURRENCY_SYMBOL+sub.toFixed(2);" +
        "document.getElementById('grand-total').textContent=CURRENCY_SYMBOL+total.toFixed(2)}\n" +
        "function toggleFavorite(id){const idx=wishlist.indexOf(id);if(idx>-1)wishlist.splice(idx,1);else wishlist.push(id);localStorage.setItem('wishlist',JSON.stringify(wishlist));updateWishlistUI()}\n" +
        "function updateWishlistUI(){document.getElementById('wishlistBadge').textContent=wishlist.length||''}\n" +
        "function submitOrder(e){e.preventDefault();const f=e.target;const order={boutiqueId:'"+b.getId()+"',fullName:f['full-name'].value,email:(f['email']?f['email'].value:''),phone:f['phone_number'].value," +
        "billingAddress:f['billing-address'].value,city:f['city'].value,country:(f['country']?f['country'].value:''),paymentMethod:f['payment-method'].value," +
        "items:cart.map(i=>({productId:i.id,quantity:i.qty,unitPrice:i.price}))};\n" +
        "fetch('/api/public/store/"+slug+"/orders',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(order)}).then(r=>r.json()).then(d=>{" +
        "if(d.success){document.getElementById('customUserFullName').textContent=order.fullName;document.getElementById('customUserBillingAddress').textContent=order.billingAddress;" +
        "document.getElementById('customUserCity').textContent=order.city;document.getElementById('customUserPhoneNumber').textContent=order.phone;" +
        "document.getElementById('customUserPaymentMethod').textContent=order.paymentMethod;" +
        "document.getElementById('customOrderConfirmationModal').classList.add('open');cart=[];saveCart();toggleCartSidebar()}" +
        "else{alert('Erreur: '+d.message)}}).catch(e=>alert('Erreur réseau'));;return false}\n" +
        "document.addEventListener('DOMContentLoaded',function(){updateCartUI();updateWishlistUI()});\n" +

        // Slider autoplay
        "!function(){var t=document.getElementById('sliderTrack');if(!t)return;var s=t.children,n=0;" +
        "function go(i){n=(i+s.length)%s.length;t.style.transform='translateX(-'+(n*100)+'%)';" +
        "var d=document.getElementById('sliderDots');if(d)Array.from(d.children).forEach(function(e,j){e.classList.toggle('active',j===n)})}" +
        "var prev=document.getElementById('prevSlide'),next=document.getElementById('nextSlide');" +
        "if(prev)prev.onclick=function(){go(n-1)};if(next)next.onclick=function(){go(n+1)};" +
        "var dots=document.getElementById('sliderDots');if(dots&&s.length>1){for(var i=0;i<s.length;i++){var dot=document.createElement('span');dot.onclick=function(j){return function(){go(j)}}(i);dots.appendChild(dot)}dots.children[0].classList.add('active')}" +
        "if(s.length>1)setInterval(function(){go(n+1)},5000)}();\n" +

        // Search
        "document.getElementById('search-input')&&document.getElementById('search-input').addEventListener('input',function(){" +
        "var q=this.value.toLowerCase();document.querySelectorAll('.product-card').forEach(function(c){" +
        "var n=c.querySelector('.name');if(n)c.style.display=n.textContent.toLowerCase().includes(q)?'':'none'})});\n" +
        "</script>\n</body>\n</html>";
    }

    private String extractFirstImage(String images) {
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

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }
}
