package io.makewebsite.service;

import io.makewebsite.dto.response.WishlistItemResponse;
import io.makewebsite.entity.Product;
import io.makewebsite.entity.User;
import io.makewebsite.entity.WishlistItem;
import io.makewebsite.repository.ProductRepository;
import io.makewebsite.repository.UserRepository;
import io.makewebsite.repository.WishlistItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class WishlistService {
    private final WishlistItemRepository wishlistItemRepository;
    private final UserRepository userRepository;
    private final ProductRepository productRepository;

    public List<WishlistItemResponse> getWishlist(UUID userId) {
        return wishlistItemRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    public boolean isInWishlist(UUID userId, UUID productId) {
        return wishlistItemRepository.existsByUserIdAndProductId(userId, productId);
    }

    public long getCount(UUID userId) {
        return wishlistItemRepository.countByUserId(userId);
    }

    @Transactional
    public WishlistItemResponse toggle(UUID userId, UUID productId) {
        var existing = wishlistItemRepository.findByUserIdAndProductId(userId, productId);
        if (existing.isPresent()) {
            wishlistItemRepository.delete(existing.get());
            return null;
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));
        Product product = productRepository.findById(productId)
                .orElseThrow(() -> new RuntimeException("Produit non trouvé"));
        WishlistItem item = wishlistItemRepository.save(WishlistItem.builder()
                .user(user).product(product).build());
        return mapToResponse(item);
    }

    @Transactional
    public void remove(UUID userId, UUID productId) {
        wishlistItemRepository.deleteByUserIdAndProductId(userId, productId);
    }

    private WishlistItemResponse mapToResponse(WishlistItem item) {
        Product p = item.getProduct();
        String images = p.getImages();
        String firstImage = null;
        if (images != null && !images.isBlank() && !images.equals("[]")) {
            try {
                String trimmed = images.trim();
                if (trimmed.startsWith("[")) {
                    String content = trimmed.substring(1, trimmed.length() - 1).trim();
                    if (content.startsWith("\"")) {
                        firstImage = content.substring(1, content.indexOf("\"", 1));
                    } else {
                        firstImage = content;
                    }
                } else {
                    firstImage = trimmed;
                }
            } catch (Exception ignored) {}
        }
        return WishlistItemResponse.builder()
                .id(item.getId())
                .productId(p.getId())
                .productName(p.getName())
                .productImage(firstImage)
                .price(p.getPrice())
                .comparePrice(p.getComparePrice())
                .stock(p.getStock())
                .boutiqueId(p.getBoutique().getId())
                .boutiqueName(p.getBoutique().getName())
                .createdAt(item.getCreatedAt())
                .build();
    }
}
