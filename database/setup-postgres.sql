-- Bol-Khata PostgreSQL Database Setup Script

-- Create database
CREATE DATABASE bolkhata;

-- Connect to the database
\c bolkhata

-- Enable pg_trgm extension for fuzzy text matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enable unaccent extension for better name matching
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Create custom function for phonetic matching (optional)
-- This helps with Indian name variations
CREATE OR REPLACE FUNCTION soundex_match(text1 TEXT, text2 TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN similarity(text1, text2) > 0.8;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Verify extensions
SELECT * FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent');

-- Show database info
SELECT current_database(), current_user, version();

COMMENT ON DATABASE bolkhata IS 'Bol-Khata Voice-First Financial Ledger Database';
