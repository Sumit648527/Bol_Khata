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
        // Check if mobile already exists
        Optional<User> existing = userRepository.findByMobile(request.getMobile());
        if (existing.isPresent()) {
            throw new IllegalArgumentException("Mobile number already registered");
        }
        
        // Create new user
        User user = new User();
        user.setMobile(request.getMobile()); // Use mobile as username
        user.setShopName(request.getShopName());
        user.setMobile(request.getMobile());
        user.setPassword(request.getPassword()); // In production, hash this!
        user.setLanguage(request.getLanguage() != null ? request.getLanguage() : "hi");
        
        return userRepository.save(user);
    }
    
    /**
     * Login shopkeeper
     */
    public User login(LoginRequest request) {
        User user = userRepository.findByMobile(request.getMobile())
            .orElseThrow(() -> new IllegalArgumentException("Invalid mobile number or password"));
        
        // Check password (in production, use proper password hashing)
        if (!user.getPassword().equals(request.getPassword())) {
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
