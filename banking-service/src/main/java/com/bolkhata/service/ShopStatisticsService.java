package com.bolkhata.service;

import com.bolkhata.entity.Customer;
import com.bolkhata.entity.Transaction;
import com.bolkhata.repository.CustomerRepository;
import com.bolkhata.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class ShopStatisticsService {
    
    @Autowired
    private TransactionRepository transactionRepository;
    
    @Autowired
    private CustomerRepository customerRepository;
    
    /**
     * Calculate comprehensive shop statistics
     */
    public Map<String, Object> calculateShopStatistics(Long userId) {
        List<Transaction> allTransactions = transactionRepository.findByUserId(userId);
        List<Customer> allCustomers = customerRepository.findByUserId(userId);
        
        // Initialize counters
        BigDecimal totalSalesPaid = BigDecimal.ZERO;
        BigDecimal totalCreditGiven = BigDecimal.ZERO;
        BigDecimal totalPaymentsReceived = BigDecimal.ZERO;
        
        // Calculate from transactions
        for (Transaction t : allTransactions) {
            String type = t.getType();
            if ("SALE_PAID".equals(type)) {
                totalSalesPaid = totalSalesPaid.add(t.getAmount());
            } else if ("SALE_CREDIT".equals(type)) {
                totalCreditGiven = totalCreditGiven.add(t.getAmount());
            } else if ("PAYMENT_RECEIVED".equals(type)) {
                totalPaymentsReceived = totalPaymentsReceived.add(t.getAmount());
            }
        }
        
        // Calculate total shop income (money actually received)
        BigDecimal totalIncome = totalSalesPaid.add(totalPaymentsReceived);
        
        // Calculate total outstanding from all customers
        BigDecimal totalOutstanding = allCustomers.stream()
            .map(Customer::getOutstanding)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        // Build response
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalCustomers", allCustomers.size());
        stats.put("totalIncome", totalIncome);
        stats.put("totalSalesPaid", totalSalesPaid);
        stats.put("totalCreditGiven", totalCreditGiven);
        stats.put("totalPaymentsReceived", totalPaymentsReceived);
        stats.put("totalOutstanding", totalOutstanding);
        
        return stats;
    }
    
    /**
     * Calculate today's statistics
     */
    public Map<String, Object> calculateTodayStatistics(Long userId) {
        LocalDateTime startOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MIN);
        LocalDateTime endOfDay = LocalDateTime.of(LocalDate.now(), LocalTime.MAX);
        
        List<Transaction> todayTransactions = transactionRepository.findByUserIdAndTimestampBetween(
            userId, startOfDay, endOfDay);
        
        BigDecimal todaySalesPaid = BigDecimal.ZERO;
        BigDecimal todayCreditGiven = BigDecimal.ZERO;
        BigDecimal todayPaymentsReceived = BigDecimal.ZERO;
        
        for (Transaction t : todayTransactions) {
            String type = t.getType();
            if ("SALE_PAID".equals(type)) {
                todaySalesPaid = todaySalesPaid.add(t.getAmount());
            } else if ("SALE_CREDIT".equals(type)) {
                todayCreditGiven = todayCreditGiven.add(t.getAmount());
            } else if ("PAYMENT_RECEIVED".equals(type)) {
                todayPaymentsReceived = todayPaymentsReceived.add(t.getAmount());
            }
        }
        
        BigDecimal todayIncome = todaySalesPaid.add(todayPaymentsReceived);
        
        Map<String, Object> stats = new HashMap<>();
        stats.put("todayIncome", todayIncome);
        stats.put("todaySalesPaid", todaySalesPaid);
        stats.put("todayCreditGiven", todayCreditGiven);
        stats.put("todayPaymentsReceived", todayPaymentsReceived);
        stats.put("todayTransactions", todayTransactions.size());
        
        return stats;
    }
}
