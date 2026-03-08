package com.bolkhata.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Service
public class AudioStorageService {
    
    @Value("${audio.storage.path:./audio-storage}")
    private String baseStoragePath;
    
    /**
     * Save audio file and return the file path
     */
    public String saveAudio(byte[] audioData, Long userId, Long transactionId) throws IOException {
        LocalDateTime now = LocalDateTime.now();
        String year = now.format(DateTimeFormatter.ofPattern("yyyy"));
        String month = now.format(DateTimeFormatter.ofPattern("MM"));
        
        // Create directory structure: /audio/{userId}/{year}/{month}/
        Path directoryPath = Paths.get(baseStoragePath, userId.toString(), year, month);
        Files.createDirectories(directoryPath);
        
        // Generate unique filename
        String filename = String.format("%d_%s.wav", 
            transactionId != null ? transactionId : System.currentTimeMillis(),
            UUID.randomUUID().toString().substring(0, 8));
        
        Path filePath = directoryPath.resolve(filename);
        Files.write(filePath, audioData);
        
        // Return relative path for database storage
        return String.format("%s/%s/%s/%s", userId, year, month, filename);
    }
    
    /**
     * Retrieve audio file by path
     */
    public byte[] retrieveAudio(String relativePath) throws IOException {
        Path filePath = Paths.get(baseStoragePath, relativePath);
        
        if (!Files.exists(filePath)) {
            throw new IOException("Audio file not found: " + relativePath);
        }
        
        return Files.readAllBytes(filePath);
    }
    
    /**
     * Delete audio file
     */
    public void deleteAudio(String relativePath) throws IOException {
        Path filePath = Paths.get(baseStoragePath, relativePath);
        Files.deleteIfExists(filePath);
    }
    
    /**
     * Check if audio file exists
     */
    public boolean audioExists(String relativePath) {
        Path filePath = Paths.get(baseStoragePath, relativePath);
        return Files.exists(filePath);
    }
}
