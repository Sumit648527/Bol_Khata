#!/bin/bash

# Fix AuthService to use correct field names
echo "Fixing AuthService to match User entity..."

# Create the corrected AuthService.java file
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

# Copy to EC2
sudo cp /tmp/AuthService.java /opt/bolkhata/banking-service/src/main/java/com/bolkhata/service/AuthService.java

echo "AuthService updated successfully"
