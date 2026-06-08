package io.makewebsite.service;

import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.checkout.Session;
import com.stripe.param.checkout.SessionCreateParams;
import io.makewebsite.dto.request.SubscribeRequest;
import io.makewebsite.dto.response.InvoiceResponse;
import io.makewebsite.dto.response.PlanResponse;
import io.makewebsite.dto.response.SubscriptionCheckoutResponse;
import io.makewebsite.dto.response.SubscriptionCheckoutStatusResponse;
import io.makewebsite.dto.response.SubscriptionResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Invoice;
import io.makewebsite.entity.Plan;
import io.makewebsite.entity.Subscription;
import io.makewebsite.entity.User;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.InvoiceRepository;
import io.makewebsite.repository.PlanRepository;
import io.makewebsite.repository.SubscriptionRepository;
import io.makewebsite.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class PlanService {
    private static final Set<String> STRIPE_SUPPORTED_CURRENCIES = Set.of(
            "usd", "eur", "gbp", "cad", "aed", "jpy", "aud", "chf", "dkk", "hkd",
            "inr", "myr", "nok", "nzd", "sar", "sek", "sgd", "try", "zar"
    );

    private final PlanRepository planRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final InvoiceRepository invoiceRepository;
    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    @Value("${app.mobile-deep-link-scheme:makewebsite}")
    private String mobileDeepLinkScheme;

    @Value("${app.mobile-deep-link-host:stripe-return}")
    private String mobileDeepLinkHost;

    @Value("${stripe.subscription-currency:eur}")
    private String stripeSubscriptionCurrency;

    public List<PlanResponse> getPlans() {
        return planRepository.findAll().stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public SubscriptionResponse getMySubscription(UUID userId) {
        Subscription sub = subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE").orElse(null);
        if (sub == null) {
            return SubscriptionResponse.builder()
                    .planName("Free")
                    .status("FREE")
                    .build();
        }
        return mapToSubscriptionResponse(sub);
    }

    public List<SubscriptionResponse> getSubscriptionHistory(UUID userId) {
        return subscriptionRepository.findByUserId(userId).stream()
                .map(this::mapToSubscriptionResponse)
                .collect(Collectors.toList());
    }

    public List<InvoiceResponse> getInvoices(UUID userId) {
        return invoiceRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::mapToInvoiceResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public SubscriptionResponse subscribe(UUID userId, SubscribeRequest request) {
        if ("STRIPE".equalsIgnoreCase(request.getPaymentMethod())) {
            throw new RuntimeException("Utilisez l'endpoint Stripe checkout pour un abonnement Stripe");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Plan plan = planRepository.findById(request.getPlanId())
                .orElseThrow(() -> new RuntimeException("Plan non trouvé"));

        // Deactivate any existing active subscription
        subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .ifPresent(s -> { s.setStatus("CANCELLED"); subscriptionRepository.save(s); });

        Subscription sub = Subscription.builder()
                .user(user)
                .plan(plan)
                .status("ACTIVE")
                .startedAt(LocalDateTime.now())
                .expiresAt(LocalDateTime.now().plusDays(plan.getDurationDays()))
                .paymentMethod(request.getPaymentMethod() != null ? request.getPaymentMethod() : "BANK")
                .build();
        sub = subscriptionRepository.save(sub);

        // Create invoice
        Invoice invoice = Invoice.builder()
                .user(user)
                .subscription(sub)
                .amount(plan.getPriceDt())
                .currency("TND")
                .status("PENDING")
                .paymentMethod(sub.getPaymentMethod())
                .build();
        invoiceRepository.save(invoice);

        return mapToSubscriptionResponse(sub);
    }

    @Transactional
    public SubscriptionCheckoutResponse createStripeCheckoutSession(UUID userId, SubscribeRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Plan plan = planRepository.findById(request.getPlanId())
                .orElseThrow(() -> new RuntimeException("Plan non trouvé"));

        if (plan.getPriceDt() == null || plan.getPriceDt().compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("Le plan sélectionné doit avoir un prix Stripe positif");
        }

        String secretKey = resolveSecretKey();
        Stripe.apiKey = secretKey;

        String currency = normalizeStripeCurrency(stripeSubscriptionCurrency);
        long amountMinor = plan.getPriceDt().multiply(BigDecimal.valueOf(100)).longValue();
        if (amountMinor <= 0) {
            throw new RuntimeException("Montant Stripe invalide pour le plan sélectionné");
        }

        Invoice invoice = Invoice.builder()
                .user(user)
                .amount(plan.getPriceDt())
                .currency(currency.toUpperCase())
                .status("PENDING")
                .paymentMethod("STRIPE")
                .invoiceData(new HashMap<>())
                .build();
        invoice = invoiceRepository.save(invoice);

        Map<String, Object> invoiceData = mutableInvoiceData(invoice);
        invoiceData.put("billingType", "SUBSCRIPTION");
        invoiceData.put("planId", plan.getId());
        invoiceData.put("userId", userId.toString());
        subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .ifPresent(existing -> invoiceData.put("previousSubscriptionId", existing.getId().toString()));

        Map<String, String> metadata = new HashMap<>();
        metadata.put("billingType", "SUBSCRIPTION");
        metadata.put("invoiceId", invoice.getId().toString());
        metadata.put("planId", plan.getId().toString());
        metadata.put("userId", userId.toString());

        try {
            SessionCreateParams.LineItem.PriceData.ProductData productData =
                    SessionCreateParams.LineItem.PriceData.ProductData.builder()
                            .setName("Abonnement " + plan.getName())
                            .setDescription("Abonnement MakeWebsite.io")
                            .build();

            SessionCreateParams.LineItem.PriceData priceData =
                    SessionCreateParams.LineItem.PriceData.builder()
                            .setCurrency(currency)
                            .setUnitAmount(amountMinor)
                            .setProductData(productData)
                            .build();

            SessionCreateParams.LineItem lineItem =
                    SessionCreateParams.LineItem.builder()
                            .setPriceData(priceData)
                            .setQuantity(1L)
                            .build();

            SessionCreateParams.PaymentIntentData.Builder paymentIntentData =
                    SessionCreateParams.PaymentIntentData.builder();
            metadata.forEach(paymentIntentData::putMetadata);

            SessionCreateParams.Builder paramsBuilder = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl(buildCheckoutSuccessUrl())
                    .setCancelUrl(buildCheckoutCancelUrl())
                    .setCustomerEmail(user.getEmail())
                    .addLineItem(lineItem)
                    .setPaymentIntentData(paymentIntentData.build());

            metadata.forEach(paramsBuilder::putMetadata);

            Session session = Session.create(paramsBuilder.build());

            invoice.setPaymentRef(session.getId());
            invoiceData.put("stripeSessionId", session.getId());
            invoiceData.put("checkoutStatus", "CREATED");
            invoice.setInvoiceData(invoiceData);
            invoiceRepository.save(invoice);

            return SubscriptionCheckoutResponse.builder()
                    .invoiceId(invoice.getId())
                    .sessionId(session.getId())
                    .sessionUrl(session.getUrl())
                    .status("PENDING_PAYMENT")
                    .build();
        } catch (StripeException e) {
            invoice.setStatus("FAILED");
            invoiceData.put("checkoutStatus", "SESSION_CREATION_FAILED");
            invoiceData.put("failureReason", e.getMessage());
            invoice.setInvoiceData(invoiceData);
            invoiceRepository.save(invoice);
            throw new RuntimeException("Erreur Stripe: " + e.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public SubscriptionCheckoutStatusResponse getCheckoutStatus(UUID userId, String sessionId) {
        Invoice invoice = invoiceRepository.findByPaymentRefAndUserId(sessionId, userId)
                .orElseThrow(() -> new RuntimeException("Session Stripe introuvable"));

        Subscription activeSubscription = subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE").orElse(null);
        if (activeSubscription == null && invoice.getSubscription() != null &&
                "ACTIVE".equalsIgnoreCase(invoice.getSubscription().getStatus())) {
            activeSubscription = invoice.getSubscription();
        }

        Map<String, Object> invoiceData = mutableInvoiceData(invoice);
        String invoiceStatus = invoice.getStatus() != null ? invoice.getStatus() : "PENDING";
        String paymentIntentId = stringValue(invoiceData.get("stripePaymentIntentId"));

        if (activeSubscription != null) {
            return SubscriptionCheckoutStatusResponse.builder()
                    .sessionId(sessionId)
                    .invoiceStatus(invoiceStatus)
                    .subscriptionStatus("ACTIVE")
                    .paymentRef(invoice.getPaymentRef())
                    .paymentIntentId(paymentIntentId)
                    .dashboardUnlocked(true)
                    .message("Abonnement activé")
                    .build();
        }

        if ("FAILED".equalsIgnoreCase(invoiceStatus)) {
            return SubscriptionCheckoutStatusResponse.builder()
                    .sessionId(sessionId)
                    .invoiceStatus("FAILED")
                    .subscriptionStatus("PAYMENT_FAILED")
                    .paymentRef(invoice.getPaymentRef())
                    .paymentIntentId(paymentIntentId)
                    .dashboardUnlocked(false)
                    .message(stringValue(invoiceData.getOrDefault("failureReason", "Paiement Stripe échoué")))
                    .build();
        }

        return SubscriptionCheckoutStatusResponse.builder()
                .sessionId(sessionId)
                .invoiceStatus(invoiceStatus)
                .subscriptionStatus("PENDING_PAYMENT")
                .paymentRef(invoice.getPaymentRef())
                .paymentIntentId(paymentIntentId)
                .dashboardUnlocked(false)
                .message("Paiement en attente de confirmation webhook")
                .build();
    }

    @Transactional
    public void cancelSubscription(UUID userId) {
        Subscription sub = subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .orElseThrow(() -> new RuntimeException("Aucun abonnement actif"));
        sub.setStatus("CANCELLED");
        subscriptionRepository.save(sub);
    }

    @Transactional
    public SubscriptionResponse upgradeSubscription(UUID userId, SubscribeRequest request) {
        // Cancel current, then subscribe to new
        subscriptionRepository.findByUserIdAndStatus(userId, "ACTIVE")
                .ifPresent(s -> { s.setStatus("UPGRADED"); subscriptionRepository.save(s); });
        return subscribe(userId, request);
    }

    public SubscriptionResponse getSubscriptionDetails(UUID subscriptionId, UUID userId) {
        Subscription sub = subscriptionRepository.findById(subscriptionId)
                .orElseThrow(() -> new RuntimeException("Abonnement non trouvé"));
        if (!sub.getUser().getId().equals(userId)) {
            throw new RuntimeException("Accès refusé");
        }
        return mapToSubscriptionResponse(sub);
    }

    @Transactional
    public void handleStripeCheckoutCompleted(Session session) {
        if (!isSubscriptionCheckout(session.getMetadata())) {
            return;
        }

        Invoice invoice = loadSubscriptionInvoice(session.getMetadata());
        Map<String, Object> invoiceData = mutableInvoiceData(invoice);
        invoiceData.put("stripeSessionId", session.getId());
        invoiceData.put("checkoutStatus", "COMPLETED");
        invoiceData.put("lastStripeEvent", "checkout.session.completed");
        if (session.getCustomer() != null) {
            invoiceData.put("stripeCustomerId", session.getCustomer());
        }
        if (session.getPaymentIntent() != null) {
            invoiceData.put("stripePaymentIntentId", session.getPaymentIntent());
        }
        invoice.setInvoiceData(invoiceData);
        invoice.setPaymentMethod("STRIPE");
        if (invoice.getPaymentRef() == null || invoice.getPaymentRef().isBlank()) {
            invoice.setPaymentRef(session.getId());
        }
        invoiceRepository.save(invoice);

        if ("paid".equalsIgnoreCase(session.getPaymentStatus())) {
            activateSubscriptionFromInvoice(
                    invoice,
                    session.getId(),
                    session.getPaymentIntent(),
                    session.getCustomer(),
                    null,
                    "checkout.session.completed"
            );
        }
    }

    @Transactional
    public void handleStripePaymentSucceeded(Map<String, String> metadata,
                                             String sessionId,
                                             String paymentIntentId,
                                             String customerId,
                                             String stripeInvoiceId,
                                             String eventType) {
        if (!isSubscriptionCheckout(metadata)) {
            return;
        }
        Invoice invoice = loadSubscriptionInvoice(metadata);
        activateSubscriptionFromInvoice(invoice, sessionId, paymentIntentId, customerId, stripeInvoiceId, eventType);
    }

    @Transactional
    public void handleStripePaymentFailed(Map<String, String> metadata,
                                          String sessionId,
                                          String paymentIntentId,
                                          String stripeInvoiceId,
                                          String failureReason,
                                          String eventType) {
        if (!isSubscriptionCheckout(metadata)) {
            return;
        }

        Invoice invoice = loadSubscriptionInvoice(metadata);
        Map<String, Object> invoiceData = mutableInvoiceData(invoice);
        if (sessionId != null && !sessionId.isBlank()) {
            invoiceData.put("stripeSessionId", sessionId);
        }
        if (paymentIntentId != null && !paymentIntentId.isBlank()) {
            invoiceData.put("stripePaymentIntentId", paymentIntentId);
        }
        if (stripeInvoiceId != null && !stripeInvoiceId.isBlank()) {
            invoiceData.put("stripeInvoiceId", stripeInvoiceId);
        }
        invoiceData.put("checkoutStatus", "FAILED");
        invoiceData.put("lastStripeEvent", eventType);
        if (failureReason != null && !failureReason.isBlank()) {
            invoiceData.put("failureReason", failureReason);
        }
        invoice.setInvoiceData(invoiceData);
        invoice.setStatus("FAILED");
        invoice.setPaymentMethod("STRIPE");
        if (invoice.getPaymentRef() == null || invoice.getPaymentRef().isBlank()) {
            invoice.setPaymentRef(sessionId);
        }
        invoiceRepository.save(invoice);
    }

    private PlanResponse mapToResponse(Plan plan) {
        return PlanResponse.builder()
                .id(plan.getId())
                .name(plan.getName())
                .priceDt(plan.getPriceDt())
                .durationDays(plan.getDurationDays())
                .maxProducts(plan.getMaxProducts())
                .commissionPercent(plan.getCommissionPercent())
                .features(plan.getFeatures())
                .build();
    }

    private SubscriptionResponse mapToSubscriptionResponse(Subscription s) {
        return SubscriptionResponse.builder()
                .id(s.getId())
                .planId(s.getPlan().getId())
                .planName(s.getPlan().getName())
                .status(s.getStatus())
                .startedAt(s.getStartedAt())
                .expiresAt(s.getExpiresAt())
                .paymentMethod(s.getPaymentMethod())
                .paymentRef(s.getPaymentRef())
                .build();
    }

    private InvoiceResponse mapToInvoiceResponse(Invoice inv) {
        String planName = inv.getSubscription() != null && inv.getSubscription().getPlan() != null
                ? inv.getSubscription().getPlan().getName()
                : null;
        return InvoiceResponse.builder()
                .id(inv.getId())
                .userId(inv.getUser().getId())
                .subscriptionId(inv.getSubscription() != null ? inv.getSubscription().getId() : null)
                .amount(inv.getAmount())
                .currency(inv.getCurrency())
                .status(inv.getStatus())
                .planName(planName)
                .paymentMethod(inv.getPaymentMethod())
                .paymentRef(inv.getPaymentRef())
                .invoiceCreatedAt(inv.getCreatedAt())
                .paymentStatus(inv.getStatus())
                .paidAt("PAID".equalsIgnoreCase(inv.getStatus()) ? inv.getCreatedAt() : null)
                .createdAt(inv.getCreatedAt())
                .build();
    }

    private String resolveSecretKey() {
        if (stripeSecretKey != null && !stripeSecretKey.isBlank()) {
            return stripeSecretKey;
        }
        String fromEnv = System.getenv("STRIPE_SECRET_KEY");
        if (fromEnv != null && !fromEnv.isBlank()) {
            return fromEnv;
        }
        throw new RuntimeException("STRIPE_SECRET_KEY manquant");
    }

    private String normalizeStripeCurrency(String candidate) {
        String lower = candidate == null ? "" : candidate.trim().toLowerCase();
        return STRIPE_SUPPORTED_CURRENCIES.contains(lower) ? lower : "eur";
    }

    private String buildCheckoutSuccessUrl() {
        return mobileDeepLinkScheme + "://" + mobileDeepLinkHost + "/subscription?status=success&session_id={CHECKOUT_SESSION_ID}";
    }

    private String buildCheckoutCancelUrl() {
        return mobileDeepLinkScheme + "://" + mobileDeepLinkHost + "/subscription?status=cancelled";
    }

    private boolean isSubscriptionCheckout(Map<String, String> metadata) {
        return metadata != null && "SUBSCRIPTION".equalsIgnoreCase(metadata.get("billingType"));
    }

    private Invoice loadSubscriptionInvoice(Map<String, String> metadata) {
        String invoiceId = metadata != null ? metadata.get("invoiceId") : null;
        if (invoiceId == null || invoiceId.isBlank()) {
            throw new RuntimeException("Invoice Stripe abonnement introuvable");
        }
        return invoiceRepository.findById(UUID.fromString(invoiceId))
                .orElseThrow(() -> new RuntimeException("Facture abonnement introuvable"));
    }

    private void activateSubscriptionFromInvoice(Invoice invoice,
                                                 String sessionId,
                                                 String paymentIntentId,
                                                 String customerId,
                                                 String stripeInvoiceId,
                                                 String eventType) {
        if ("PAID".equalsIgnoreCase(invoice.getStatus())) {
            log.info("Invoice {} already PAID, skipping duplicate activation (event={})", invoice.getId(), eventType);
            return;
        }
        Map<String, Object> invoiceData = mutableInvoiceData(invoice);
        if (sessionId != null && !sessionId.isBlank()) {
            invoiceData.put("stripeSessionId", sessionId);
        }
        if (paymentIntentId != null && !paymentIntentId.isBlank()) {
            invoiceData.put("stripePaymentIntentId", paymentIntentId);
        }
        if (customerId != null && !customerId.isBlank()) {
            invoiceData.put("stripeCustomerId", customerId);
        }
        if (stripeInvoiceId != null && !stripeInvoiceId.isBlank()) {
            invoiceData.put("stripeInvoiceId", stripeInvoiceId);
        }
        invoiceData.put("checkoutStatus", "PAID");
        invoiceData.put("lastStripeEvent", eventType);
        invoice.setInvoiceData(invoiceData);
        invoice.setStatus("PAID");
        invoice.setPaymentMethod("STRIPE");
        if (invoice.getPaymentRef() == null || invoice.getPaymentRef().isBlank()) {
            invoice.setPaymentRef(sessionId);
        }

        Plan plan = resolvePlan(invoice, invoiceData);
        Subscription current = subscriptionRepository.findByUserIdAndStatus(invoice.getUser().getId(), "ACTIVE").orElse(null);
        Subscription subscription = invoice.getSubscription();

        if (current != null && (subscription == null || !current.getId().equals(subscription.getId()))) {
            current.setStatus("CANCELLED");
            subscriptionRepository.save(current);
        }

        if (subscription == null) {
            subscription = Subscription.builder()
                    .user(invoice.getUser())
                    .plan(plan)
                    .status("ACTIVE")
                    .startedAt(LocalDateTime.now())
                    .expiresAt(LocalDateTime.now().plusDays(plan.getDurationDays()))
                    .paymentMethod("STRIPE")
                    .paymentRef(paymentIntentId != null && !paymentIntentId.isBlank() ? paymentIntentId : sessionId)
                    .build();
        } else {
            subscription.setPlan(plan);
            subscription.setStatus("ACTIVE");
            subscription.setStartedAt(LocalDateTime.now());
            subscription.setExpiresAt(LocalDateTime.now().plusDays(plan.getDurationDays()));
            subscription.setPaymentMethod("STRIPE");
            subscription.setPaymentRef(paymentIntentId != null && !paymentIntentId.isBlank() ? paymentIntentId : sessionId);
        }

        subscription = subscriptionRepository.save(subscription);
        invoice.setSubscription(subscription);
        invoiceRepository.save(invoice);

        reactivateBoutiques(invoice.getUser().getId());
    }

    private Plan resolvePlan(Invoice invoice, Map<String, Object> invoiceData) {
        if (invoice.getSubscription() != null && invoice.getSubscription().getPlan() != null) {
            return invoice.getSubscription().getPlan();
        }

        Object rawPlanId = invoiceData.get("planId");
        if (rawPlanId == null) {
            throw new RuntimeException("Plan Stripe introuvable pour cette facture");
        }
        Integer planId = Integer.valueOf(rawPlanId.toString());
        return planRepository.findById(planId)
                .orElseThrow(() -> new RuntimeException("Plan introuvable"));
    }

    private void reactivateBoutiques(UUID userId) {
        List<Boutique> boutiques = boutiqueRepository.findByUserId(userId);
        for (Boutique boutique : boutiques) {
            if (!"FROZEN".equalsIgnoreCase(boutique.getStoreStatus())) {
                continue;
            }
            String freezeReason = boutique.getFreezeReason();
            if (freezeReason == null || !freezeReason.startsWith("SUBSCRIPTION_")) {
                continue;
            }
            boutique.setStoreStatus("ACTIVE");
            boutique.setFrozenAt(null);
            boutique.setFreezeReason(null);
            boutiqueRepository.save(boutique);
        }
    }

    private Map<String, Object> mutableInvoiceData(Invoice invoice) {
        return invoice.getInvoiceData() != null
                ? new HashMap<>(invoice.getInvoiceData())
                : new HashMap<>();
    }

    private String stringValue(Object value) {
        return value == null ? null : value.toString();
    }
}
