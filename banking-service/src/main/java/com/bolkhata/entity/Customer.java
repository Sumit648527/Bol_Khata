package com.bolkhata.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "customers", indexes = {
    @Index(name = "idx_user_name", columnList = "user_id,name")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Customer {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "name", nullable = false)
    private String name;
    
    @Column(name = "mobile", length = 15)
    private String mobile;
    
    @Column(name = "user_id", nullable = false)
    private Long userId;
    
    @Column(name = "total_credit", precision = 10, scale = 2)
    private BigDecimal totalCredit = BigDecimal.ZERO;
    
    @Column(name = "total_payments", precision = 10, scale = 2)
    private BigDecimal totalPayments = BigDecimal.ZERO;
    
    @Column(name = "outstanding", precision = 10, scale = 2)
    private BigDecimal outstanding = BigDecimal.ZERO;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        if (totalCredit == null) {
            totalCredit = BigDecimal.ZERO;
        }
        if (totalPayments == null) {
            totalPayments = BigDecimal.ZERO;
        }
        if (outstanding == null) {
            outstanding = BigDecimal.ZERO;
        }
    }
}
