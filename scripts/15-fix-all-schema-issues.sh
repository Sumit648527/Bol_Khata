#!/bin/bash

# Script to fix all database schema mismatches between local and RDS
# This ensures all entities match the actual RDS schema

set -e

echo "=========================================="
echo "Fixing All Database Schema Issues"
echo "=========================================="

# 1. Fix Transaction Entity - Remove enum, use String
echo "1. Fixing Transaction entity..."
cat > /opt/bolkhata/banking-service/src/main/java/com/bolkhata/entity/Transaction.java << 'EOF'
package com.bolkhata.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "transactions", indexes = {
    @Index(name = "idx_customer", columnList = "customer_id"),
    @Index(name = "idx_user_timestamp", columnList = "user_id,timestamp")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Transaction {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "customer_id", nullable = false)
    private Long customerId;
    
    @Column(name = "user_id", nullable = false)
    private Long userId;
    
    @Column(name = "amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;
    
    @Column(name = "type", nullable = false, length = 20)
    private String type;
    
    @Column(name = "transcription", columnDefinition = "TEXT")
    private String transcription;
    
    @Column(name = "audio_file_path", length = 500)
    private String audioFilePath;
    
    @Column(name = "confidence", precision = 3, scale = 2)
    private BigDecimal confidence;
    
    @Column(name = "verified")
    private Boolean verified = false;
    
    @Column(name = "timestamp", nullable = false, updatable = false)
    private LocalDateTime timestamp;
    
    @PrePersist
    protected void onCreate() {
        timestamp = LocalDateTime.now();
        if (verified == null) {
            verified = false;
        }
    }
}
EOF

# 2. Fix TransactionService - Remove enum usage
echo "2. Fixing TransactionService..."
cat > /opt/bolkhata/banking-service/src/main/java/com/bolkhata/service/TransactionService.java << 'EOF'
package com.bolkhata.service;

import com.bolkhata.dto.TransactionRequest;
import com.bolkhata.entity.Customer;
import com.bolkhata.entity.Transaction;
import com.bolkhata.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class TransactionService {
    
    @Autowired
    private TransactionRepository transactionRepository;
    
    @Autowired
    private CustomerService customerService;
    
    @Autowired
    private WhatsAppService whatsAppService;
    
    @Autowired
    private AudioStorageService audioStorageService;
    
    /**
     * Create transaction and update customer balance atomically
     */
    @Transactional
    public Transaction createTransaction(TransactionRequest request, Long userId) {
        // Find or create customer
        Customer customer = customerService.findOrCreateCustomer(request.getName(), userId);
        
        // Save audio file if provided
        String audioFilePath = null;
        if (request.getAudioData() != null && !request.getAudioData().isEmpty()) {
            try {
                byte[] audioBytes = java.util.Base64.getDecoder().decode(request.getAudioData());
                audioFilePath = audioStorageService.saveAudio(audioBytes, userId, null);
            } catch (Exception e) {
                System.err.println("Audio storage failed: " + e.getMessage());
            }
        }
        
        // Create transaction
        Transaction transaction = new Transaction();
        transaction.setCustomerId(customer.getId());
        transaction.setUserId(userId);
        transaction.setAmount(request.getAmount());
        transaction.setType(request.getType());
        transaction.setTranscription(request.getTranscription());
        transaction.setAudioFilePath(audioFilePath);
        transaction.setConfidence(request.getConfidence());
        transaction.setVerified(request.getConfidence() != null && 
                               request.getConfidence().compareTo(new BigDecimal("0.7")) >= 0);
        
        Transaction savedTransaction = transactionRepository.save(transaction);
        
        // Update customer financials based on transaction type
        customerService.updateCustomerFinancials(customer.getId(), request.getAmount(), request.getType());
        
        // Send WhatsApp alert for payments
        if ("PAYMENT_RECEIVED".equals(request.getType())) {
            try {
                whatsAppService.sendPaymentAlert(customer, savedTransaction);
            } catch (Exception e) {
                System.err.println("WhatsApp alert failed: " + e.getMessage());
            }
        }
        
        return savedTransaction;
    }
    
    public List<Transaction> getTransactionsByCustomer(Long customerId) {
        return transactionRepository.findByCustomerId(customerId);
    }
    
    public List<Transaction> getTransactionsByUser(Long userId) {
        return transactionRepository.findByUserId(userId);
    }
}
EOF

# 3. Fix TransactionController - Remove .name() calls
echo "3. Fixing TransactionController..."
cat > /opt/bolkhata/banking-service/src/main/java/com/bolkhata/controller/TransactionController.java << 'EOF'
package com.bolkhata.controller;

import com.bolkhata.dto.TransactionRequest;
import com.bolkhata.dto.TransactionResponse;
import com.bolkhata.entity.Customer;
import com.bolkhata.entity.Transaction;
import com.bolkhata.repository.CustomerRepository;
import com.bolkhata.service.TransactionService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/transactions")
@CrossOrigin(origins = "*")
public class TransactionController {
    
    @Autowired
    private TransactionService transactionService;
    
    @Autowired
    private CustomerRepository customerRepository;
    
    @Autowired
    private com.bolkhata.repository.TransactionRepository transactionRepository;
    
    /**
     * Get all customers for a user
     */
    @GetMapping("/customers")
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
     * Get all transactions for a user
     */
    @GetMapping("")
    public ResponseEntity<?> getTransactions(@RequestHeader("X-User-Id") Long userId) {
        try {
            var transactions = transactionRepository.findByUserIdOrderByTimestampDesc(userId);
            
            // Enrich with customer names
            var enrichedTransactions = transactions.stream().map(t -> {
                var dto = new com.bolkhata.dto.TransactionDTO();
                dto.setId(t.getId());
                dto.setCustomerId(t.getCustomerId());
                dto.setUserId(t.getUserId());
                dto.setAmount(t.getAmount());
                dto.setType(t.getType());
                dto.setTranscription(t.getTranscription());
                dto.setAudioFilePath(t.getAudioFilePath());
                dto.setConfidence(t.getConfidence());
                dto.setVerified(t.getVerified());
                dto.setTimestamp(t.getTimestamp());
                
                // Add customer name
                customerRepository.findById(t.getCustomerId()).ifPresent(c -> {
                    dto.setCustomerName(c.getName());
                });
                
                return dto;
            }).toList();
            
            return ResponseEntity.ok(enrichedTransactions);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("Error fetching transactions: " + e.getMessage());
        }
    }
    
    /**
     * Log a new transaction
     */
    @PostMapping("/log")
    public ResponseEntity<TransactionResponse> logTransaction(
            @Valid @RequestBody TransactionRequest request,
            @RequestHeader("X-User-Id") Long userId) {
        
        try {
            // Create transaction
            Transaction transaction = transactionService.createTransaction(request, userId);
            
            // Get updated customer outstanding
            Customer customer = customerRepository.findById(transaction.getCustomerId())
                .orElseThrow(() -> new RuntimeException("Customer not found"));
            
            // Generate response message
            String responseText = generateResponseText(
                customer.getName(),
                request.getAmount(),
                request.getType(),
                customer.getOutstanding()
            );
            
            TransactionResponse response = new TransactionResponse(
                true,
                "Transaction recorded successfully",
                responseText,
                customer.getOutstanding()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            TransactionResponse errorResponse = new TransactionResponse(
                false,
                "Error recording transaction: " + e.getMessage(),
                null,
                null
            );
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorResponse);
        }
    }
    
    /**
     * Generate voice response text in Hindi
     */
    private String generateResponseText(String name, java.math.BigDecimal amount, 
                                       String type, java.math.BigDecimal outstanding) {
        switch(type) {
            case "SALE_PAID":
                return String.format(
                    "%s ka %.2f rupay cash payment record ho gaya. Dhanyavaad!",
                    name, amount
                );
            case "SALE_CREDIT":
                return String.format(
                    "%s ka %.2f rupay udhaar record ho gaya. Total baaki: %.2f rupay",
                    name, amount, outstanding
                );
            case "PAYMENT_RECEIVED":
                return String.format(
                    "%s ka %.2f rupay payment record ho gaya. Baaki raashi: %.2f rupay",
                    name, amount, outstanding
                );
            default:
                return String.format(
                    "%s ka %.2f rupay transaction record ho gaya.",
                    name, amount
                );
        }
    }
}
EOF

# 4. Fix CustomerService - Ensure all string comparisons
echo "4. Fixing CustomerService..."
cat > /opt/bolkhata/banking-service/src/main/java/com/bolkhata/service/CustomerService.java << 'EOF'
package com.bolkhata.service;

import com.bolkhata.entity.Customer;
import com.bolkhata.repository.CustomerRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class CustomerService {
    
    @Autowired
    private CustomerRepository customerRepository;
    
    /**
     * Find customer by name (fuzzy match) or create new one
     */
    @Transactional
    public Customer findOrCreateCustomer(String name, Long userId) {
        // Try exact match first
        List<Customer> customers = customerRepository.findByUserIdAndName(userId, name);
        if (!customers.isEmpty()) {
            return customers.get(0);
        }
        
        // Try fuzzy match using PostgreSQL similarity
        customers = customerRepository.findSimilarCustomers(userId, name, 0.3);
        if (!customers.isEmpty()) {
            return customers.get(0);
        }
        
        // Create new customer
        Customer customer = new Customer();
        customer.setName(name);
        customer.setUserId(userId);
        customer.setTotalCredit(BigDecimal.ZERO);
        customer.setTotalPayments(BigDecimal.ZERO);
        customer.setOutstanding(BigDecimal.ZERO);
        
        return customerRepository.save(customer);
    }
    
    /**
     * Update customer financial totals based on transaction
     */
    @Transactional
    public void updateCustomerFinancials(Long customerId, BigDecimal amount, String transactionType) {
        Customer customer = customerRepository.findById(customerId)
            .orElseThrow(() -> new RuntimeException("Customer not found"));
        
        switch (transactionType) {
            case "SALE_PAID":
                // Immediate payment - no change to outstanding
                break;
                
            case "SALE_CREDIT":
                // Credit sale - increase outstanding
                customer.setTotalCredit(customer.getTotalCredit().add(amount));
                customer.setOutstanding(customer.getOutstanding().add(amount));
                break;
                
            case "PAYMENT_RECEIVED":
                // Payment received - decrease outstanding
                customer.setTotalPayments(customer.getTotalPayments().add(amount));
                customer.setOutstanding(customer.getOutstanding().subtract(amount));
                break;
        }
        
        customerRepository.save(customer);
    }
    
    public List<Customer> getCustomersByUser(Long userId) {
        return customerRepository.findByUserId(userId);
    }
    
    public Customer getCustomerById(Long id) {
        return customerRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Customer not found"));
    }
}
EOF

# 5. Fix ShopStatisticsService
echo "5. Fixing ShopStatisticsService..."
cat > /opt/bolkhata/banking-service/src/main/java/com/bolkhata/service/ShopStatisticsService.java << 'EOF'
package com.bolkhata.service;

import com.bolkhata.entity.Customer;
import com.bolkhata.entity.Transaction;
import com.bolkhata.repository.CustomerRepository;
import com.bolkhata.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class ShopStatisticsService {
    
    @Autowired
    private CustomerRepository customerRepository;
    
    @Autowired
    private TransactionRepository transactionRepository;
    
    public Map<String, Object> getShopStatistics(Long userId) {
        Map<String, Object> stats = new HashMap<>();
        
        // Get all customers
        List<Customer> customers = customerRepository.findByUserId(userId);
        stats.put("totalCustomers", customers.size());
        
        // Calculate total outstanding
        BigDecimal totalOutstanding = customers.stream()
            .map(Customer::getOutstanding)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        stats.put("totalOutstanding", totalOutstanding);
        
        // Get all transactions
        List<Transaction> transactions = transactionRepository.findByUserId(userId);
        stats.put("totalTransactions", transactions.size());
        
        // Calculate today's transactions
        LocalDateTime startOfDay = LocalDateTime.now().withHour(0).withMinute(0).withSecond(0);
        long todayTransactions = transactions.stream()
            .filter(t -> t.getTimestamp().isAfter(startOfDay))
            .count();
        stats.put("todayTransactions", todayTransactions);
        
        // Calculate total sales (SALE_PAID + SALE_CREDIT)
        BigDecimal totalSales = transactions.stream()
            .filter(t -> "SALE_PAID".equals(t.getType()) || "SALE_CREDIT".equals(t.getType()))
            .map(Transaction::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        stats.put("totalSales", totalSales);
        
        // Calculate total payments received
        BigDecimal totalPayments = transactions.stream()
            .filter(t -> "PAYMENT_RECEIVED".equals(t.getType()))
            .map(Transaction::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        stats.put("totalPayments", totalPayments);
        
        // Calculate today's sales
        BigDecimal todaySales = transactions.stream()
            .filter(t -> t.getTimestamp().isAfter(startOfDay))
            .filter(t -> "SALE_PAID".equals(t.getType()) || "SALE_CREDIT".equals(t.getType()))
            .map(Transaction::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        stats.put("todaySales", todaySales);
        
        // Calculate today's payments
        BigDecimal todayPayments = transactions.stream()
            .filter(t -> t.getTimestamp().isAfter(startOfDay))
            .filter(t -> "PAYMENT_RECEIVED".equals(t.getType()))
            .map(Transaction::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        stats.put("todayPayments", todayPayments);
        
        return stats;
    }
}
EOF

# 6. Rebuild the application
echo "6. Rebuilding application..."
cd /opt/bolkhata/banking-service
mvn clean package -DskipTests

# 7. Restart the service
echo "7. Restarting service..."
sudo systemctl restart bolkhata-banking

# 8. Wait and check status
echo "8. Checking service status..."
sleep 10
sudo systemctl status bolkhata-banking --no-pager

echo ""
echo "=========================================="
echo "All schema fixes applied successfully!"
echo "=========================================="
echo ""
echo "Service should now work with RDS schema."
echo "Test by creating a manual transaction."
