package io.makewebsite.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "plans")
public class Plan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull
    @Size(max = 50)
    @Column(nullable = false)
    private String name;

    @NotNull
    @Column(name = "price_dt", nullable = false, precision = 10, scale = 2)
    private BigDecimal priceDt;

    @NotNull
    @Column(name = "duration_days", nullable = false)
    private Integer durationDays;

    @Builder.Default
    @Column(name = "max_products")
    private Integer maxProducts = 250;

    @Builder.Default
    @Column(name = "commission_percent", precision = 10, scale = 2)
    private BigDecimal commissionPercent = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String features;
}
