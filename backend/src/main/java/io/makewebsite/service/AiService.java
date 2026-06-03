package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.makewebsite.dto.response.AiResponse;
import io.makewebsite.entity.AiConversation;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Product;
import io.makewebsite.entity.User;
import io.makewebsite.repository.AiConversationRepository;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.CustomerRepository;
import io.makewebsite.repository.OrderItemRepository;
import io.makewebsite.repository.OrderRepository;
import io.makewebsite.repository.ProductRepository;
import io.makewebsite.repository.StoreViewRepository;
import io.makewebsite.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpEntity;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AiService {
    private final AiConversationRepository aiConversationRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final UserRepository userRepository;
    private final ProductRepository productRepository;
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final StoreViewRepository storeViewRepository;
    private final CustomerRepository customerRepository;
    private final TenantAccessService tenantAccessService;
    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate;

    @Value("${ollama.base-url:http://localhost:11434}")
    private String ollamaBaseUrl;

    @Value("${ollama.model:qwen3:8b}")
    private String ollamaModel;

    @Value("${ollama.fallback-model:llama3.1:8b}")
    private String ollamaFallbackModel;

    private static final int MAX_HISTORY = 12;
    private static final int LOW_STOCK_LIMIT = 5;

    @Transactional
    public AiResponse chat(UUID userId, String message) {
        UUID boutiqueId = resolveOwnerBoutiqueId(userId, null);
        return ownerChat(userId, boutiqueId, message, null);
    }

    @Transactional
    public AiResponse ownerChat(UUID userId, UUID requestedBoutiqueId, String message, String sessionId) {
        UUID boutiqueId = resolveOwnerBoutiqueId(userId, requestedBoutiqueId);
        Boutique boutique = tenantAccessService.requireBoutiqueAccess(boutiqueId);

        saveHistory(userId, "user", message);
        List<AiConversation> history = limitedHistory(userId);
        Intent intent = detectOwnerIntent(message);
        AiResponse base = buildOwnerAnswer(boutique, intent, message);
        String reply = enrichWithLlm("owner", boutique, message, base, history);

        if (reply != null && !reply.isBlank()) {
            base.setReply(reply);
        }
        saveHistory(userId, "assistant", base.getReply());
        base.setHistory(toHistory(limitedHistory(userId)));
        return base;
    }

    @Transactional(readOnly = true)
    public AiResponse publicStoreChat(String slug, String message, String sessionId, List<Map<String, String>> messages) {
        Boutique boutique = boutiqueRepository.findBySlug(slug)
                .orElseThrow(() -> new RuntimeException("Boutique introuvable"));
        if (!Boolean.TRUE.equals(boutique.getIsPublished()) || !"ACTIVE".equalsIgnoreCase(nullToEmpty(boutique.getStoreStatus()))) {
            return AiResponse.builder()
                    .type("text")
                    .reply("Cette boutique n'est pas disponible pour le moment.")
                    .history(List.of())
                    .build();
        }

        String userMessage = message;
        if ((userMessage == null || userMessage.isBlank()) && messages != null && !messages.isEmpty()) {
            userMessage = messages.get(messages.size() - 1).getOrDefault("content", "");
        }
        if (userMessage == null || userMessage.isBlank()) {
            userMessage = "Bonjour";
        }

        Intent intent = detectCustomerIntent(userMessage);
        AiResponse base = buildCustomerAnswer(boutique, intent, userMessage);
        String reply = enrichWithLlm("customer", boutique, userMessage, base, List.of());
        if (reply != null && !reply.isBlank()) {
            base.setReply(reply);
        }
        base.setHistory(List.of());
        return base;
    }

    @Cacheable(value = "aiBestSellingProducts", key = "#boutiqueId")
    public List<Map<String, Object>> getBestSellingProducts(UUID boutiqueId) {
        return orderItemRepository.findBestSellingProducts(boutiqueId).stream()
                .limit(10)
                .map(row -> mapOf(
                        "productId", row[0],
                        "name", row[1],
                        "quantitySold", number(row[2]),
                        "revenue", money(row[3])
                ))
                .toList();
    }

    @Cacheable(value = "aiLowStockProducts", key = "#boutiqueId")
    public List<Map<String, Object>> getLowStockProducts(UUID boutiqueId) {
        return productRepository.findByBoutiqueIdAndStockLessThan(boutiqueId, LOW_STOCK_LIMIT).stream()
                .filter(p -> p.getIsActive() == null || p.getIsActive())
                .sorted(Comparator.comparing(p -> p.getStock() == null ? 0 : p.getStock()))
                .limit(20)
                .map(this::productCard)
                .toList();
    }

    @Cacheable(value = "aiRevenueStats", key = "#boutiqueId")
    public Map<String, Object> getRevenueStats(UUID boutiqueId) {
        LocalDate today = LocalDate.now();
        LocalDateTime todayStart = today.atStartOfDay();
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime monthStart = today.with(TemporalAdjusters.firstDayOfMonth()).atStartOfDay();
        LocalDateTime yearStart = today.with(TemporalAdjusters.firstDayOfYear()).atStartOfDay();
        return mapOf(
                "ordersToday", orderRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, now),
                "revenueToday", money(orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, now)),
                "revenueThisMonth", money(orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, monthStart, now)),
                "revenueThisYear", money(orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, yearStart, now)),
                "totalRevenue", money(orderRepository.sumRevenueByBoutiqueId(boutiqueId)),
                "totalOrders", orderRepository.countByBoutiqueId(boutiqueId)
        );
    }

    @Cacheable(value = "aiTopViewedProducts", key = "#boutiqueId")
    public List<Map<String, Object>> getTopViewedProducts(UUID boutiqueId) {
        List<Product> products = productRepository.findByBoutiqueIdAndIsActiveTrue(boutiqueId);
        List<Map<String, Object>> ranked = new ArrayList<>();
        for (Product product : products) {
            long views = storeViewRepository.findAllByBoutiqueIdOrderByViewedAtDesc(boutiqueId).stream()
                    .filter(v -> nullToEmpty(v.getPage()).contains(product.getId().toString()))
                    .count();
            if (views > 0) {
                Map<String, Object> card = productCard(product);
                card.put("views", views);
                ranked.add(card);
            }
        }
        ranked.sort((a, b) -> Long.compare(((Number) b.get("views")).longValue(), ((Number) a.get("views")).longValue()));
        return ranked.stream().limit(10).toList();
    }

    @Cacheable(value = "aiTrafficStats", key = "#boutiqueId")
    public Map<String, Object> getTrafficStats(UUID boutiqueId) {
        LocalDate today = LocalDate.now();
        LocalDateTime todayStart = today.atStartOfDay();
        LocalDateTime now = LocalDateTime.now();
        long visitsToday = storeViewRepository.countByBoutiqueIdAndViewedAtBetween(boutiqueId, todayStart, now);
        long visitsMonth = storeViewRepository.countByBoutiqueIdAndViewedAtBetween(
                boutiqueId, today.with(TemporalAdjusters.firstDayOfMonth()).atStartOfDay(), now);
        long ordersToday = orderRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, now);
        double conversion = visitsToday == 0 ? 0 : (ordersToday * 100.0 / visitsToday);
        return mapOf(
                "visitsToday", visitsToday,
                "visitsThisMonth", visitsMonth,
                "totalVisits", storeViewRepository.countByBoutiqueId(boutiqueId),
                "ordersToday", ordersToday,
                "conversionRateToday", Math.round(conversion * 100.0) / 100.0
        );
    }

    @Cacheable(value = "aiTopCustomers", key = "#boutiqueId")
    public List<Map<String, Object>> getTopCustomers(UUID boutiqueId) {
        return customerRepository.findTopCustomers(boutiqueId, PageRequest.of(0, 10)).stream()
                .map(row -> mapOf(
                        "name", row[0],
                        "orders", number(row[1]),
                        "totalSpent", money(row[2])
                ))
                .toList();
    }

    @Cacheable(value = "aiAbandonedProducts", key = "#boutiqueId")
    public List<Map<String, Object>> getAbandonedProducts(UUID boutiqueId) {
        Set<UUID> sold = new HashSet<>(orderItemRepository.findSoldProductIds(boutiqueId));
        return productRepository.findByBoutiqueIdAndIsActiveTrue(boutiqueId).stream()
                .filter(p -> !sold.contains(p.getId()))
                .limit(20)
                .map(this::productCard)
                .toList();
    }

    private AiResponse buildOwnerAnswer(Boutique boutique, Intent intent, String message) {
        UUID boutiqueId = boutique.getId();
        Map<String, Object> analytics = new LinkedHashMap<>();
        List<Map<String, Object>> products = List.of();
        String reply;

        switch (intent) {
            case BEST_SELLERS -> {
                products = getBestSellingProducts(boutiqueId);
                reply = products.isEmpty()
                        ? "Aucune vente produit trouvee pour cette boutique."
                        : "Votre meilleur produit est " + products.get(0).get("name") + " avec " + products.get(0).get("quantitySold") + " ventes.";
            }
            case LOW_STOCK -> {
                products = getLowStockProducts(boutiqueId);
                reply = products.isEmpty()
                        ? "Aucun produit en stock faible pour le moment."
                        : products.size() + " produit(s) ont un stock faible. Le plus urgent est " + products.get(0).get("name") + ".";
            }
            case REVENUE -> {
                analytics = getRevenueStats(boutiqueId);
                reply = "Revenu aujourd'hui: " + analytics.get("revenueToday") + " TND. Revenu ce mois: " + analytics.get("revenueThisMonth") + " TND.";
            }
            case ORDERS_TODAY -> {
                analytics = getRevenueStats(boutiqueId);
                reply = "Vous avez " + analytics.get("ordersToday") + " commande(s) aujourd'hui.";
            }
            case TOP_VIEWED -> {
                products = getTopViewedProducts(boutiqueId);
                reply = products.isEmpty()
                        ? "Je n'ai pas encore assez de vues produit pour classer les produits."
                        : "Le produit le plus consulte est " + products.get(0).get("name") + ".";
            }
            case TRAFFIC -> {
                analytics = getTrafficStats(boutiqueId);
                reply = "Visites aujourd'hui: " + analytics.get("visitsToday") + ". Taux de conversion aujourd'hui: " + analytics.get("conversionRateToday") + "%.";
            }
            case TOP_CUSTOMERS -> {
                analytics.put("topCustomers", getTopCustomers(boutiqueId));
                reply = ((List<?>) analytics.get("topCustomers")).isEmpty()
                        ? "Aucun client recurrent trouve pour le moment."
                        : "Votre meilleur client est " + ((Map<?, ?>) ((List<?>) analytics.get("topCustomers")).get(0)).get("name") + ".";
            }
            case ABANDONED -> {
                products = getAbandonedProducts(boutiqueId);
                reply = products.isEmpty()
                        ? "Tous vos produits actifs ont deja eu au moins une vente."
                        : products.size() + " produit(s) actifs n'ont pas encore de vente.";
            }
            case CATEGORY -> {
                List<Map<String, Object>> categories = bestCategories(boutiqueId);
                analytics.put("categories", categories);
                reply = categories.isEmpty()
                        ? "Je n'ai pas encore assez de ventes pour classer les categories."
                        : "La categorie la plus performante est " + categories.get(0).get("category") + ".";
            }
            case DELIVERY -> {
                List<Map<String, Object>> delivery = deliveryCompanies(boutiqueId);
                analytics.put("deliveryCompanies", delivery);
                reply = delivery.isEmpty()
                        ? "Aucune societe de livraison n'est encore dominante dans vos commandes."
                        : "La livraison la plus utilisee est " + delivery.get(0).get("company") + ".";
            }
            case PROMOTE -> {
                products = productsToPromote(boutiqueId);
                reply = products.isEmpty()
                        ? "Je n'ai pas encore assez de donnees pour recommander une promotion."
                        : "Je recommande de promouvoir " + products.get(0).get("name") + ": il combine demande, stock et potentiel de vente.";
            }
            default -> {
                analytics = mapOf(
                        "revenue", getRevenueStats(boutiqueId),
                        "traffic", getTrafficStats(boutiqueId),
                        "lowStockCount", getLowStockProducts(boutiqueId).size()
                );
                reply = "Je peux analyser vos ventes, stocks, trafic, clients, categories et produits a promouvoir pour " + boutique.getName() + ".";
            }
        }

        return AiResponse.builder()
                .type(products.isEmpty() ? "analytics" : "mixed")
                .reply(reply)
                .products(products)
                .recommendations(intent == Intent.PROMOTE ? products : List.of())
                .analytics(analytics)
                .history(List.of())
                .build();
    }

    private AiResponse buildCustomerAnswer(Boutique boutique, Intent intent, String message) {
        List<Map<String, Object>> products = switch (intent) {
            case CHEAPEST -> cheapestProducts(boutique.getId());
            case BEST_SELLERS, TRENDING -> customerBestSellers(boutique.getId());
            case NEW_ARRIVALS -> newArrivals(boutique.getId());
            default -> searchProducts(boutique.getId(), message);
        };

        String reply;
        if (products.isEmpty()) {
            reply = "Je n'ai pas trouve de produit correspondant dans cette boutique. Essayez avec une categorie, une couleur, une taille ou un budget.";
        } else if (intent == Intent.CHEAPEST) {
            reply = "Voici les produits les moins chers disponibles chez " + boutique.getName() + ".";
        } else if (intent == Intent.BEST_SELLERS || intent == Intent.TRENDING) {
            reply = "Voici les produits populaires chez " + boutique.getName() + ".";
        } else {
            reply = "J'ai trouve " + products.size() + " produit(s) qui correspondent a votre demande.";
        }

        return AiResponse.builder()
                .type("products")
                .reply(reply)
                .products(products)
                .recommendations(products)
                .analytics(Map.of("store", boutique.getName(), "slug", boutique.getSlug()))
                .history(List.of())
                .build();
    }

    private String enrichWithLlm(String mode, Boutique boutique, String userMessage, AiResponse base, List<AiConversation> history) {
        String modelToUse = ollamaModel;
        String responseText = callOllama(modelToUse, mode, boutique, userMessage, base, history);
        if (responseText == null && !ollamaFallbackModel.equals(modelToUse)) {
            responseText = callOllama(ollamaFallbackModel, mode, boutique, userMessage, base, history);
        }
        return responseText;
    }

    private String callOllama(String model, String mode, Boutique boutique, String userMessage, AiResponse base, List<AiConversation> history) {
        try {
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("model", model);
            requestBody.put("stream", false);

            ArrayNode messages = requestBody.putArray("messages");
            ObjectNode systemMsg = objectMapper.createObjectNode();
            systemMsg.put("role", "system");
            systemMsg.put("content", systemPrompt(mode));
            messages.add(systemMsg);

            for (AiConversation conv : history.stream().skip(Math.max(0, history.size() - MAX_HISTORY)).toList()) {
                ObjectNode msg = objectMapper.createObjectNode();
                msg.put("role", conv.getRole());
                msg.put("content", conv.getContent());
                messages.add(msg);
            }

            ObjectNode context = objectMapper.createObjectNode();
            context.put("role", "user");
            context.put("content", "Boutique: " + boutique.getName()
                    + "\nQuestion: " + userMessage
                    + "\nDB_CONTEXT_JSON: " + objectMapper.writeValueAsString(base)
                    + "\nReponds uniquement avec ces donnees. N'invente pas de produits, prix, commandes, clients ou chiffres.");
            messages.add(context);

            HttpEntity<String> request = new HttpEntity<>(objectMapper.writeValueAsString(requestBody));

            ResponseEntity<String> response = restTemplate.postForEntity(
                    ollamaBaseUrl + "/api/chat",
                    request,
                    String.class);

            JsonNode responseJson = objectMapper.readTree(response.getBody());
            JsonNode messageNode = responseJson.get("message");
            if (messageNode != null && messageNode.has("content")) {
                return messageNode.get("content").asText();
            }
            return null;
        } catch (Exception ignored) {
            return null;
        }
    }

    public List<Map<String, Object>> getHistory(UUID userId) {
        return toHistory(aiConversationRepository.findByUserIdOrderByCreatedAtAsc(userId));
    }

    @Transactional
    public void deleteHistory(UUID userId) {
        aiConversationRepository.deleteByUserId(userId);
    }

    private UUID resolveOwnerBoutiqueId(UUID userId, UUID requestedBoutiqueId) {
        if (requestedBoutiqueId != null) {
            tenantAccessService.requireBoutiqueAccess(requestedBoutiqueId);
            return requestedBoutiqueId;
        }
        User user = userRepository.findById(userId).orElseThrow(() -> new RuntimeException("Utilisateur introuvable"));
        if (user.getActiveBoutiqueId() != null) {
            tenantAccessService.requireBoutiqueAccess(user.getActiveBoutiqueId());
            return user.getActiveBoutiqueId();
        }
        List<Boutique> boutiques = boutiqueRepository.findByTenantId(user.getTenant().getId());
        if (boutiques.isEmpty()) {
            throw new RuntimeException("Aucune boutique trouvee");
        }
        tenantAccessService.requireBoutiqueAccess(boutiques.get(0).getId());
        return boutiques.get(0).getId();
    }

    private void saveHistory(UUID userId, String role, String content) {
        aiConversationRepository.save(AiConversation.builder()
                .user(User.builder().id(userId).build())
                .role(role)
                .content(content)
                .createdAt(LocalDateTime.now())
                .build());
    }

    private List<AiConversation> limitedHistory(UUID userId) {
        List<AiConversation> history = aiConversationRepository.findByUserIdOrderByCreatedAtAsc(userId);
        if (history.size() <= MAX_HISTORY) {
            return history;
        }
        return history.subList(history.size() - MAX_HISTORY, history.size());
    }

    private List<Map<String, Object>> toHistory(List<AiConversation> history) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (AiConversation conv : history) {
            result.add(mapOf("role", conv.getRole(), "content", conv.getContent()));
        }
        return result;
    }

    private Intent detectOwnerIntent(String message) {
        String q = normalize(message);
        if (containsAny(q, "best selling", "meilleur", "plus vendu", "bestseller", "best seller")) return Intent.BEST_SELLERS;
        if (containsAny(q, "low stock", "stock faible", "rupture", "stock bas")) return Intent.LOW_STOCK;
        if (containsAny(q, "revenue", "revenu", "chiffre", "ca ", "month", "mois")) return Intent.REVENUE;
        if (containsAny(q, "orders today", "commandes aujourd", "combien de commandes")) return Intent.ORDERS_TODAY;
        if (containsAny(q, "top viewed", "plus consulte", "vues produit")) return Intent.TOP_VIEWED;
        if (containsAny(q, "traffic", "trafic", "visites", "conversion")) return Intent.TRAFFIC;
        if (containsAny(q, "customers", "clients", "order most")) return Intent.TOP_CUSTOMERS;
        if (containsAny(q, "no sales", "sans vente", "aucune vente")) return Intent.ABANDONED;
        if (containsAny(q, "category", "categorie")) return Intent.CATEGORY;
        if (containsAny(q, "delivery", "livraison", "transport")) return Intent.DELIVERY;
        if (containsAny(q, "promote", "promouvoir", "promotion")) return Intent.PROMOTE;
        return Intent.GENERAL;
    }

    private Intent detectCustomerIntent(String message) {
        String q = normalize(message);
        if (containsAny(q, "cheap", "cheapest", "moins cher", "pas cher", "prix bas")) return Intent.CHEAPEST;
        if (containsAny(q, "trending", "populaire", "tendance")) return Intent.TRENDING;
        if (containsAny(q, "best seller", "meilleur", "plus vendu")) return Intent.BEST_SELLERS;
        if (containsAny(q, "new", "nouveau", "nouveaute")) return Intent.NEW_ARRIVALS;
        return Intent.SEARCH;
    }

    private List<Map<String, Object>> searchProducts(UUID boutiqueId, String query) {
        String q = normalize(query);
        Double maxPrice = extractMaxPrice(q);
        Set<String> terms = tokenize(q);
        return productRepository.findPublicProductsWithCategory(boutiqueId).stream()
                .map(p -> Map.entry(p, scoreProduct(p, terms, maxPrice, q)))
                .filter(e -> e.getValue() > 0)
                .sorted((a, b) -> Integer.compare(b.getValue(), a.getValue()))
                .limit(8)
                .map(e -> productCard(e.getKey()))
                .toList();
    }

    private int scoreProduct(Product product, Set<String> terms, Double maxPrice, String rawQuery) {
        String haystack = normalize(product.getName() + " " + nullToEmpty(product.getDescription()) + " "
                + nullToEmpty(product.getColors()) + " " + nullToEmpty(product.getSizes()) + " "
                + (product.getCategory() != null ? product.getCategory().getName() : ""));
        int score = 0;
        for (String term : expandTerms(terms)) {
            if (haystack.contains(term)) score += 4;
            else if (fuzzyContains(haystack, term)) score += 2;
        }
        if (maxPrice != null && product.getPrice() != null && product.getPrice().doubleValue() <= maxPrice) score += 5;
        if (containsAny(rawQuery, "gaming", "gamer") && containsAny(haystack, "gaming", "gamer", "pc", "laptop")) score += 6;
        if (containsAny(rawQuery, "promotion", "promo") && product.getComparePrice() != null) score += 3;
        return score;
    }

    private List<Map<String, Object>> cheapestProducts(UUID boutiqueId) {
        return productRepository.findPublicProductsWithCategory(boutiqueId).stream()
                .sorted(Comparator.comparing(Product::getPrice, Comparator.nullsLast(Comparator.naturalOrder())))
                .limit(8)
                .map(this::productCard)
                .toList();
    }

    private List<Map<String, Object>> newArrivals(UUID boutiqueId) {
        return productRepository.findByBoutiqueIdAndIsActiveTrueOrderByCreatedAtDesc(boutiqueId).stream()
                .limit(8)
                .map(this::productCard)
                .toList();
    }

    private List<Map<String, Object>> customerBestSellers(UUID boutiqueId) {
        List<Map<String, Object>> best = getBestSellingProducts(boutiqueId);
        if (!best.isEmpty()) return best;
        return newArrivals(boutiqueId);
    }

    private List<Map<String, Object>> productsToPromote(UUID boutiqueId) {
        Set<UUID> lowStockIds = getLowStockProducts(boutiqueId).stream()
                .map(p -> UUID.fromString(p.get("id").toString()))
                .collect(Collectors.toSet());
        return productRepository.findByBoutiqueIdAndIsActiveTrue(boutiqueId).stream()
                .filter(p -> !lowStockIds.contains(p.getId()))
                .sorted(Comparator.comparing(Product::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(5)
                .map(this::productCard)
                .toList();
    }

    private List<Map<String, Object>> bestCategories(UUID boutiqueId) {
        return orderItemRepository.findBestCategories(boutiqueId).stream()
                .limit(5)
                .map(row -> mapOf("category", row[0], "quantitySold", number(row[1]), "revenue", money(row[2])))
                .toList();
    }

    private List<Map<String, Object>> deliveryCompanies(UUID boutiqueId) {
        return orderRepository.countByDeliveryCompany(boutiqueId).stream()
                .limit(5)
                .map(row -> mapOf("company", row[0], "orders", number(row[1])))
                .toList();
    }

    private Map<String, Object> productCard(Product p) {
        return mapOf(
                "id", p.getId(),
                "name", p.getName(),
                "description", truncate(p.getDescription(), 140),
                "price", money(p.getPrice()),
                "comparePrice", money(p.getComparePrice()),
                "stock", p.getStock(),
                "category", p.getCategory() != null ? p.getCategory().getName() : null,
                "colors", p.getColors(),
                "sizes", p.getSizes(),
                "image", firstImage(p.getImages())
        );
    }

    private String systemPrompt(String mode) {
        if ("customer".equals(mode)) {
            return "Tu es un assistant shopping pour une boutique en ligne. Reponds en francais, aide a choisir, comparer et trouver des produits. Utilise uniquement le contexte DB fourni. N'invente jamais de produit, prix, stock ou promotion.";
        }
        return "Tu es un assistant business e-commerce pour proprietaires de boutiques. Reponds en francais avec des chiffres clairs. Utilise uniquement le contexte DB fourni. N'expose pas de donnees privees inutiles et n'invente jamais.";
    }

    private Map<String, Object> mapOf(Object... values) {
        Map<String, Object> map = new LinkedHashMap<>();
        for (int i = 0; i + 1 < values.length; i += 2) {
            map.put(String.valueOf(values[i]), values[i + 1]);
        }
        return map;
    }

    private String normalize(String input) {
        String value = input == null ? "" : input.toLowerCase(Locale.ROOT);
        value = Normalizer.normalize(value, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return value.replaceAll("[^a-z0-9. ]", " ").replaceAll("\\s+", " ").trim();
    }

    private boolean containsAny(String value, String... needles) {
        for (String needle : needles) {
            if (value.contains(normalize(needle))) return true;
        }
        return false;
    }

    private Set<String> tokenize(String value) {
        Set<String> stop = Set.of("je", "veux", "un", "une", "des", "de", "du", "le", "la", "les", "show", "me", "i", "want", "products", "produits");
        return Set.of(value.split(" ")).stream()
                .filter(t -> t.length() > 1 && !stop.contains(t))
                .collect(Collectors.toSet());
    }

    private Set<String> expandTerms(Set<String> terms) {
        Set<String> expanded = new HashSet<>(terms);
        if (terms.contains("shoes") || terms.contains("sneakers") || terms.contains("chaussure")) {
            expanded.addAll(Set.of("chaussures", "basket", "sneaker"));
        }
        if (terms.contains("hoodie") || terms.contains("sweat")) {
            expanded.addAll(Set.of("capuche", "pull"));
        }
        if (terms.contains("phone") || terms.contains("telephone")) {
            expanded.addAll(Set.of("smartphone", "mobile"));
        }
        if (terms.contains("gaming") || terms.contains("gamer")) {
            expanded.addAll(Set.of("pc gamer", "laptop", "console"));
        }
        return expanded;
    }

    private boolean fuzzyContains(String haystack, String term) {
        if (term.length() < 4) return false;
        for (String word : haystack.split(" ")) {
            if (levenshtein(word, term) <= 1) return true;
        }
        return false;
    }

    private int levenshtein(String a, String b) {
        int[] costs = new int[b.length() + 1];
        for (int j = 0; j < costs.length; j++) costs[j] = j;
        for (int i = 1; i <= a.length(); i++) {
            costs[0] = i;
            int nw = i - 1;
            for (int j = 1; j <= b.length(); j++) {
                int cj = Math.min(1 + Math.min(costs[j], costs[j - 1]), a.charAt(i - 1) == b.charAt(j - 1) ? nw : nw + 1);
                nw = costs[j];
                costs[j] = cj;
            }
        }
        return costs[b.length()];
    }

    private Double extractMaxPrice(String value) {
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile("(?:under|moins de|<)?\\s*(\\d+(?:\\.\\d+)?)\\s*(?:dt|tnd)?").matcher(value);
        Double found = null;
        while (matcher.find()) {
            found = Double.parseDouble(matcher.group(1));
        }
        return found;
    }

    private Object money(Object value) {
        if (value == null) return null;
        if (value instanceof BigDecimal bd) return bd.doubleValue();
        if (value instanceof Number n) return n.doubleValue();
        return value;
    }

    private long number(Object value) {
        return value instanceof Number n ? n.longValue() : 0;
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private String truncate(String value, int max) {
        if (value == null || value.length() <= max) return value;
        return value.substring(0, max) + "...";
    }

    private String firstImage(String images) {
        if (images == null || images.isBlank() || "[]".equals(images)) return null;
        String clean = images.trim();
        if (clean.startsWith("[") && clean.endsWith("]")) {
            clean = clean.substring(1, clean.length() - 1).trim();
        }
        if (clean.startsWith("\"")) {
            int end = clean.indexOf("\"", 1);
            return end > 1 ? clean.substring(1, end) : null;
        }
        int comma = clean.indexOf(',');
        return comma > 0 ? clean.substring(0, comma).trim() : clean;
    }

    private enum Intent {
        GENERAL,
        SEARCH,
        BEST_SELLERS,
        LOW_STOCK,
        REVENUE,
        ORDERS_TODAY,
        TOP_VIEWED,
        TRAFFIC,
        TOP_CUSTOMERS,
        ABANDONED,
        CATEGORY,
        DELIVERY,
        PROMOTE,
        CHEAPEST,
        TRENDING,
        NEW_ARRIVALS
    }
}
