#!/bin/bash

# Fix UserRepository to use correct field names
echo "Fixing UserRepository to match User entity..."

# Create the corrected UserRepository.java file
cat > /tmp/UserRepository.java << 'EOF'
package com.bolkhata.repository;

import com.bolkhata.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    // Find user by phone (was findByMobile)
    Optional<User> findByPhone(String phone);
    
    // Find user by username
    Optional<User> findByUsername(String username);
}
EOF

# Copy to EC2
sudo cp /tmp/UserRepository.java /opt/bolkhata/banking-service/src/main/java/com/bolkhata/repository/UserRepository.java

echo "UserRepository updated successfully"
