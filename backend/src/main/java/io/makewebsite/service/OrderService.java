package io.makewebsite.service;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.util.CsvUtil;
import lombok.RequiredArgsConstructor;

import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final CustomerRepository customerRepository;
    private final CustomerService customerService;
    private final ProductRepository productRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final WebSocketService webSocketService;
    private final TelegramService telegramService;
    private final TelegramNotificationService telegramNotificationService;
    private final InvoiceService invoiceService;
    private final CaisseService caisseService;
    private final StoreStatusGuard storeStatusGuard;
    private final InvoicePdfService invoicePdfService;
    private final EmailService emailService;
    private final CouponService couponService;

    @Transactional(readOnly = true)
    public Page<OrderResponse> getOrders(UUID boutiqueId, String status, String search,
                                          String startDate, String endDate, Pageable pageable) {
        boolean hasDate = startDate != null && !startDate.isEmpty();

        if (hasDate) {
            LocalDateTime from = LocalDate.parse(startDate).atStartOfDay();
            LocalDateTime to = endDate != null && !endDate.isEmpty()
                    ? LocalDate.parse(endDate).atTime(LocalTime.MAX)
                    : LocalDateTime.now();
            Page<Order> orders;
            if (search != null && !search.isEmpty() && status != null && !status.isEmpty() && !"ALL".equals(status)) {
                orders = orderRepository
                        .findByBoutiqueIdAndStatusAndOrderNumberContainingIgnoreCaseAndCreatedAtBetween(
                                boutiqueId, status, search, from, to, pageable);
            } else if (search != null && !search.isEmpty()) {
                orders = orderRepository
                        .findByBoutiqueIdAndOrderNumberContainingIgnoreCaseAndCreatedAtBetween(
                                boutiqueId, search, from, to, pageable);
            } else if (status != null && !status.isEmpty() && !"ALL".equals(status)) {
                orders = orderRepository
                        .findByBoutiqueIdAndStatusAndCreatedAtBetween(
                                boutiqueId, status, from, to, pageable);
            } else {
                orders = orderRepository
                        .findByBoutiqueIdAndCreatedAtBetween(boutiqueId, from, to, pageable);
            }
            return orders.map(this::mapToResponse);
        }

        Page<Order> orders;
        if (search != null && !search.isEmpty() && status != null && !status.isEmpty() && !"ALL".equals(status)) {
            orders = orderRepository.findByBoutiqueIdAndStatusAndOrderNumberContainingIgnoreCase(boutiqueId, status, search, pageable);
        } else if (search != null && !search.isEmpty()) {
            orders = orderRepository.findByBoutiqueIdAndOrderNumberContainingIgnoreCase(boutiqueId, search, pageable);
        } else if (status != null && !status.isEmpty() && !"ALL".equals(status)) {
            orders = orderRepository.findByBoutiqueIdAndStatus(boutiqueId, status, pageable);
        } else {
            orders = orderRepository.findByBoutiqueId(boutiqueId, pageable);
        }
        return orders.map(this::mapToResponse);
    }

    @Transactional(readOnly = true)
    public OrderResponse getOrder(UUID id) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new RuntimeException("Commande non trouvée"));
        return mapToResponse(order);
    }

    @Transactional(readOnly = true)
    public Page<OrderResponse> getMyOrders(UUID userId, Pageable pageable) {
        return orderRepository.findByUserId(userId, pageable).map(this::mapToResponse);
    }

    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request, UUID userId) {
        Boutique boutique = boutiqueRepository.findById(request.getBoutiqueId())
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        storeStatusGuard.requireActive(boutique);

        if ("paypal".equalsIgnoreCase(request.getPaymentMethod())) {
            throw new RuntimeException("PayPal n'est plus disponible");
        }

        User user = userId != null ? userRepository.findById(userId).orElse(null) : null;

        Customer customer = null;
        if (request.getCustomerId() != null) {
            customer = customerRepository.findById(request.getCustomerId()).orElse(null);
        } else if (request.getCustomerName() != null && !request.getCustomerName().isEmpty()) {
            customer = customerService.findOrCreateCustomer(
                    request.getBoutiqueId(),
                    request.getCustomerName(),
                    request.getCustomerEmail(),
                    request.getCustomerPhone(),
                    request.getShippingAddress(),
                    request.getCity(),
                    request.getGovernorate(),
                    request.getPostalCode(),
                    request.getCountry()
            );
        }

        String datePart = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        String randomPart = String.format("%04d", new Random().nextInt(10000));
        String orderNumber = "MW-" + datePart + "-" + randomPart;

        BigDecimal subtotal = BigDecimal.ZERO;
        List<OrderItem> items = new ArrayList<>();

        for (OrderItemRequest itemReq : request.getItems()) {
            BigDecimal itemSubtotal = itemReq.getUnitPrice().multiply(BigDecimal.valueOf(itemReq.getQuantity()));
            subtotal = subtotal.add(itemSubtotal);

            Product product = null;
            if (itemReq.getProductId() != null) {
                product = productRepository.findById(itemReq.getProductId()).orElse(null);
            }

            int qty = itemReq.getQuantity() != null ? itemReq.getQuantity() : 1;
            if (product != null && product.getStock() != null && product.getStock() < qty) {
                throw new RuntimeException("Stock insuffisant pour " + product.getName()
                        + " (demand\u00E9: " + qty + ", disponible: " + product.getStock() + ")");
            }

            items.add(OrderItem.builder()
                    .product(product)
                    .productName(itemReq.getProductName())
                    .unitPrice(itemReq.getUnitPrice())
                    .quantity(qty)
                    .subtotal(itemSubtotal)
                    .build());
        }

        for (OrderItemRequest itemReq : request.getItems()) {
            if (itemReq.getProductId() != null) {
                Product product = productRepository.findById(itemReq.getProductId()).orElse(null);
                if (product != null && product.getStock() != null) {
                    int qty = itemReq.getQuantity() != null ? itemReq.getQuantity() : 1;
                    product.setStock(product.getStock() - qty);
                    int remaining = product.getStock();

                    if (remaining > 5) {
                        product.setLowStockAlertSent(false);
                        product.setOutOfStockAlertSent(false);
                    } else if (remaining > 0) {
                        if (!Boolean.TRUE.equals(product.getLowStockAlertSent())) {
                            telegramNotificationService.notifyLowStock(product, remaining);
                            product.setLowStockAlertSent(true);
                        }
                        product.setOutOfStockAlertSent(false);
                    } else {
                        if (!Boolean.TRUE.equals(product.getOutOfStockAlertSent())) {
                            telegramNotificationService.notifyOutOfStock(product);
                            product.setOutOfStockAlertSent(true);
                        }
                        product.setLowStockAlertSent(false);
                    }
                    productRepository.save(product);
                }
            }
        }

        BigDecimal shippingFee = request.getShippingFee() != null ? request.getShippingFee() : BigDecimal.ZERO;
        BigDecimal discount = BigDecimal.ZERO;
        String couponCode = request.getCouponCode();
        if (couponCode != null && !couponCode.isBlank()) {
            ValidateCouponRequest validateReq = ValidateCouponRequest.builder()
                    .boutiqueId(request.getBoutiqueId())
                    .code(couponCode)
                    .orderAmount(subtotal)
                    .build();
            CouponValidationResponse validation = couponService.validateCoupon(validateReq);
            if (!validation.getValid()) {
                throw new RuntimeException(validation.getMessage());
            }
            discount = validation.getDiscountAmount();
        } else {
            discount = request.getDiscount() != null ? request.getDiscount() : BigDecimal.ZERO;
        }
        BigDecimal total = subtotal.add(shippingFee).subtract(discount);

        Order order = Order.builder()
                .boutique(boutique)
                .user(user)
                .customer(customer)
                .orderNumber(orderNumber)
                .status("PENDING")
                .subtotal(subtotal)
                .shippingFee(shippingFee)
                .discount(discount)
                .couponCode(couponCode)
                .total(total)
                .paymentMethod(request.getPaymentMethod())
                .paymentStatus("UNPAID")
                .shippingAddress(request.getShippingAddress())
                .notes(request.getNotes())
                .build();
        order = orderRepository.save(order);

        for (OrderItem item : items) {
            item.setOrder(order);
        }
        orderItemRepository.saveAll(items);
        invoiceService.generateInvoice(order.getId());

        try {
            String customerEmail = order.getCustomerEmail() != null ? order.getCustomerEmail()
                : (customer != null ? customer.getEmail() : request.getCustomerEmail());
            if (customerEmail != null && !customerEmail.isBlank()
                    && !Boolean.TRUE.equals(order.getConfirmationEmailSent())) {
                Invoice invoice = invoiceService.findByOrderId(order.getId());
                if (invoice != null) {
                    byte[] pdfBytes = invoicePdfService.generatePdf(order, boutique, invoice);
                    String subject = "Commande confirm\u00e9e - " + order.getOrderNumber();
                    StringBuilder itemsHtml = new StringBuilder();
                    for (OrderItem item : items) {
                        itemsHtml.append("<tr>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px\">").append(escapeHtml(item.getProductName())).append("</td>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px;text-align:center\">").append(item.getQuantity()).append("</td>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px;text-align:right\">").append(item.getUnitPrice().stripTrailingZeros().toPlainString()).append("</td>")
                            .append("<td style=\"padding:8px 12px;color:#374151;font-size:13px;text-align:right\">").append(item.getSubtotal().stripTrailingZeros().toPlainString()).append("</td>")
                            .append("</tr>");
                    }
                    String subtotalStr = order.getSubtotal().stripTrailingZeros().toPlainString();
                    String shippingFeeStr = order.getShippingFee().stripTrailingZeros().toPlainString();
                    String totalStr = order.getTotal().stripTrailingZeros().toPlainString();
                    String htmlBody = emailService.buildOrderConfirmationHtml(
                            boutique.getName(), order.getOrderNumber(),
                            order.getCustomerName() != null ? order.getCustomerName() : (customer != null ? customer.getFullName() : "Client"),
                            customerEmail,
                            order.getCustomerPhone() != null ? order.getCustomerPhone() : (customer != null ? customer.getPhone() : ""),
                            order.getShippingAddress(), order.getPaymentMethod(),
                            boutique.getCurrency(), itemsHtml.toString(),
                            subtotalStr, shippingFeeStr, totalStr);
                    emailService.sendOrderConfirmation(customerEmail, subject, htmlBody, pdfBytes,
                            "facture-" + order.getOrderNumber() + ".pdf");
                    order.setConfirmationEmailSent(true);
                    orderRepository.save(order);
                    log.info("Confirmation email queued for order {}", order.getOrderNumber());
                }
            }
        } catch (Exception e) {
            log.warn("Failed to send confirmation email for order {}: {}", order.getOrderNumber(), e.getMessage());
        }

        if (customer != null) {
            customerService.updateCustomerAggregation(customer, total);
        }

        User owner = boutique.getUser();
        String message = "Nouvelle commande " + orderNumber + " - " + total + " TND";
        notificationService.createNotification(owner.getId(), "Nouvelle commande", message, "NEW_ORDER");
        OrderResponse response = mapToResponse(order);
        webSocketService.sendNewOrderNotification(boutique.getId(), response);
        webSocketService.sendCaisseOrderUpdate(boutique.getId(), response);
        telegramNotificationService.notifyNewOrder(order);

        try {
            caisseService.recordActivity(boutique.getId(), user != null ? user.getId() : null,
                    user != null ? user.getFullName() : "Client", "ORDER_CREATED",
                    "Commande " + orderNumber + " créée - " + total + " TND");
        } catch (Exception e) {
            log.warn("Failed to record order activity: {}", e.getMessage());
        }

        return response;
    }

    @Transactional
    public OrderResponse updateStatus(UUID id, UpdateOrderStatusRequest request) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new RuntimeException("Commande non trouvée"));
        String oldStatus = order.getStatus();
        order.setStatus(request.getStatus());
        order = orderRepository.save(order);
        OrderResponse response = mapToResponse(order);

        webSocketService.sendCaisseOrderUpdate(order.getBoutique().getId(), response);

        if (!oldStatus.equals(request.getStatus())) {
            try {
                Boutique boutique = order.getBoutique();
                caisseService.recordActivity(boutique.getId(),
                        order.getUser() != null ? order.getUser().getId() : null,
                        order.getUser() != null ? order.getUser().getFullName() : "Syst\u00E8me",
                        "ORDER_STATUS_CHANGED",
                        "Commande " + order.getOrderNumber() + " : " + oldStatus + " \u2192 " + request.getStatus());
            } catch (Exception e) {
                log.warn("Failed to record status change activity: {}", e.getMessage());
            }
            telegramNotificationService.notifyOrderStatusChanged(order, oldStatus, request.getStatus());
        }

        return response;
    }

    @Transactional
    public OrderResponse updatePayment(UUID id, UpdatePaymentStatusRequest request) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new RuntimeException("Commande non trouvée"));
        if (request.getPaymentStatus() != null) order.setPaymentStatus(request.getPaymentStatus());
        if (request.getPaymentRef() != null) order.setPaymentRef(request.getPaymentRef());
        order = orderRepository.save(order);
        return mapToResponse(order);
    }

    @Transactional
    public OrderResponse updateTracking(UUID id, UpdateTrackingRequest request) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new RuntimeException("Commande non trouvée"));

        if (request.getDeliveryCompany() != null && request.getDeliveryCompany().trim().isEmpty()) {
            throw new RuntimeException("Société de livraison requise");
        }
        if (request.getTrackingNumber() != null && request.getTrackingNumber().trim().isEmpty()) {
            throw new RuntimeException("Numéro de suivi requis");
        }
        if (request.getDeliveryStatus() != null && request.getDeliveryStatus().trim().isEmpty()) {
            throw new RuntimeException("Statut de livraison invalide");
        }

        if (request.getDeliveryCompany() != null) order.setDeliveryCompany(request.getDeliveryCompany());
        if (request.getTrackingNumber() != null) order.setTrackingNumber(request.getTrackingNumber());
        if (request.getDeliveryStatus() != null) order.setDeliveryStatus(request.getDeliveryStatus());
        order = orderRepository.save(order);
        return mapToResponse(order);
    }

    @Transactional
    public OrderResponse refundOrder(UUID id) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new RuntimeException("Commande non trouvée"));
        if (!"PAID".equals(order.getPaymentStatus())) {
            throw new RuntimeException("Seules les commandes payées peuvent être remboursées");
        }
        order.setStatus("REFUNDED");
        order.setPaymentStatus("REFUNDED");
        order = orderRepository.save(order);
        return mapToResponse(order);
    }

    @Transactional
    public void deleteOrder(UUID id) {
        orderRepository.deleteById(id);
    }

    @Transactional(readOnly = true)
    public String exportCsv(UUID boutiqueId) {
        List<Order> orders = orderRepository.findByBoutiqueId(boutiqueId, Pageable.unpaged()).getContent();
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append("Numéro,Client,Total,Statut,Paiement,Date\n");
        for (Order o : orders) {
            sb.append(CsvUtil.escapeCsv(o.getOrderNumber())).append(",")
                    .append(CsvUtil.escapeCsv(o.getCustomer() != null ? o.getCustomer().getFullName() : "")).append(",")
                    .append(o.getTotal()).append(",")
                    .append(CsvUtil.escapeCsv(o.getStatus())).append(",")
                    .append(CsvUtil.escapeCsv(o.getPaymentStatus())).append(",")
                    .append(o.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    private String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private OrderResponse mapToResponse(Order o) {
        List<OrderItem> items = orderItemRepository.findByOrderId(o.getId());
        return OrderResponse.builder()
                .id(o.getId()).boutiqueId(o.getBoutique().getId())
                .userId(o.getUser() != null ? o.getUser().getId() : null)
                .customerId(o.getCustomer() != null ? o.getCustomer().getId() : null)
                .customerName(o.getCustomer() != null ? o.getCustomer().getFullName()
                    : (o.getCustomerName() != null ? o.getCustomerName() : "Client inconnu"))
                .customerPhone(o.getCustomer() != null ? o.getCustomer().getPhone() : o.getCustomerPhone())
                .customerEmail(o.getCustomer() != null ? o.getCustomer().getEmail() : o.getCustomerEmail())
                .orderNumber(o.getOrderNumber()).status(o.getStatus())
                .subtotal(o.getSubtotal()).shippingFee(o.getShippingFee())
                .discount(o.getDiscount()).couponCode(o.getCouponCode()).total(o.getTotal())
                .paymentMethod(o.getPaymentMethod()).paymentStatus(o.getPaymentStatus())
                .paymentRef(o.getPaymentRef()).shippingAddress(o.getShippingAddress())
                .city(o.getCity())
                .deliveryCompany(o.getDeliveryCompany()).trackingNumber(o.getTrackingNumber())
                .deliveryStatus(o.getDeliveryStatus())
                .notes(o.getNotes()).invoiceNumber(o.getInvoiceNumber())
                .invoiceCreatedAt(o.getInvoiceCreatedAt()).createdAt(o.getCreatedAt())
                .items(items.stream().map(i -> OrderItemResponse.builder()
                        .id(i.getId()).productId(i.getProduct() != null ? i.getProduct().getId() : null)
                        .productName(i.getProductName()).unitPrice(i.getUnitPrice())
                        .quantity(i.getQuantity()).subtotal(i.getSubtotal())
                        .build()).collect(Collectors.toList()))
                .build();
    }
}
