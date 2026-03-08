package com.bolkhata.service;

import com.bolkhata.entity.Customer;
import com.bolkhata.entity.Transaction;
import org.springframework.stereotype.Service;

@Service
public class WhatsAppService {
    
    /**
     * Send payment alert via WhatsApp
     * Mock implementation - integrate with actual WhatsApp Business API
     */
    public void sendPaymentAlert(Customer customer, Transaction transaction) {
        if (customer.getMobile() == null || customer.getMobile().isEmpty()) {
            System.out.println("Customer has no mobile number, skipping WhatsApp alert");
            return;
        }
        
        String message = formatMessage(customer, transaction);
        
        // Mock implementation - in production, call WhatsApp Business API
        System.out.println("=== WhatsApp Alert ===");
        System.out.println("To: " + customer.getMobile());
        System.out.println("Message: " + message);
        System.out.println("=====================");
    }
    
    /**
     * Format WhatsApp message in customer's language
     */
    private String formatMessage(Customer customer, Transaction transaction) {
        // For now, default to Hindi
        // In production, get language from user preferences
        return String.format(
            "Namaste %s, aapka %.2f rupay ka payment mil gaya. Baaki raashi: %.2f rupay.",
            customer.getName(),
            transaction.getAmount(),
            customer.getOutstanding()
        );
    }
}
