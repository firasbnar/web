package io.makewebsite.service;

import io.makewebsite.entity.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class TelegramNotificationService {

    private final TelegramService telegramService;

    @Value("${telegram.low-stock-threshold:5}")
    private int lowStockThreshold;

    public void notifyNewOrder(Order order) {
        User owner = order.getBoutique().getUser();
        if (!canNotify(owner)) return;
        String msg = "\uD83D\uDCE6 <b>Nouvelle commande re\u00E7ue</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + order.getBoutique().getName() + "\n"
                + "\uD83E\uDDFE Commande : #" + order.getOrderNumber() + "\n"
                + "\uD83D\uDC64 Client : " + (order.getCustomer() != null ? order.getCustomer().getFullName() : order.getCustomerName()) + "\n"
                + "\uD83D\uDCB0 Total : " + order.getTotal() + " TND\n"
                + "\uD83D\uDCB3 R\u00E8glement : " + order.getPaymentMethod() + "\n"
                + "\uD83D\uDCCC Statut : " + order.getStatus();
        send(owner, msg);
    }

    public void notifyOrderStatusChanged(Order order, String oldStatus, String newStatus) {
        User owner = order.getBoutique().getUser();
        if (!canNotify(owner)) return;
        String msg = "\uD83D\uDD04 <b>Statut de commande modifi\u00E9</b>\n\n"
                + "\uD83E\uDDFE Commande : #" + order.getOrderNumber() + "\n"
                + "\uD83D\uDCE2 Ancien statut : " + oldStatus + "\n"
                + "\uD83C\uDFAF Nouveau statut : " + newStatus;
        send(owner, msg);
    }

    public void notifyLowStock(Product product, int remaining) {
        User owner = product.getBoutique().getUser();
        if (!canNotify(owner)) return;
        String msg = "\u26A0\uFE0F <b>Stock faible</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + product.getBoutique().getName() + "\n"
                + "\uD83D\uDCE6 Produit : " + product.getName() + "\n"
                + "\uD83D\uDD22 Stock restant : " + remaining;
        send(owner, msg);
    }

    public void notifyOutOfStock(Product product) {
        User owner = product.getBoutique().getUser();
        if (!canNotify(owner)) return;
        String msg = "\uD83D\uDED1 <b>Rupture de stock</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + product.getBoutique().getName() + "\n"
                + "\uD83D\uDCE6 Produit : " + product.getName() + "\n"
                + "\uD83D\uDD22 Stock restant : 0";
        send(owner, msg);
    }

    public void notifyNewCustomer(Customer customer) {
        User owner = customer.getBoutique().getUser();
        if (!canNotify(owner)) return;
        String msg = "\uD83D\uDC65 <b>Nouveau client</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + customer.getBoutique().getName() + "\n"
                + "\uD83D\uDC64 Nom : " + customer.getFullName()
                + (customer.getEmail() != null ? "\n\uD83D\uDCE7 Email : " + customer.getEmail() : "")
                + (customer.getPhone() != null ? "\n\uD83D\uDCDE T\u00E9l\u00E9phone : " + customer.getPhone() : "");
        send(owner, msg);
    }

    public void notifyNewReview(Review review) {
        Boutique boutique = review.getBoutique();
        if (boutique == null) return;
        User owner = boutique.getUser();
        if (!canNotify(owner)) return;
        String stars = "\u2B50".repeat(Math.min(review.getRating() != null ? review.getRating() : 0, 5));
        String msg = "\uD83D\uDCDD <b>Nouvel avis</b>\n\n"
                + "\u2B50 Note : " + review.getRating() + "/5 " + stars + "\n"
                + "\uD83D\uDCE6 Produit : " + (review.getProduct() != null ? review.getProduct().getName() : "\u2014") + "\n"
                + "\uD83D\uDC64 Client : " + review.getCustomerName()
                + (review.getComment() != null && !review.getComment().isBlank()
                    ? "\n\uD83D\uDCAC Avis : " + review.getComment() : "")
                + "\n\uD83D\uDCCC Statut : " + review.getStatus();
        send(owner, msg);
    }

    public void notifyBoutiqueFrozen(Boutique boutique, String reason) {
        User owner = boutique.getUser();
        if (!canNotify(owner)) return;
        String msg = "\u26A0\uFE0F <b>Boutique gel\u00E9e</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + boutique.getName() + "\n"
                + "\uD83D\uDCC4 Motif : " + reason;
        send(owner, msg);
    }

    public void notifyPaymentValidated(Order order, String paymentMethod, String paymentRef) {
        User owner = order.getBoutique().getUser();
        if (!canNotify(owner)) return;
        String msg = "\u2705 <b>Paiement confirm\u00E9</b>\n\n"
                + "\uD83E\uDDFE Commande : #" + order.getOrderNumber() + "\n"
                + "\uD83D\uDCB0 Montant : " + order.getTotal() + " TND\n"
                + "\uD83D\uDCB3 Moyen : " + paymentMethod
                + (paymentRef != null ? "\n\uD83D\uDCCB R\u00E9f\u00E9rence : " + paymentRef : "");
        send(owner, msg);
    }

    public void notifyTeamMemberInvited(Boutique boutique, String invitedEmail, String role) {
        User owner = boutique.getUser();
        if (!canNotify(owner)) return;
        String msg = "\uD83D\uDC65 <b>Nouveau membre d'\u00E9quipe</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + boutique.getName() + "\n"
                + "\uD83D\uDCE7 Email : " + invitedEmail + "\n"
                + "\uD83D\uDC68\u200D\uD83D\uDCBB R\u00F4le : " + role;
        send(owner, msg);
    }

    public void notifyNewCustomerMessage(Conversation conversation, String content) {
        Boutique boutique = conversation.getBoutique();
        User owner = boutique.getUser();
        if (!canNotify(owner)) return;
        String preview = content.length() > 80 ? content.substring(0, 80) + "..." : content;
        String msg = "\uD83D\uDCAC <b>Nouveau message client</b>\n\n"
                + "\uD83C\uDFEA Boutique : " + boutique.getName() + "\n"
                + "\uD83D\uDC64 De : " + conversation.getCustomerName() + "\n"
                + "\uD83D\uDCDD Message : " + preview;
        send(owner, msg);
    }

    private boolean canNotify(User user) {
        return user != null
                && Boolean.TRUE.equals(user.getTelegramEnabled())
                && user.getTelegramChatId() != null
                && !user.getTelegramChatId().trim().isEmpty();
    }

    private void send(User user, String message) {
        try {
            telegramService.sendMessage(user.getTelegramChatId(), message);
        } catch (Exception e) {
            log.warn("Failed to send Telegram notification to user {}: {}", user.getId(), e.getMessage());
        }
    }
}
