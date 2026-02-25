-- Create database (created by docker postgres)
-- This script runs automatically when container starts

CREATE TABLE IF NOT EXISTS todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO todos (title, completed) VALUES
    ('Learn Docker', false),
    ('Master Docker Compose', false),
    ('Deploy to AWS', false),
    ('Become DevOps Engineer', false);
