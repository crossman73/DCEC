-- PostgreSQL initialization script

-- Create a new database
CREATE DATABASE my_database;

-- Create a new user with a password
CREATE USER my_user WITH ENCRYPTED PASSWORD 'my_password';

-- Grant all privileges on the database to the new user
GRANT ALL PRIVILEGES ON DATABASE my_database TO my_user;

-- Create a sample table
CREATE TABLE my_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data into the table
INSERT INTO my_table (name) VALUES ('Sample Data 1'), ('Sample Data 2');