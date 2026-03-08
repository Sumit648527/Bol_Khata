package com.bolkhata.controller;

import com.bolkhata.service.AudioStorageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;

@RestController
@RequestMapping("/api/audio")
@CrossOrigin(origins = "*")
public class AudioController {
    
    @Autowired
    private AudioStorageService audioStorageService;
    
    /**
     * Retrieve audio file by path
     */
    @GetMapping("/{userId}/{year}/{month}/{filename}")
    public ResponseEntity<byte[]> getAudio(
            @PathVariable Long userId,
            @PathVariable String year,
            @PathVariable String month,
            @PathVariable String filename) {
        
        try {
            String relativePath = String.format("%d/%s/%s/%s", userId, year, month, filename);
            byte[] audioData = audioStorageService.retrieveAudio(relativePath);
            
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.parseMediaType("audio/wav"));
            headers.setContentDispositionFormData("inline", filename);
            
            return new ResponseEntity<>(audioData, headers, HttpStatus.OK);
            
        } catch (IOException e) {
            return ResponseEntity.notFound().build();
        }
    }
}
