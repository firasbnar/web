package io.makewebsite.service;

import io.makewebsite.dto.request.AddToCartRequest;
import io.makewebsite.dto.request.UpdateCartItemRequest;
import io.makewebsite.dto.response.CartItemResponse;
import io.makewebsite.dto.response.CartResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CartService {
    private final CartRepository cartRepository;
    private final CartItemRepository cartItemRepository;
    private final UserRepository userRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;

    @Transactional(readOnly = true)
    public CartResponse getCart(UUID userId, UUID boutiqueId) {
        Cart cart = cartRepository.findByUserIdAndBoutiqueId(userId, boutiqueId)
                .orElse(null);
        if (cart == null) {
            return CartResponse.builder()
                    .boutiqueId(boutiqueId).items(List.of())
                    .itemCount(0).subtotal(BigDecimal.ZERO)
                    .build();
        }
        return mapToResponse(cart);
    }

    @Transactional
    public CartResponse addItem(UUID userId, AddToCartRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Boutique boutique = boutiqueRepository.findById(request.getBoutiqueId())
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        Product product = productRepository.findById(request.getProductId())
                .orElseThrow(() -> new RuntimeException("Produit non trouvé"));

        Cart cart = cartRepository.findByUserIdAndBoutiqueId(userId, request.getBoutiqueId())
                .orElseGet(() -> cartRepository.save(Cart.builder()
                        .user(user).boutique(boutique).build()));

        cartItemRepository.findByCartIdAndProductId(cart.getId(), request.getProductId())
                .ifPresentOrElse(
                        item -> {
                            item.setQuantity(item.getQuantity() + request.getQuantity());
                            cartItemRepository.save(item);
                        },
                        () -> cartItemRepository.save(CartItem.builder()
                                .cart(cart)
                                .product(product)
                                .quantity(request.getQuantity())
                                .unitPrice(product.getPrice())
                                .build()));

        return mapToResponse(cart);
    }

    @Transactional
    public CartResponse updateItem(UUID userId, UUID itemId, UpdateCartItemRequest request) {
        CartItem item = cartItemRepository.findById(itemId)
                .orElseThrow(() -> new RuntimeException("Article non trouvé dans le panier"));
        item.setQuantity(request.getQuantity());
        cartItemRepository.save(item);
        return mapToResponse(item.getCart());
    }

    @Transactional
    public CartResponse removeItem(UUID userId, UUID itemId) {
        CartItem item = cartItemRepository.findById(itemId)
                .orElseThrow(() -> new RuntimeException("Article non trouvé dans le panier"));
        Cart cart = item.getCart();
        cartItemRepository.delete(item);
        return mapToResponse(cart);
    }

    @Transactional
    public void clearCart(UUID userId, UUID boutiqueId) {
        cartRepository.findByUserIdAndBoutiqueId(userId, boutiqueId)
                .ifPresent(cart -> cartItemRepository.deleteByCartId(cart.getId()));
    }

    private CartResponse mapToResponse(Cart cart) {
        List<CartItem> items = cartItemRepository.findByCartId(cart.getId());
        BigDecimal subtotal = items.stream()
                .map(i -> i.getUnitPrice().multiply(BigDecimal.valueOf(i.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        return CartResponse.builder()
                .id(cart.getId())
                .boutiqueId(cart.getBoutique().getId())
                .boutiqueName(cart.getBoutique().getName())
                .items(items.stream().map(i -> CartItemResponse.builder()
                        .id(i.getId())
                        .productId(i.getProduct().getId())
                        .productName(i.getProduct().getName())
                        .productImage(extractFirstImage(i.getProduct().getImages()))
                        .unitPrice(i.getUnitPrice())
                        .quantity(i.getQuantity())
                        .subtotal(i.getUnitPrice().multiply(BigDecimal.valueOf(i.getQuantity())))
                        .availableStock(i.getProduct().getStock())
                        .build()).collect(Collectors.toList()))
                .itemCount(items.size())
                .subtotal(subtotal)
                .build();
    }

    private String extractFirstImage(String images) {
        if (images == null || images.isBlank() || images.equals("[]")) return null;
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
        } catch (Exception e) {
            return null;
        }
    }
}
