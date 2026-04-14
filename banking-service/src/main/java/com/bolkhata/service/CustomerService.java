package com.bolkhata.service;

import com.bolkhata.entity.Customer;
import com.bolkhata.entity.Transaction;
import com.bolkhata.repository.CustomerRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Service
public class CustomerService {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomerService.class);
    
    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private volatile Boolean pgTrgmAvailable;
    
    /**
     * Find or create customer using fuzzy matching
     */
    @Transactional
    public Customer findOrCreateCustomer(String name, Long userId) {
        // Try fuzzy matching
        Optional<Customer> matched = fuzzyMatchCustomer(name, userId);
        
        if (matched.isPresent()) {
            return matched.get();
        }
        
        // Create new customer
        return createCustomer(name, userId);
    }
    
    /**
     * Fuzzy match customer by name using PostgreSQL pg_trgm
     * Falls back to Levenshtein if pg_trgm query fails
     */
    public Optional<Customer> fuzzyMatchCustomer(String name, Long userId) {
        if (!isPgTrgmAvailable()) {
            return Optional.empty();
        }

        try {
            // Try PostgreSQL native fuzzy matching first (faster)
            List<Customer> matches = customerRepository.findByFuzzyNameMatch(userId, name);
            
            if (!matches.isEmpty()) {
                return Optional.of(matches.get(0)); // Return best match
            }
        } catch (Exception e) {
            // Fallback to Levenshtein if pg_trgm not available
            logger.warn("PostgreSQL fuzzy matching failed, using Levenshtein fallback: " + e.getMessage());
            // Disable pg_trgm attempts for subsequent calls to avoid poisoning transactions
            pgTrgmAvailable = false;
        }
        
        // Fallback: Use Levenshtein distance
        List<Customer> customers = customerRepository.findByUserId(userId);
        
        Customer bestMatch = null;
        double bestScore = 0.0;
        
        for (Customer customer : customers) {
            double similarity = calculateSimilarity(name, customer.getName());
            
            if (similarity > 0.8 && similarity > bestScore) {
                bestScore = similarity;
                bestMatch = customer;
            }
        }
        
        return Optional.ofNullable(bestMatch);
    }

    private boolean isPgTrgmAvailable() {
        Boolean cached = pgTrgmAvailable;
        if (cached != null) {
            return cached;
        }
        try {
            Boolean exists = jdbcTemplate.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm')",
                Boolean.class
            );
            pgTrgmAvailable = Boolean.TRUE.equals(exists);
        } catch (Exception e) {
            logger.warn("Unable to determine pg_trgm availability, disabling fuzzy SQL: " + e.getMessage());
            pgTrgmAvailable = false;
        }
        return pgTrgmAvailable;
    }
    
    /**
     * Create new customer
     */
    @Transactional
    public Customer createCustomer(String name, Long userId) {
        Customer customer = new Customer();
        customer.setName(name);
        customer.setUserId(userId);
        customer.setTotalCredit(BigDecimal.ZERO);
        customer.setTotalPayments(BigDecimal.ZERO);
        customer.setOutstanding(BigDecimal.ZERO);
        
        return customerRepository.save(customer);
    }
    
    /**
     * Update customer financials based on transaction type
     * Following the financial model:
     * - SALE_PAID: No change to outstanding (immediate payment)
     * - SALE_CREDIT: Increases outstanding (customer owes more)
     * - PAYMENT_RECEIVED: Decreases outstanding (customer pays back)
     */
    @Transactional
    public void updateCustomerFinancials(Long customerId, BigDecimal amount, String type) {
        Customer customer = customerRepository.findById(customerId)
            .orElseThrow(() -> new RuntimeException("Customer not found"));
        
        switch(type) {
            case "SALE_PAID":
                // Immediate payment - no change to outstanding
                break;
            case "SALE_CREDIT":
                // Credit sale - customer owes more
                customer.setTotalCredit(customer.getTotalCredit().add(amount));
                customer.setOutstanding(customer.getOutstanding().add(amount));
                break;
            case "PAYMENT_RECEIVED":
                // Payment received - customer owes less
                customer.setTotalPayments(customer.getTotalPayments().add(amount));
                BigDecimal newOutstanding = customer.getOutstanding().subtract(amount);
                customer.setOutstanding(newOutstanding.max(BigDecimal.ZERO));
                if (newOutstanding.compareTo(BigDecimal.ZERO) < 0) {
                    logger.info("Overpayment detected for customer {}: paid {} but owed only {}",
                               customerId, amount, customer.getOutstanding());
                }
                break;
        }
        
        customerRepository.save(customer);
    }
    
    /**
     * Calculate string similarity using Levenshtein distance
     */
    private double calculateSimilarity(String s1, String s2) {
        String longer = s1.toLowerCase();
        String shorter = s2.toLowerCase();
        
        if (longer.length() < shorter.length()) {
            String temp = longer;
            longer = shorter;
            shorter = temp;
        }
        
        int longerLength = longer.length();
        if (longerLength == 0) {
            return 1.0;
        }
        
        return (longerLength - levenshteinDistance(longer, shorter)) / (double) longerLength;
    }
    
    /**
     * Calculate Levenshtein distance
     */
    private int levenshteinDistance(String s1, String s2) {
        int[] costs = new int[s2.length() + 1];
        
        for (int i = 0; i <= s1.length(); i++) {
            int lastValue = i;
            for (int j = 0; j <= s2.length(); j++) {
                if (i == 0) {
                    costs[j] = j;
                } else if (j > 0) {
                    int newValue = costs[j - 1];
                    if (s1.charAt(i - 1) != s2.charAt(j - 1)) {
                        newValue = Math.min(Math.min(newValue, lastValue), costs[j]) + 1;
                    }
                    costs[j - 1] = lastValue;
                    lastValue = newValue;
                }
            }
            if (i > 0) {
                costs[s2.length()] = lastValue;
            }
        }
        
        return costs[s2.length()];
    }
    
    public List<Customer> getCustomersByUser(Long userId) {
        return customerRepository.findByUserId(userId);
    }
}
