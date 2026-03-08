package com.bolkhata.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransactionDTO {
    private Long id;
    private Long customerId;
    private String customerName;
    private Long userId;
    private BigDecimal amount;
    private String type;
    private String transcription;
    private String audioFilePath;
    private BigDecimal confidence;
    private Boolean verified;
    private LocalDateTime timestamp;
}
