package io.makewebsite.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class CheckoutController {

    @GetMapping("/checkout/success")
    public String checkoutSuccess(@RequestParam(value = "order", required = false) String orderNumber,
                                   @RequestParam(value = "boutiqueId", required = false) String boutiqueId) {
        return "redirect:/store/" + (boutiqueId != null ? boutiqueId : "") + "?payment=success&order=" +
                (orderNumber != null ? orderNumber : "");
    }

    @GetMapping("/checkout/cancel")
    public String checkoutCancel(@RequestParam(value = "boutiqueId", required = false) String boutiqueId) {
        return "redirect:/store/" + (boutiqueId != null ? boutiqueId : "") + "?payment=cancel";
    }
}
