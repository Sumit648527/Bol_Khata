package com.bolkhata.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "shop_name", nullable = false)
    private String shopName;
    
    @Column(name = "mobile", unique = true, nullable = false, length = 15)
    private String mobile;
    
    @Column(name = "language", length = 10)
    private String language = "hi"; // Default to Hindi
    
    @Column(name = "password", nullable = false)
    private String password; // TODO: Hash passwords in production!
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
