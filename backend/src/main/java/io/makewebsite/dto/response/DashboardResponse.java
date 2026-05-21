package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.UUID;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class DashboardResponse {
    private BoutiqueInfo boutique;
    private long views;
    private long productCount;
    private long subscriptionDaysLeft;
    private String subscriptionPlan;
    private String subscriptionStatus;
    private List<QuickAction> quickActions;
    private List<OrderResponse> recentOrders;
    private List<ProductResponse> lowStockProducts;
    private DailyStats todayStats;
    private List<BoutiqueResponse> allBoutiques;

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class BoutiqueInfo {
        private UUID id;
        private String name;
        private String slug;
        private String logoUrl;
        private String customDomain;
        private String planName;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class DailyStats {
        private long ordersToday;
        private double revenueToday;
        private long pendingOrders;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class QuickAction {
        private String label;
        private String icon;
        private String route;
    }
}
