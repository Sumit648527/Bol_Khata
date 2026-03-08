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
                // Save with temporary transaction ID (will update after save)
                audioFilePath = audioStorageService.saveAudio(audioBytes, userId, null);
            } catch (Exception e) {
                System.err.println("Audio storage failed: " + e.getMessage());
                // Continue without audio - flag will be set
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
                // Log error but don't fail transaction
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
