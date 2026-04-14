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
        // Create a test user if it doesn't exist. This must never fail app startup.
        final String testMobile = "9876543210";
        if (userRepository.findByMobile(testMobile).isEmpty()) {
            User testUser = new User();
            testUser.setShopName("Test Shop");
            testUser.setMobile(testMobile);
            testUser.setLanguage("hi");
            testUser.setPassword("test123"); // Do not deploy with real users; demo only.

            if (testUser.getPassword() == null || testUser.getPassword().isBlank()) {
                testUser.setPassword("test123");
            }

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
