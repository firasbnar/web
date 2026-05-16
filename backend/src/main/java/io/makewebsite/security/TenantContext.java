package io.makewebsite.security;

import java.util.UUID;

public final class TenantContext {
    private static final ThreadLocal<UUID> CURRENT_TENANT = new ThreadLocal<>();
    private static final ThreadLocal<Boolean> SUPER_ADMIN = ThreadLocal.withInitial(() -> false);

    private TenantContext() {
    }

    public static void set(UUID tenantId, boolean superAdmin) {
        CURRENT_TENANT.set(tenantId);
        SUPER_ADMIN.set(superAdmin);
    }

    public static UUID getTenantId() {
        return CURRENT_TENANT.get();
    }

    public static boolean isSuperAdmin() {
        return Boolean.TRUE.equals(SUPER_ADMIN.get());
    }

    public static void clear() {
        CURRENT_TENANT.remove();
        SUPER_ADMIN.remove();
    }
}
