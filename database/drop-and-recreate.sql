-- Drop and Recreate Database Schema for Bol-Khata
-- This script drops existing tables and recreates them with the new financial model

-- Drop existing tables
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Create users table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    shop_name VARCHAR(255) NOT NULL,
    mobile VARCHAR(15) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    language VARCHAR(10) DEFAULT 'hi',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create customers table with new financial tracking fields
CREATE TABLE customers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    mobile VARCHAR(15),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_credit DECIMAL(10,2) DEFAULT 0.00,
    total_payments DECIMAL(10,2) DEFAULT 0.00,
    outstanding DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index for customer lookup
CREATE INDEX idx_user_name ON customers(user_id, name);

-- Create transactions table with new transaction types
CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('SALE_PAID', 'SALE_CREDIT', 'PAYMENT_RECEIVED')),
    transcription TEXT,
    audio_file_path VARCHAR(500),
    confidence DECIMAL(3,2),
    verified BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for transaction queries
CREATE INDEX idx_customer ON transactions(customer_id);
CREATE INDEX idx_user_timestamp ON transactions(user_id, timestamp);

-- Insert sample users for testing
INSERT INTO users (shop_name, mobile, password, language) VALUES
('Ramesh General Store', '9876543210', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'hi'),
('Suresh Kirana', '9876543211', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'gu'),
('Mahesh Traders', '9876543212', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'en');

-- Insert sample customers
INSERT INTO customers (name, mobile, user_id, total_credit, total_payments, outstanding) VALUES
('Rajesh Kumar', '9123456789', 1, 500.00, 200.00, 300.00),
('Priya Sharma', '9123456790', 1, 1000.00, 1000.00, 0.00),
('Amit Patel', '9123456791', 1, 750.00, 500.00, 250.00);

-- Insert sample transactions
INSERT INTO transactions (customer_id, user_id, amount, type, transcription, confidence, verified) VALUES
(1, 1, 500.00, 'SALE_CREDIT', 'Rajesh ne paanch sau rupay ka maal udhar liya', 0.95, TRUE),
(1, 1, 200.00, 'PAYMENT_RECEIVED', 'Rajesh ne do sau rupay diye', 0.92, TRUE),
(2, 1, 1000.00, 'SALE_CREDIT', 'Priya ne hazaar rupay ka saman liya', 0.88, TRUE),
(2, 1, 1000.00, 'PAYMENT_RECEIVED', 'Priya ne poora paisa de diya', 0.90, TRUE),
(3, 1, 750.00, 'SALE_CREDIT', 'Amit ne saade saat sau rupay udhar liye', 0.85, TRUE),
(3, 1, 500.00, 'PAYMENT_RECEIVED', 'Amit ne paanch sau rupay diye', 0.93, TRUE);

-- Verify data
SELECT 'Users:' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'Customers:', COUNT(*) FROM customers
UNION ALL
SELECT 'Transactions:', COUNT(*) FROM transactions;

-- Show sample data
SELECT 
    c.name as customer_name,
    c.total_credit,
    c.total_payments,
    c.outstanding,
    COUNT(t.id) as transaction_count
FROM customers c
LEFT JOIN transactions t ON c.id = t.customer_id
WHERE c.user_id = 1
GROUP BY c.id, c.name, c.total_credit, c.total_payments, c.outstanding;
