package com.bolkhata.controller;

import com.bolkhata.service.ShopStatisticsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/statistics")
@CrossOrigin(origins = "*")
public class StatisticsController {
    
    @Autowired
    private ShopStatisticsService statisticsService;
    
    /**
     * Get overall shop statistics
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getShopStatistics(
            @RequestHeader("X-User-Id") Long userId) {
        
        Map<String, Object> stats = statisticsService.calculateShopStatistics(userId);
        return ResponseEntity.ok(stats);
    }
    
    /**
     * Get today's statistics
     */
    @GetMapping("/today")
    public ResponseEntity<Map<String, Object>> getTodayStatistics(
            @RequestHeader("X-User-Id") Long userId) {
        
        Map<String, Object> stats = statisticsService.calculateTodayStatistics(userId);
        return ResponseEntity.ok(stats);
    }
}
