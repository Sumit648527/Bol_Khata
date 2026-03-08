package com.bolkhata.repository;

import com.bolkhata.entity.Customer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface CustomerRepository extends JpaRepository<Customer, Long> {
    List<Customer> findByUserId(Long userId);
    List<Customer> findByUserIdAndNameContainingIgnoreCase(Long userId, String name);
    
    /**
     * PostgreSQL fuzzy matching using pg_trgm similarity
     * Returns customers with similarity > 0.8
     */
    @Query(value = "SELECT * FROM customers " +
           "WHERE user_id = :userId " +
           "AND similarity(LOWER(name), LOWER(:name)) > 0.8 " +
           "ORDER BY similarity(LOWER(name), LOWER(:name)) DESC " +
           "LIMIT 5", 
           nativeQuery = true)
    List<Customer> findByFuzzyNameMatch(@Param("userId") Long userId, @Param("name") String name);
}
