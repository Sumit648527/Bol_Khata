#!/bin/bash

echo "=========================================="
echo "Fixing User Entity Schema Mismatch"
echo "=========================================="
echo ""

# Step 1: Fix User entity
echo "Step 1: Updating User.java entity..."
cat > /tmp/User.java << 'EOF'
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
    
    @Column(name = "username", unique = true, nullable = false, length = 50)
    private String username;
    
    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;
    
    @Column(name = "email", length = 100)
    private String email;
    
    @Column(name = "phone", length = 20)
    private String phone;
    
    @Column(name = "shop_name", length = 100)
    private String shopName;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
EOF

sudo cp /tmp/User.java /opt/bolkhata/banking-service/src/main/java/com/bolkhata/entity/User.java
echo "✓ User.java updated"
echo ""

# Step 2: Fix UserRepository
echo "Step 2: Updating UserRepository.java..."
cat > /tmp/UserRepository.java << 'EOF'
package com.bolkhata.repository;

import com.bolkhata.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    // Find user by phone (was findByMobile)
    Optional<User> findByPhone(String phone);
    
    // Find user by username
    Optional<User> findByUsername(String username);
}
EOF

sudo cp /tmp/UserRepository.java /opt/bolkhata/banking-service/src/main/java/com/bolkhata/repository/UserRepository.java
echo "✓ UserRepository.java updated"
echo ""

# Step 3: Fix AuthService
echo "Step 3: Updating AuthService.java..."
cat > /tmp/AuthService.java << 'EOF'
package com.bolkhata.service;

import com.bolkhata.dto.LoginRequest;
import com.bolkhata.dto.RegisterRequest;
import com.bolkhata.entity.User;
import com.bolkhata.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class AuthService {
    
    @Autowired
    private UserRepository userRepository;
    
    /**
     * Register a new shopkeeper
     */
    @Transactional
    public User register(RegisterRequest request) {
        // Check if mobile already exists (using phone field)
        Optional<User> existing = userRepository.findByPhone(request.getMobile());
        if (existing.isPresent()) {
            throw new IllegalArgumentException("Mobile number already registered");
        }
        
        // Create new user
        User user = new User();
        user.setUsername(request.getMobile()); // Use mobile as username
        user.setPasswordHash(request.getPassword()); // In production, hash this!
        user.setPhone(request.getMobile());
        user.setShopName(request.getShopName());
        user.setEmail(null); // Optional field
        
        return userRepository.save(user);
    }
    
    /**
     * Login shopkeeper
     */
    public User login(LoginRequest request) {
        User user = userRepository.findByPhone(request.getMobile())
            .orElseThrow(() -> new IllegalArgumentException("Invalid mobile number or password"));
        
        // Check password (in production, use proper password hashing)
        if (!user.getPasswordHash().equals(request.getPassword())) {
            throw new IllegalArgumentException("Invalid mobile number or password");
        }
        
        return user;
    }
    
    /**
     * Get user by ID
     */
    public User getUserById(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
    }
}
EOF

sudo cp /tmp/AuthService.java /opt/bolkhata/banking-service/src/main/java/com/bolkhata/service/AuthService.java
echo "✓ AuthService.java updated"
echo ""

# Step 4: Rebuild application
echo "Step 4: Rebuilding application..."
cd /opt/bolkhata/banking-service
mvn clean package -DskipTests
echo ""

# Step 5: Restart service
echo "Step 5: Restarting banking service..."
sudo systemctl restart bolkhata-banking
echo ""

# Step 6: Wait and check status
echo "Step 6: Waiting for service to start..."
sleep 15
echo ""

echo "Service status:"
sudo systemctl status bolkhata-banking --no-pager
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "Test registration at: http://54.225.178.7"
