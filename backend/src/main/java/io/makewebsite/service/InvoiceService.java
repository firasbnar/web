package io.makewebsite.service;

import io.makewebsite.dto.response.InvoiceResponse;
import io.makewebsite.dto.response.OrderItemResponse;
import io.makewebsite.entity.Boutique;
import io.makewebsite.entity.Customer;
import io.makewebsite.entity.Invoice;
import io.makewebsite.entity.Order;
import io.makewebsite.entity.OrderItem;
import io.makewebsite.repository.BoutiqueRepository;
import io.makewebsite.repository.InvoiceRepository;
import io.makewebsite.repository.OrderItemRepository;
import io.makewebsite.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class InvoiceService {

    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final InvoiceRepository invoiceRepository;

    @Transactional
    public String generateInvoice(UUID orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Commande non trouvee"));

        return createInvoiceIfMissing(order).getInvoiceNumber();
    }

    @Transactional
    public InvoiceResponse getInvoice(UUID boutiqueId, UUID orderId) {
        Invoice invoice = findOrCreateInvoice(boutiqueId, orderId);
        return mapToResponse(invoice);
    }

    @Transactional
    public String buildInvoiceHtml(UUID orderId) {
        Invoice invoice = invoiceRepository.findByOrderId(orderId).orElseGet(() -> {
            Order order = orderRepository.findById(orderId)
                    .orElseThrow(() -> new RuntimeException("Commande non trouvee"));
            return createInvoiceIfMissing(order);
        });
        return buildInvoiceHtml(invoice);
    }

    @Transactional
    public String buildInvoiceHtml(UUID boutiqueId, UUID orderId) {
        Invoice invoice = findOrCreateInvoice(boutiqueId, orderId);
        return buildInvoiceHtml(invoice);
    }

    private Invoice findOrCreateInvoice(UUID boutiqueId, UUID orderId) {
        return invoiceRepository.findByOrderIdAndBoutiqueId(orderId, boutiqueId).orElseGet(() -> {
            Order order = orderRepository.findById(orderId)
                    .orElseThrow(() -> new RuntimeException("Commande non trouvee"));
            if (!order.getBoutique().getId().equals(boutiqueId)) {
                throw new RuntimeException("Facture non trouvee");
            }
            return createInvoiceIfMissing(order);
        });
    }

    private Invoice createInvoiceIfMissing(Order order) {
        Invoice existing = invoiceRepository.findByOrderId(order.getId()).orElse(null);
        if (existing != null) {
            syncOrderInvoiceFields(order, existing.getInvoiceNumber(), existing.getCreatedAt());
            return existing;
        }

        Boutique boutique = order.getBoutique();
        String invoiceNumber = order.getInvoiceNumber();
        LocalDateTime invoiceCreatedAt = order.getInvoiceCreatedAt();

        if (invoiceNumber == null || invoiceNumber.isBlank()) {
            long seq = boutique.getInvoiceSequence() != null ? boutique.getInvoiceSequence() + 1 : 1;
            boutique.setInvoiceSequence(seq);
            boutiqueRepository.save(boutique);

            String datePart = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
            invoiceNumber = "INV-" + datePart + "-" + String.format("%04d", seq);
            invoiceCreatedAt = LocalDateTime.now();
        }

        syncOrderInvoiceFields(order, invoiceNumber, invoiceCreatedAt);

        Invoice invoice = Invoice.builder()
                .user(boutique.getUser())
                .boutique(boutique)
                .order(order)
                .invoiceNumber(invoiceNumber)
                .amount(value(order.getTotal()))
                .currency(currency(boutique))
                .status("ISSUED")
                .paymentMethod(order.getPaymentMethod())
                .paymentRef(order.getPaymentRef())
                .invoiceData(buildInvoiceData(order, invoiceNumber))
                .build();

        Invoice saved = invoiceRepository.save(invoice);
        log.info("Invoice {} created for order {}", invoiceNumber, order.getOrderNumber());
        return saved;
    }

    private void syncOrderInvoiceFields(Order order, String invoiceNumber, LocalDateTime invoiceCreatedAt) {
        order.setInvoiceNumber(invoiceNumber);
        order.setInvoiceCreatedAt(invoiceCreatedAt != null ? invoiceCreatedAt : LocalDateTime.now());
        orderRepository.save(order);
    }

    private Map<String, Object> buildInvoiceData(Order order, String invoiceNumber) {
        Boutique boutique = order.getBoutique();
        Customer customer = order.getCustomer();
        List<OrderItem> items = orderItemRepository.findByOrderId(order.getId());

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("invoiceNumber", invoiceNumber);
        data.put("orderId", order.getId().toString());
        data.put("orderNumber", order.getOrderNumber());
        data.put("currency", currency(boutique));
        data.put("subtotal", value(order.getSubtotal()));
        data.put("shippingFee", value(order.getShippingFee()));
        data.put("discount", value(order.getDiscount()));
        data.put("total", value(order.getTotal()));
        data.put("paymentMethod", order.getPaymentMethod());
        data.put("paymentStatus", order.getPaymentStatus());

        Map<String, Object> boutiqueData = new LinkedHashMap<>();
        boutiqueData.put("id", boutique.getId().toString());
        boutiqueData.put("name", boutique.getName());
        boutiqueData.put("email", boutique.getEmail());
        boutiqueData.put("phone", boutique.getPhone());
        boutiqueData.put("address", boutique.getAddress());
        data.put("boutique", boutiqueData);

        Map<String, Object> customerData = new LinkedHashMap<>();
        customerData.put("name", customer != null ? customer.getFullName() : "Client");
        customerData.put("email", customer != null ? customer.getEmail() : null);
        customerData.put("phone", customer != null ? customer.getPhone() : null);
        customerData.put("shippingAddress", order.getShippingAddress());
        data.put("customer", customerData);

        data.put("items", items.stream().map(item -> {
            Map<String, Object> itemData = new LinkedHashMap<>();
            itemData.put("productId", item.getProduct() != null ? item.getProduct().getId().toString() : null);
            itemData.put("productName", item.getProductName());
            itemData.put("unitPrice", value(item.getUnitPrice()));
            itemData.put("quantity", item.getQuantity());
            itemData.put("subtotal", value(item.getSubtotal()));
            return itemData;
        }).collect(Collectors.toList()));

        return data;
    }

    private InvoiceResponse mapToResponse(Invoice invoice) {
        Order order = invoice.getOrder();
        Boutique boutique = invoice.getBoutique();
        Customer customer = order != null ? order.getCustomer() : null;
        List<OrderItem> items = order != null ? orderItemRepository.findByOrderId(order.getId()) : List.of();

        return InvoiceResponse.builder()
                .id(invoice.getId())
                .userId(invoice.getUser() != null ? invoice.getUser().getId() : null)
                .subscriptionId(invoice.getSubscription() != null ? invoice.getSubscription().getId() : null)
                .boutiqueId(boutique != null ? boutique.getId() : null)
                .boutiqueName(boutique != null ? boutique.getName() : null)
                .boutiqueEmail(boutique != null ? boutique.getEmail() : null)
                .boutiquePhone(boutique != null ? boutique.getPhone() : null)
                .boutiqueAddress(boutique != null ? boutique.getAddress() : null)
                .orderId(order != null ? order.getId() : null)
                .orderNumber(order != null ? order.getOrderNumber() : null)
                .invoiceNumber(invoice.getInvoiceNumber())
                .invoiceCreatedAt(order != null ? order.getInvoiceCreatedAt() : invoice.getCreatedAt())
                .customerName(customer != null ? customer.getFullName() : "Client")
                .customerEmail(customer != null ? customer.getEmail() : null)
                .customerPhone(customer != null ? customer.getPhone() : null)
                .shippingAddress(order != null ? order.getShippingAddress() : null)
                .subtotal(order != null ? value(order.getSubtotal()) : null)
                .shippingFee(order != null ? value(order.getShippingFee()) : null)
                .discount(order != null ? value(order.getDiscount()) : null)
                .total(order != null ? value(order.getTotal()) : invoice.getAmount())
                .amount(invoice.getAmount())
                .currency(invoice.getCurrency())
                .status(invoice.getStatus())
                .paymentMethod(invoice.getPaymentMethod())
                .paymentRef(invoice.getPaymentRef())
                .paymentStatus(order != null ? order.getPaymentStatus() : null)
                .createdAt(invoice.getCreatedAt())
                .items(items.stream().map(item -> OrderItemResponse.builder()
                        .id(item.getId())
                        .productId(item.getProduct() != null ? item.getProduct().getId() : null)
                        .productName(item.getProductName())
                        .unitPrice(item.getUnitPrice())
                        .quantity(item.getQuantity())
                        .subtotal(item.getSubtotal())
                        .build()).collect(Collectors.toList()))
                .build();
    }

    private String buildInvoiceHtml(Invoice invoice) {
        Order order = invoice.getOrder();
        if (order == null) {
            throw new RuntimeException("Facture non liee a une commande");
        }

        Boutique boutique = invoice.getBoutique();
        Customer customer = order.getCustomer();
        List<OrderItem> items = orderItemRepository.findByOrderId(order.getId());
        String currency = currency(boutique);

        StringBuilder rows = new StringBuilder();
        int index = 1;
        for (OrderItem item : items) {
            rows.append("<tr>")
                    .append("<td class=\"center\">").append(index++).append("</td>")
                    .append("<td>").append(escape(item.getProductName())).append("</td>")
                    .append("<td class=\"center\">").append(item.getQuantity() != null ? item.getQuantity() : 0).append("</td>")
                    .append("<td class=\"right\">").append(money(item.getUnitPrice())).append(" ").append(escape(currency)).append("</td>")
                    .append("<td class=\"right\">").append(money(item.getSubtotal())).append(" ").append(escape(currency)).append("</td>")
                    .append("</tr>");
        }

        String paid = "PAID".equalsIgnoreCase(order.getPaymentStatus()) ? "Payee" : "Non payee";
        String issuedAt = order.getInvoiceCreatedAt() != null
                ? order.getInvoiceCreatedAt().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"))
                : "";

        String discountRow = value(order.getDiscount()).compareTo(BigDecimal.ZERO) > 0
                ? "<div class=\"total-row\"><span>Remise</span><strong>-" + money(order.getDiscount()) + " " + escape(currency) + "</strong></div>"
                : "";

        return """
                <!DOCTYPE html>
                <html lang="fr">
                <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Facture ${invoiceNumber}</title>
                  <style>
                    * { box-sizing: border-box; }
                    body { margin: 0; padding: 32px; font-family: Arial, sans-serif; color: #172033; background: #f4f6fb; font-size: 13px; }
                    .invoice { max-width: 900px; margin: 0 auto; background: #ffffff; padding: 36px; border: 1px solid #dde3ef; }
                    .top { display: flex; justify-content: space-between; gap: 32px; border-bottom: 3px solid #2710BF; padding-bottom: 22px; }
                    h1 { margin: 0; color: #2710BF; font-size: 28px; letter-spacing: 0; }
                    h2 { margin: 0 0 8px; color: #172033; font-size: 16px; }
                    p { margin: 3px 0; color: #536176; }
                    .meta { text-align: right; }
                    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; margin: 28px 0; }
                    .box { border: 1px solid #e5eaf3; padding: 16px; background: #fbfcff; }
                    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
                    th { background: #2710BF; color: #ffffff; padding: 12px; text-align: left; font-size: 12px; }
                    td { padding: 12px; border-bottom: 1px solid #edf1f7; }
                    .center { text-align: center; }
                    .right { text-align: right; }
                    .totals { width: 340px; margin-left: auto; margin-top: 22px; }
                    .total-row { display: flex; justify-content: space-between; padding: 7px 0; border-bottom: 1px solid #edf1f7; }
                    .grand { color: #2710BF; font-size: 18px; font-weight: 700; border-bottom: 0; }
                    .footer { text-align: center; margin-top: 36px; padding-top: 18px; border-top: 1px solid #dde3ef; color: #7a8798; }
                    .actions { max-width: 900px; margin: 16px auto; text-align: right; }
                    button { background: #2710BF; color: #ffffff; border: 0; padding: 10px 16px; cursor: pointer; font-weight: 700; }
                    @media print {
                      body { padding: 0; background: #ffffff; }
                      .invoice { max-width: none; border: 0; padding: 20px; }
                      .actions { display: none; }
                    }
                  </style>
                </head>
                <body>
                  <div class="actions"><button onclick="window.print()">Imprimer</button></div>
                  <main class="invoice">
                    <section class="top">
                      <div>
                        <h1>FACTURE</h1>
                        <p>${invoiceNumber}</p>
                      </div>
                      <div class="meta">
                        <h2>${boutiqueName}</h2>
                        <p>${boutiqueEmail}</p>
                        <p>${boutiquePhone}</p>
                        <p>${boutiqueAddress}</p>
                      </div>
                    </section>
                    <section class="grid">
                      <div class="box">
                        <h2>Client</h2>
                        <p>${customerName}</p>
                        <p>${customerEmail}</p>
                        <p>${customerPhone}</p>
                        <p>${shippingAddress}</p>
                      </div>
                      <div class="box">
                        <h2>Commande</h2>
                        <p>Numero: ${orderNumber}</p>
                        <p>Date facture: ${issuedAt}</p>
                        <p>Paiement: ${paymentMethod}</p>
                        <p>Statut: ${paid}</p>
                      </div>
                    </section>
                    <table>
                      <thead>
                        <tr>
                          <th class="center">#</th>
                          <th>Article</th>
                          <th class="center">Qte</th>
                          <th class="right">P.U</th>
                          <th class="right">Total</th>
                        </tr>
                      </thead>
                      <tbody>${rows}</tbody>
                    </table>
                    <section class="totals">
                      <div class="total-row"><span>Sous-total</span><strong>${subtotal} ${currency}</strong></div>
                      <div class="total-row"><span>Livraison</span><strong>${shippingFee} ${currency}</strong></div>
                      ${discountRow}
                      <div class="total-row grand"><span>Total</span><strong>${total} ${currency}</strong></div>
                    </section>
                    <section class="footer">
                      <p>Merci de votre confiance.</p>
                      <p>Genere le ${generatedAt}</p>
                    </section>
                  </main>
                  <script>
                    window.addEventListener('load', function () {
                      setTimeout(function () { window.print(); }, 350);
                    });
                  </script>
                </body>
                </html>
                """
                .replace("${invoiceNumber}", escape(invoice.getInvoiceNumber()))
                .replace("${boutiqueName}", escape(boutique != null ? boutique.getName() : "Boutique"))
                .replace("${boutiqueEmail}", escape(boutique != null ? boutique.getEmail() : ""))
                .replace("${boutiquePhone}", escape(boutique != null ? boutique.getPhone() : ""))
                .replace("${boutiqueAddress}", escape(boutique != null ? boutique.getAddress() : ""))
                .replace("${customerName}", escape(customer != null ? customer.getFullName() : "Client"))
                .replace("${customerEmail}", escape(customer != null ? customer.getEmail() : ""))
                .replace("${customerPhone}", escape(customer != null ? customer.getPhone() : ""))
                .replace("${shippingAddress}", escape(order.getShippingAddress()))
                .replace("${orderNumber}", escape(order.getOrderNumber()))
                .replace("${issuedAt}", escape(issuedAt))
                .replace("${paymentMethod}", escape(order.getPaymentMethod()))
                .replace("${paid}", escape(paid))
                .replace("${rows}", rows.toString())
                .replace("${subtotal}", money(order.getSubtotal()))
                .replace("${shippingFee}", money(order.getShippingFee()))
                .replace("${discountRow}", discountRow)
                .replace("${total}", money(order.getTotal()))
                .replace("${currency}", escape(currency))
                .replace("${generatedAt}", LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")));
    }

    private String currency(Boutique boutique) {
        return boutique != null && boutique.getCurrency() != null && !boutique.getCurrency().isBlank()
                ? boutique.getCurrency()
                : "TND";
    }

    private BigDecimal value(BigDecimal value) {
        return value != null ? value : BigDecimal.ZERO;
    }

    private String money(BigDecimal value) {
        return value(value).setScale(3, RoundingMode.HALF_UP).toPlainString();
    }

    private String escape(String value) {
        if (value == null) return "";
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }
}
