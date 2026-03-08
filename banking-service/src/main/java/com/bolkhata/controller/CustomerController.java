package com.bolkhata.controller;

import com.bolkhata.entity.Customer;
import com.bolkhata.repository.CustomerRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/customers")
@CrossOrigin(origins = "*")
public class CustomerController {
    
    @Autowired
    private CustomerRepository customerRepository;
    
    /**
     * Get all customers for a user
     */
    @GetMapping("")
    public ResponseEntity<?> getCustomers(@RequestHeader("X-User-Id") Long userId) {
        try {
            var customers = customerRepository.findByUserId(userId);
            return ResponseEntity.ok(customers);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("Error fetching customers: " + e.getMessage());
        }
    }
    
    /**
     * Update customer details
     */
    @PutMapping("/{customerId}")
    public ResponseEntity<?> updateCustomer(
            @PathVariable Long customerId,
            @RequestHeader("X-User-Id") Long userId,
            @RequestBody Map<String, String> updates) {
        try {
            Customer customer = customerRepository.findById(customerId)
                .orElseThrow(() -> new RuntimeException("Customer not found"));
            
            // Verify customer belongs to user
            if (!customer.getUserId().equals(userId)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(createErrorResponse("Unauthorized access"));
            }
            
            // Update fields
            if (updates.containsKey("name")) {
                customer.setName(updates.get("name"));
            }
            if (updates.containsKey("mobile")) {
                customer.setMobile(updates.get("mobile"));
            }
            
            customerRepository.save(customer);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Customer updated successfully");
            response.put("customer", customer);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(createErrorResponse("Error updating customer: " + e.getMessage()));
        }
    }
    
    private Map<String, Object> createErrorResponse(String message) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("message", message);
        return response;
    }
}
