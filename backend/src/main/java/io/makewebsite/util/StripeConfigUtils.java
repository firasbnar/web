package io.makewebsite.util;

import io.makewebsite.entity.Boutique;

public final class StripeConfigUtils {

    private StripeConfigUtils() {
    }

    public static boolean isStripeEnabled(Boutique boutique) {
        if (boutique == null) {
            return false;
        }
        if (Boolean.TRUE.equals(boutique.getStripeEnabled())) {
            return true;
        }
        String status = boutique.getStripeStatus();
        return status != null && (
                "active".equalsIgnoreCase(status)
                        || "enabled".equalsIgnoreCase(status)
                        || "true".equalsIgnoreCase(status)
        );
    }

    public static String normalizeStripeStatus(Boolean stripeEnabled, String stripeStatus) {
        if (stripeEnabled != null) {
            return stripeEnabled ? "ENABLED" : "DISABLED";
        }
        if (stripeStatus == null || stripeStatus.isBlank()) {
            return "DISABLED";
        }
        if ("active".equalsIgnoreCase(stripeStatus) || "enabled".equalsIgnoreCase(stripeStatus) || "true".equalsIgnoreCase(stripeStatus)) {
            return "ENABLED";
        }
        return "DISABLED";
    }

    public static boolean resolveStripeEnabled(Boolean stripeEnabled, String stripeStatus) {
        if (stripeEnabled != null) {
            return stripeEnabled;
        }
        return "ENABLED".equals(normalizeStripeStatus(null, stripeStatus));
    }

    public static void applyStripeState(Boutique boutique, Boolean stripeEnabled, String stripeStatus) {
        if (boutique == null) {
            return;
        }
        boolean enabled = resolveStripeEnabled(stripeEnabled, stripeStatus);
        boutique.setStripeEnabled(enabled);
        boutique.setStripeStatus(enabled ? "ENABLED" : "DISABLED");
    }
}
