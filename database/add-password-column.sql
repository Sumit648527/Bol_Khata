-- Add password column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS password VARCHAR(255);

-- Update existing users with a default password (change this!)
UPDATE users SET password = 'password123' WHERE password IS NULL;
