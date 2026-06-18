package io.makewebsite.security;

import java.util.Collections;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

public final class RolePermissions {

    private static final Map<String, Set<Permission>> ROLE_PERMISSIONS = Map.of(
        "OWNER", EnumSet.allOf(Permission.class),

        "ADMIN", EnumSet.of(
            Permission.PRODUCT_READ, Permission.PRODUCT_WRITE, Permission.PRODUCT_DELETE,
            Permission.STOCK_UPDATE,
            Permission.CATEGORY_READ, Permission.CATEGORY_WRITE,
            Permission.ORDER_READ, Permission.ORDER_WRITE, Permission.ORDER_DELETE,
            Permission.CUSTOMER_READ, Permission.CUSTOMER_WRITE,
            Permission.ANALYTICS_READ,
            Permission.TEAM_READ, Permission.TEAM_WRITE, Permission.TEAM_DELETE,
            Permission.SETTINGS_READ, Permission.SETTINGS_WRITE,
            Permission.POS_ACCESS,
            Permission.PAYMENT_VALIDATE,
            Permission.MESSAGE_READ, Permission.MESSAGE_WRITE,
            Permission.REVIEW_READ, Permission.REVIEW_WRITE,
            Permission.DISCOUNT_WRITE,
            Permission.INVENTORY_READ, Permission.INVENTORY_WRITE,
            Permission.AI_ASSISTANT
        ),

        "MANAGER", EnumSet.of(
            Permission.PRODUCT_READ, Permission.PRODUCT_WRITE,
            Permission.STOCK_UPDATE,
            Permission.CATEGORY_READ, Permission.CATEGORY_WRITE,
            Permission.ORDER_READ, Permission.ORDER_WRITE,
            Permission.CUSTOMER_READ, Permission.CUSTOMER_WRITE,
            Permission.ANALYTICS_READ,
            Permission.POS_ACCESS,
            Permission.PAYMENT_VALIDATE,
            Permission.MESSAGE_READ, Permission.MESSAGE_WRITE,
            Permission.REVIEW_READ, Permission.REVIEW_WRITE,
            Permission.DISCOUNT_WRITE,
            Permission.INVENTORY_READ, Permission.INVENTORY_WRITE,
            Permission.AI_ASSISTANT
        ),

        "STAFF", EnumSet.of(
            Permission.PRODUCT_READ,
            Permission.CATEGORY_READ,
            Permission.ORDER_READ,
            Permission.CUSTOMER_READ,
            Permission.POS_ACCESS,
            Permission.MESSAGE_READ
        ),

        "CAISSIER", EnumSet.of(
            Permission.ORDER_WRITE,
            Permission.PAYMENT_VALIDATE,
            Permission.POS_ACCESS,
            Permission.CUSTOMER_READ,
            Permission.ORDER_READ
        ),

        "CASHIER", EnumSet.of(
            Permission.ORDER_WRITE,
            Permission.PAYMENT_VALIDATE,
            Permission.POS_ACCESS,
            Permission.CUSTOMER_READ,
            Permission.ORDER_READ
        ),

        "PRODUCT_MANAGER", EnumSet.of(
            Permission.PRODUCT_READ, Permission.PRODUCT_WRITE, Permission.PRODUCT_DELETE,
            Permission.STOCK_UPDATE,
            Permission.CATEGORY_READ, Permission.CATEGORY_WRITE,
            Permission.INVENTORY_READ, Permission.INVENTORY_WRITE
        ),

        "SUPPORT", EnumSet.of(
            Permission.CUSTOMER_READ,
            Permission.ORDER_READ,
            Permission.MESSAGE_READ, Permission.MESSAGE_WRITE,
            Permission.REVIEW_READ, Permission.REVIEW_WRITE
        )
    );

    public static Set<Permission> getPermissions(String role) {
        if (role == null) return Collections.emptySet();
        return ROLE_PERMISSIONS.getOrDefault(role.toUpperCase(), Collections.emptySet());
    }

    public static boolean hasPermission(String role, Permission permission) {
        return getPermissions(role).contains(permission);
    }

    public static boolean hasAnyPermission(String role, Permission... permissions) {
        Set<Permission> perms = getPermissions(role);
        for (Permission p : permissions) {
            if (perms.contains(p)) return true;
        }
        return false;
    }

    public static boolean hasAllPermissions(String role, Permission... permissions) {
        return getPermissions(role).containsAll(Set.of(permissions));
    }

    public static boolean canManageTeam(String role) {
        return role != null && ("OWNER".equals(role) || "ADMIN".equals(role));
    }

    private RolePermissions() {}
}
