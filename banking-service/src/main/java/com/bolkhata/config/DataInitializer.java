package com.bolkhata.config;

import com.bolkhata.entity.User;
import com.bolkhata.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class DataInitializer implements CommandLineRunner {
    
    @Autowired
    private UserRepository userRepository;
    
    @Override
    public void run(String... args) throws Exception {
        // Create a test user if none exists
        if (userRepository.count() == 0) {
            User testUser = new User();
            testUser.setShopName("Test Shop");
            testUser.setMobile("9876543210");
            testUser.setLanguage("hi");
            userRepository.save(testUser);
            
            System.out.println("=================================");
            System.out.println("Test user created with ID: " + testUser.getId());
            System.out.println("Shop: " + testUser.getShopName());
            System.out.println("Mobile: " + testUser.getMobile());
            System.out.println("Use X-User-Id: " + testUser.getId() + " in API requests");
            System.out.println("=================================");
        }
    }
}
