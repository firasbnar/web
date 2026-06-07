package io.makewebsite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.makewebsite.dto.response.AiChatResponse;
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
import lombok.extern.slf4j.Slf4j;
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
@Slf4j
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
        String reply = enrichWithLlm(boutique, message, base, history);

        if (reply != null && !reply.isBlank()) {
            base.setReply(reply);
        }
        saveHistory(userId, "assistant", base.getReply());
        base.setHistory(toHistory(limitedHistory(userId)));
        return base;
    }

    @Transactional(readOnly = true)
    public AiChatResponse merchantChat(UUID userId, UUID requestedBoutiqueId, String message) {
        UUID boutiqueId = resolveOwnerBoutiqueId(userId, requestedBoutiqueId);
        Boutique boutique = tenantAccessService.requireBoutiqueAccess(boutiqueId);
        String currency = boutique.getCurrency() != null ? boutique.getCurrency() : "TND";

        StringBuilder ctx = new StringBuilder();
        ctx.append("Store name: ").append(boutique.getName()).append("\n");
        if (boutique.getDescription() != null)
            ctx.append("Store description: ").append(boutique.getDescription()).append("\n");
        ctx.append("Currency: ").append(currency).append("\n");

        ctx.append("Active products: ").append(productRepository.countByBoutiqueIdAndIsActiveTrue(boutiqueId)).append("\n");

        List<Map<String, Object>> lowStock = getLowStockProducts(boutiqueId);
        if (!lowStock.isEmpty()) {
            ctx.append("Low stock products: ");
            for (Map<String, Object> p : lowStock)
                ctx.append(p.get("name")).append(" (stock: ").append(p.get("stock")).append("), ");
            ctx.append("\n");
        }

        Map<String, Object> revenue = getRevenueStats(boutiqueId);
        ctx.append("Orders today: ").append(revenue.get("ordersToday")).append("\n");
        ctx.append("Revenue today: ").append(revenue.get("revenueToday")).append(" ").append(currency).append("\n");
        ctx.append("Revenue this month: ").append(revenue.get("revenueThisMonth")).append(" ").append(currency).append("\n");
        ctx.append("Total revenue: ").append(revenue.get("totalRevenue")).append(" ").append(currency).append("\n");
        ctx.append("Total orders: ").append(revenue.get("totalOrders")).append("\n");

        Map<String, Object> traffic = getTrafficStats(boutiqueId);
        ctx.append("Visits today: ").append(traffic.get("visitsToday")).append("\n");
        ctx.append("Conversion rate today: ").append(traffic.get("conversionRateToday")).append("%\n");

        List<Map<String, Object>> bestSellers = getBestSellingProducts(boutiqueId);
        if (!bestSellers.isEmpty()) {
            ctx.append("Best-selling products: ");
            for (Map<String, Object> p : bestSellers.stream().limit(5).toList())
                ctx.append(p.get("name")).append(" (").append(p.get("quantitySold")).append(" sold), ");
            ctx.append("\n");
        }

        String systemPrompt = "You are Merchant Copilot for MakeWebsite.io.\n"
                + "You help the merchant understand analytics, products, orders, revenue, traffic, and business performance.\n"
                + "Use only the provided store data.\n"
                + "Do not invent numbers.\n"
                + "Give short, clear, useful business advice.";
        String answer = callOllamaSimple(systemPrompt, ctx + "\nMerchant question: " + (message != null ? message : "Bonjour"));
        return AiChatResponse.builder()
                .answer(answer != null ? answer : "D\u00e9sol\u00e9, je n'ai pas pu traiter votre demande pour le moment.")
                .build();
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

    private String enrichWithLlm(Boutique boutique, String userMessage, AiResponse base, List<AiConversation> history) {
        String modelToUse = ollamaModel;
        String responseText = callOllama(modelToUse, boutique, userMessage, base, history);
        if (responseText == null && !ollamaFallbackModel.equals(modelToUse)) {
            responseText = callOllama(ollamaFallbackModel, boutique, userMessage, base, history);
        }
        return responseText;
    }

    private String callOllamaSimple(String systemPrompt, String userContent) {
        try {
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("model", ollamaModel);
            requestBody.put("stream", false);
            ArrayNode messages = requestBody.putArray("messages");

            ObjectNode systemNode = objectMapper.createObjectNode();
            systemNode.put("role", "system");
            systemNode.put("content", systemPrompt);
            messages.add(systemNode);

            ObjectNode userNode = objectMapper.createObjectNode();
            userNode.put("role", "user");
            userNode.put("content", userContent);
            messages.add(userNode);

            HttpEntity<String> request = new HttpEntity<>(objectMapper.writeValueAsString(requestBody));
            ResponseEntity<String> response = restTemplate.postForEntity(
                    ollamaBaseUrl + "/api/chat", request, String.class);
            JsonNode responseJson = objectMapper.readTree(response.getBody());
            JsonNode messageNode = responseJson.get("message");
            if (messageNode != null && messageNode.has("content")) {
                return messageNode.get("content").asText();
            }
            return null;
        } catch (Exception e) {
            log.warn("Ollama chat failed: {}", e.getMessage());
            return null;
        }
    }

    private String callOllama(String model, Boutique boutique, String userMessage, AiResponse base, List<AiConversation> history) {
        try {
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("model", model);
            requestBody.put("stream", false);

            ArrayNode messages = requestBody.putArray("messages");
            ObjectNode systemMsg = objectMapper.createObjectNode();
            systemMsg.put("role", "system");
            systemMsg.put("content", systemPrompt());
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
                "description", p.getDescription(),
                "price", money(p.getPrice()),
                "comparePrice", money(p.getComparePrice()),
                "stock", p.getStock(),
                "category", p.getCategory() != null ? p.getCategory().getName() : null,
                "colors", p.getColors(),
                "sizes", p.getSizes(),
                "image", p.getImages()
        );
    }

    private String systemPrompt() {
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

    private enum Intent {
        GENERAL,
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
        PROMOTE
    }
}
