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
@RequestMapping({"/api/transactions", "/transactions"})
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
            String rootMessage = getRootCauseMessage(e);
            String message = rootMessage != null && !rootMessage.isBlank()
                ? rootMessage
                : e.getMessage();

            TransactionResponse errorResponse = new TransactionResponse(
                false,
                "Error recording transaction: " + message,
                null,
                null
            );
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorResponse);
        }
    }

    private String getRootCauseMessage(Throwable t) {
        if (t == null) return null;
        Throwable cur = t;
        int guard = 0;
        while (cur.getCause() != null && cur.getCause() != cur && guard++ < 25) {
            cur = cur.getCause();
        }
        return cur.getMessage();
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
