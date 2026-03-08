package com.bolkhata.controller;

import com.bolkhata.dto.LoginRequest;
import com.bolkhata.dto.RegisterRequest;
import com.bolkhata.dto.AuthResponse;
import com.bolkhata.entity.User;
import com.bolkhata.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {
    
    @Autowired
    private AuthService authService;
    
    /**
     * Register a new shopkeeper
     */
    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request) {
        try {
            User user = authService.register(request);
            
            AuthResponse response = new AuthResponse(
                true,
                "Registration successful",
                user.getId(),
                user.getShopName(),
                user.getMobile(),
                user.getLanguage()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new AuthResponse(false, e.getMessage(), null, null, null, null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new AuthResponse(false, "Registration failed: " + e.getMessage(), null, null, null, null));
        }
    }
    
    /**
     * Login shopkeeper
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request) {
        try {
            User user = authService.login(request);
            
            AuthResponse response = new AuthResponse(
                true,
                "Login successful",
                user.getId(),
                user.getShopName(),
                user.getMobile(),
                user.getLanguage()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new AuthResponse(false, e.getMessage(), null, null, null, null));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new AuthResponse(false, "Login failed: " + e.getMessage(), null, null, null, null));
        }
    }
    
    /**
     * Get user profile
     */
    @GetMapping("/profile")
    public ResponseEntity<?> getProfile(@RequestHeader("X-User-Id") Long userId) {
        try {
            User user = authService.getUserById(userId);
            
            AuthResponse response = new AuthResponse(
                true,
                "Profile retrieved",
                user.getId(),
                user.getShopName(),
                user.getMobile(),
                user.getLanguage()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new AuthResponse(false, "User not found", null, null, null, null));
        }
    }
}
