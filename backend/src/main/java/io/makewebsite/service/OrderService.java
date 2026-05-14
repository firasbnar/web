package io.makewebsite.service;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
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

    @Transactional(readOnly = true)
    public Page<OrderResponse> getOrders(UUID boutiqueId, String status, String search, Pageable pageable) {
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

            items.add(OrderItem.builder()
                    .product(product)
                    .productName(itemReq.getProductName())
                    .unitPrice(itemReq.getUnitPrice())
                    .quantity(itemReq.getQuantity())
                    .subtotal(itemSubtotal)
                    .build());
        }

        BigDecimal shippingFee = request.getShippingFee() != null ? request.getShippingFee() : BigDecimal.ZERO;
        BigDecimal discount = request.getDiscount() != null ? request.getDiscount() : BigDecimal.ZERO;
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

        if (customer != null) {
            customerService.updateCustomerAggregation(customer, total);
        }

        User owner = boutique.getUser();
        String message = "Nouvelle commande " + orderNumber + " - " + total + " TND";
        notificationService.createNotification(owner.getId(), "Nouvelle commande", message, "NEW_ORDER");
        webSocketService.sendNewOrderNotification(boutique.getId(), mapToResponse(order));
        telegramService.sendMessage(owner.getTelegramChatId(), message);

        return mapToResponse(order);
    }

    @Transactional
    public OrderResponse updateStatus(UUID id, UpdateOrderStatusRequest request) {
        Order order = orderRepository.findById(id).orElseThrow(() -> new RuntimeException("Commande non trouvée"));
        order.setStatus(request.getStatus());
        order = orderRepository.save(order);
        return mapToResponse(order);
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
        if (request.getDeliveryCompany() != null) order.setDeliveryCompany(request.getDeliveryCompany());
        if (request.getTrackingNumber() != null) order.setTrackingNumber(request.getTrackingNumber());
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
        StringBuilder sb = new StringBuilder("Numéro,Client,Total,Statut,Paiement,Date\n");
        for (Order o : orders) {
            sb.append(o.getOrderNumber()).append(",")
                    .append(o.getCustomer() != null ? o.getCustomer().getFullName() : "").append(",")
                    .append(o.getTotal()).append(",")
                    .append(o.getStatus()).append(",")
                    .append(o.getPaymentStatus()).append(",")
                    .append(o.getCreatedAt()).append("\n");
        }
        return sb.toString();
    }

    private OrderResponse mapToResponse(Order o) {
        List<OrderItem> items = orderItemRepository.findByOrderId(o.getId());
        return OrderResponse.builder()
                .id(o.getId()).boutiqueId(o.getBoutique().getId())
                .userId(o.getUser() != null ? o.getUser().getId() : null)
                .customerId(o.getCustomer() != null ? o.getCustomer().getId() : null)
                .customerName(o.getCustomer() != null ? o.getCustomer().getFullName() : "Client inconnu")
                .orderNumber(o.getOrderNumber()).status(o.getStatus())
                .subtotal(o.getSubtotal()).shippingFee(o.getShippingFee())
                .discount(o.getDiscount()).total(o.getTotal())
                .paymentMethod(o.getPaymentMethod()).paymentStatus(o.getPaymentStatus())
                .paymentRef(o.getPaymentRef()).shippingAddress(o.getShippingAddress())
                .deliveryCompany(o.getDeliveryCompany()).trackingNumber(o.getTrackingNumber())
                .notes(o.getNotes()).createdAt(o.getCreatedAt())
                .items(items.stream().map(i -> OrderItemResponse.builder()
                        .id(i.getId()).productId(i.getProduct() != null ? i.getProduct().getId() : null)
                        .productName(i.getProductName()).unitPrice(i.getUnitPrice())
                        .quantity(i.getQuantity()).subtotal(i.getSubtotal())
                        .build()).collect(Collectors.toList()))
                .build();
    }
}
