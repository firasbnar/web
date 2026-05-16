package io.makewebsite.service;

import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.BoutiqueCountry;
import io.makewebsite.repository.BoutiqueCountryRepository;
import io.makewebsite.repository.BoutiqueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.Currency;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class StoreSettingsService {
    private static final Pattern HEX_COLOR = Pattern.compile("^#[0-9A-Fa-f]{6}$");
    private static final Set<String> SUPPORTED_CURRENCIES = Set.of(
            "TND", "EUR", "USD", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY",
            "MAD", "DZD", "LYD", "EGP", "SAR", "AED", "QAR", "OMR", "BHD", "KWD"
    );
    private static final Set<String> SUPPORTED_FONTS = Set.of(
            "Inter", "Poppins", "Roboto", "Playfair Display", "Montserrat"
    );

    private final BoutiqueRepository boutiqueRepository;
    private final BoutiqueCountryRepository countryRepository;
    private final StoreGeneratorService storeGeneratorService;
    private final UploadService uploadService;

    @Transactional(readOnly = true)
    public List<String> getAcceptedCountries(UUID storeId, UUID userId) {
        requireOwnedStore(storeId, userId);
        return countryRepository.findByBoutiqueId(storeId).stream()
                .map(BoutiqueCountry::getCountryCode)
                .sorted()
                .toList();
    }

    @Transactional
    public List<String> replaceAcceptedCountries(UUID storeId, UUID userId, List<String> rawCodes) {
        Boutique boutique = requireOwnedStore(storeId, userId);
        List<String> codes = normalizeCountryCodes(rawCodes);

        countryRepository.deleteByBoutiqueId(storeId);
        countryRepository.flush();
        List<BoutiqueCountry> countries = codes.stream()
                .map(code -> BoutiqueCountry.builder()
                        .boutique(boutique)
                        .countryCode(code)
                        .countryName(getCountryName(code))
                        .build())
                .toList();
        countryRepository.saveAll(countries);
        storeGeneratorService.regenerate(storeId);
        return codes;
    }

    @Transactional
    public Map<String, Object> updateBranding(UUID storeId, UUID userId, Map<String, ?> body) {
        Boutique boutique = requireOwnedStore(storeId, userId);

        setHexColor(body, "primaryColor", boutique::setPrimaryColor);
        setHexColor(body, "secondaryColor", boutique::setSecondaryColor);
        setHexColor(body, "headerColor", boutique::setHeaderColor);
        setHexColor(body, "footerColor", boutique::setFooterColor);
        setHexColor(body, "bodyColor", boutique::setBodyColor);
        setHexColor(body, "cardProductColor", boutique::setCardProductColor);
        setHexColor(body, "buttonColor", boutique::setButtonColor);
        setHexColor(body, "topBarColor", boutique::setTopBarColor);
        setHexColor(body, "textColor", boutique::setTextColor);

        if (body.containsKey("fontFamily")) {
            String fontFamily = asString(body.get("fontFamily"));
            if (!SUPPORTED_FONTS.contains(fontFamily)) {
                throw new IllegalArgumentException("Police non supportee");
            }
            boutique.setFontFamily(fontFamily);
        }
        if (body.containsKey("darkMode")) {
            boutique.setDarkMode(asBoolean(body.get("darkMode")));
        }

        boutiqueRepository.save(boutique);
        storeGeneratorService.regenerate(storeId);
        return brandingPayload(boutique);
    }

    @Transactional
    public Map<String, Object> updateCurrency(UUID storeId, UUID userId, String currency) {
        Boutique boutique = requireOwnedStore(storeId, userId);
        String code = normalizeCurrency(currency);
        boutique.setCurrency(code);
        boutiqueRepository.save(boutique);
        storeGeneratorService.regenerate(storeId);
        return Map.of("currency", code);
    }

    @Transactional
    public Map<String, Object> uploadLogo(UUID storeId, UUID userId, MultipartFile file) {
        Boutique boutique = requireOwnedStore(storeId, userId);
        String oldLogoUrl = boutique.getLogoUrl();
        String logoUrl = uploadService.uploadImage(file, "logos");
        boutique.setLogoUrl(logoUrl);
        boutiqueRepository.save(boutique);
        uploadService.deletePublicUrl(oldLogoUrl);
        storeGeneratorService.regenerate(storeId);
        return Map.of("logoUrl", logoUrl);
    }

    private Boutique requireOwnedStore(UUID storeId, UUID userId) {
        if (storeId == null) throw new IllegalArgumentException("storeId requis");
        if (userId == null) throw new IllegalArgumentException("Utilisateur requis");
        return boutiqueRepository.findByUserIdAndId(userId, storeId)
                .orElseThrow(() -> new RuntimeException("Boutique non trouvee"));
    }

    private List<String> normalizeCountryCodes(List<String> rawCodes) {
        if (rawCodes == null) {
            return List.of();
        }

        Set<String> codes = new LinkedHashSet<>();
        for (String rawCode : rawCodes) {
            if (!StringUtils.hasText(rawCode)) continue;
            String code = rawCode.trim().toUpperCase(Locale.ROOT);
            if (!isIsoCountryCode(code)) {
                throw new IllegalArgumentException("Code pays invalide: " + rawCode);
            }
            codes.add(code);
        }
        return new ArrayList<>(codes);
    }

    private boolean isIsoCountryCode(String code) {
        if (code.length() != 2) return false;
        for (String isoCode : Locale.getISOCountries()) {
            if (isoCode.equals(code)) return true;
        }
        return false;
    }

    private String normalizeCurrency(String currency) {
        if (!StringUtils.hasText(currency)) {
            throw new IllegalArgumentException("Devise requise");
        }
        String code = currency.trim().toUpperCase(Locale.ROOT);
        try {
            Currency.getInstance(code);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Devise invalide", e);
        }
        if (!SUPPORTED_CURRENCIES.contains(code)) {
            throw new IllegalArgumentException("Devise non supportee");
        }
        return code;
    }

    private void setHexColor(Map<String, ?> body, String key, java.util.function.Consumer<String> setter) {
        if (!body.containsKey(key)) return;
        String value = asString(body.get(key));
        if (!HEX_COLOR.matcher(value).matches()) {
            throw new IllegalArgumentException("Couleur invalide pour " + key);
        }
        setter.accept(value.toUpperCase(Locale.ROOT));
    }

    private String asString(Object value) {
        if (value == null || !StringUtils.hasText(value.toString())) {
            throw new IllegalArgumentException("Valeur requise");
        }
        return value.toString().trim();
    }

    private boolean asBoolean(Object value) {
        if (value instanceof Boolean bool) return bool;
        String text = asString(value).toLowerCase(Locale.ROOT);
        return text.equals("true") || text.equals("yes") || text.equals("1");
    }

    private String getCountryName(String code) {
        if (code == null || code.length() != 2) return code;
        Locale locale = new Locale("", code);
        String name = locale.getDisplayName(Locale.FRENCH);
        if (name == null || name.isBlank() || name.equals(code)) {
            name = locale.getDisplayName(Locale.ENGLISH);
        }
        return name;
    }

    private Map<String, Object> brandingPayload(Boutique b) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("primaryColor", b.getPrimaryColor());
        payload.put("secondaryColor", b.getSecondaryColor());
        payload.put("headerColor", b.getHeaderColor());
        payload.put("footerColor", b.getFooterColor());
        payload.put("bodyColor", b.getBodyColor());
        payload.put("cardProductColor", b.getCardProductColor());
        payload.put("buttonColor", b.getButtonColor());
        payload.put("topBarColor", b.getTopBarColor());
        payload.put("textColor", b.getTextColor());
        payload.put("fontFamily", b.getFontFamily());
        payload.put("darkMode", Boolean.TRUE.equals(b.getDarkMode()));
        return payload;
    }
}
