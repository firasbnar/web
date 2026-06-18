package io.makewebsite.controller;

import io.makewebsite.repository.BoutiqueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

import java.util.UUID;

@Controller
@RequiredArgsConstructor
public class CheckoutController {

    private final BoutiqueRepository boutiqueRepository;

    @GetMapping("/checkout/success")
    public String checkoutSuccess(@RequestParam(value = "order", required = false) String orderNumber,
                                   @RequestParam(value = "boutiqueId", required = false) String boutiqueId) {
        String slug = resolveStoreSlug(boutiqueId);
        return "redirect:/store/" + slug + "?payment=success&order=" + (orderNumber != null ? orderNumber : "");
    }

    @GetMapping("/checkout/cancel")
    public String checkoutCancel(@RequestParam(value = "boutiqueId", required = false) String boutiqueId) {
        String slug = resolveStoreSlug(boutiqueId);
        return "redirect:/store/" + slug + "?payment=cancel";
    }

    private String resolveStoreSlug(String boutiqueIdOrSlug) {
        if (boutiqueIdOrSlug == null || boutiqueIdOrSlug.isBlank()) {
            return "";
        }
        try {
            UUID id = UUID.fromString(boutiqueIdOrSlug.trim());
            return boutiqueRepository.findById(id).map(b -> b.getSlug() != null ? b.getSlug() : "").orElse("");
        } catch (IllegalArgumentException ex) {
            return boutiqueIdOrSlug.trim();
        }
    }
}
