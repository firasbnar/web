package io.makewebsite.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.GenericGenerator;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "store_language")
public class StoreLanguage {
    @Id
    @GeneratedValue(generator = "UUID")
    @GenericGenerator(name = "UUID", strategy = "org.hibernate.id.UUIDGenerator")
    @Column(updatable = false)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "boutique_id", nullable = false, unique = true)
    private Boutique boutique;

    @Builder.Default @Column(name = "add_to_cart") private String addToCart = "Ajouter au panier";
    @Builder.Default @Column(name = "checkout_title") private String checkoutTitle = "Commande";
    @Builder.Default @Column(name = "total_price_label") private String totalPriceLabel = "Prix Total :";
    @Builder.Default @Column(name = "shipping_cost_label") private String shippingCostLabel = "Frais de livraison";
    @Builder.Default @Column(name = "grand_total_label") private String grandTotalLabel = "Total Général";
    @Builder.Default @Column(name = "full_name_placeholder") private String fullNamePlaceholder = "Entrez votre nom complet";
    @Builder.Default @Column(name = "email_placeholder") private String emailPlaceholder = "Entrez votre e-mail";
    @Builder.Default @Column(name = "billing_address_placeholder") private String billingAddressPlaceholder = "Entrez votre adresse de livraison";
    @Builder.Default @Column(name = "city_placeholder") private String cityPlaceholder = "Sélectionnez votre gouvernorat";
    @Builder.Default @Column(name = "phone_placeholder") private String phonePlaceholder = "Entrez votre numéro de téléphone";
    @Builder.Default @Column(name = "payment_method_label") private String paymentMethodLabel = "Méthode de paiement :";
    @Builder.Default @Column(name = "place_order_button") private String placeOrderButton = "Passer la commande";
    @Builder.Default @Column(name = "no_products") private String noProducts = "Aucun produit disponible pour le moment.";
    @Builder.Default @Column(name = "footer_text") private String footerText = "Tous droits réservés.";
    @Builder.Default @Column(name = "order_confirmation_title") private String orderConfirmationTitle = "Confirmation de commande";
    @Builder.Default @Column(name = "search_products") private String searchProducts = "Rechercher des produits...";
    @Builder.Default @Column(name = "see_all") private String seeAll = "Voir tout";
    @Builder.Default @Column(name = "cash_on_delivery") private String cashOnDelivery = "Paiement à la livraison";
    @Builder.Default @Column(name = "follow_us") private String followUs = "Suivez-nous";
    @Builder.Default @Column(name = "support") private String support = "Support";
    @Builder.Default @Column(name = "menu_label") private String menuLabel = "Menu";
    @Builder.Default @Column(name = "cart_title") private String cartTitle = "Panier";
    @Builder.Default @Column(name = "select_country") private String selectCountry = "Sélectionnez votre pays";
}
