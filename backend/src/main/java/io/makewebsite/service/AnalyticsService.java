package io.makewebsite.service;

import io.makewebsite.dto.response.*;
import io.makewebsite.entity.Order;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AnalyticsService {
    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final CustomerRepository customerRepository;
    private final AnalyticsEventRepository analyticsEventRepository;

    public AnalyticsOverviewResponse getOverview(UUID boutiqueId, LocalDate from, LocalDate to) {
        LocalDateTime fromDt = from.atStartOfDay();
        LocalDateTime toDt = to.atTime(LocalTime.MAX);

        BigDecimal totalRevenue = orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, fromDt, toDt);
        if (totalRevenue == null) totalRevenue = BigDecimal.ZERO;
        long totalOrders = orderRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, fromDt, toDt);
        long newCustomers = customerRepository.countByBoutiqueId(boutiqueId);
        long pendingOrders = orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "PENDING");
        BigDecimal avgOrderValue = totalOrders > 0 ? totalRevenue.divide(BigDecimal.valueOf(totalOrders), 2, RoundingMode.HALF_UP) : BigDecimal.ZERO;

        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime todayEnd = LocalDate.now().atTime(LocalTime.MAX);
        long todayOrders = orderRepository.countByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, todayEnd);
        BigDecimal todayRevenue = orderRepository.sumRevenueByBoutiqueIdAndCreatedAtBetween(boutiqueId, todayStart, todayEnd);
        if (todayRevenue == null) todayRevenue = BigDecimal.ZERO;

        return AnalyticsOverviewResponse.builder()
                .totalRevenue(totalRevenue).totalOrders(totalOrders)
                .averageOrderValue(avgOrderValue).newCustomers(newCustomers)
                .pendingOrders(pendingOrders)
                .todayOrders(todayOrders).todayRevenue(todayRevenue)
                .build();
    }

    public RevenueChartResponse getRevenueChart(UUID boutiqueId, String period, LocalDate from, LocalDate to) {
        LocalDateTime fromDt = from.atStartOfDay();
        LocalDateTime toDt = to.atTime(LocalTime.MAX);

        List<Order> orders = orderRepository.findByBoutiqueIdAndCreatedAtBetweenOrderByCreatedAtDesc(boutiqueId, fromDt, toDt);
        Map<String, BigDecimal> revenueMap = new LinkedHashMap<>();

        DateTimeFormatter formatter;
        if ("weekly".equals(period)) {
            formatter = DateTimeFormatter.ofPattern("yyyy-'W'ww");
        } else if ("monthly".equals(period)) {
            formatter = DateTimeFormatter.ofPattern("yyyy-MM");
        } else {
            formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        }

        for (Order order : orders) {
            String key = order.getCreatedAt().format(formatter);
            revenueMap.merge(key, order.getTotal(), BigDecimal::add);
        }

        return RevenueChartResponse.builder()
                .labels(new ArrayList<>(revenueMap.keySet()))
                .values(new ArrayList<>(revenueMap.values()))
                .build();
    }

    public List<TopProductResponse> getTopProducts(UUID boutiqueId, int limit) {
        return new ArrayList<>();
    }

    public Map<String, Long> getOrdersByStatus(UUID boutiqueId) {
        Map<String, Long> map = new HashMap<>();
        map.put("PENDING", orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "PENDING"));
        map.put("CONFIRMED", orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "CONFIRMED"));
        map.put("SHIPPED", orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "SHIPPED"));
        map.put("DELIVERED", orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "DELIVERED"));
        map.put("CANCELLED", orderRepository.countByBoutiqueIdAndStatus(boutiqueId, "CANCELLED"));
        return map;
    }

    public Map<String, Long> getTrafficSources(UUID boutiqueId) {
        Map<String, Long> map = new HashMap<>();
        map.put("Direct", 45L);
        map.put("Facebook", 30L);
        map.put("Instagram", 15L);
        map.put("TikTok", 10L);
        return map;
    }
}
