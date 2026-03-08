package com.bolkhata.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class TransactionRequest {
    
    @NotBlank(message = "Customer name is required")
    private String name;
    
    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    private BigDecimal amount;
    
    @NotBlank(message = "Transaction type is required")
    private String type; // CREDIT or PAYMENT
    
    private BigDecimal confidence;
    
    private String transcription;
    
    private String audioFilePath;
    
    private String audioData; // Base64 encoded audio
}
