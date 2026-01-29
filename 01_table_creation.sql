-- ============================================================================
-- 01_table_creation.sql
-- Purpose: Create tables for SaaS analytics database
-- Author: Data Analyst Assessment
-- Date: 2026-01-29
-- ============================================================================

-- Drop existing tables if they exist (for clean runs)
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS customers;

-- ============================================================================
-- CUSTOMERS TABLE
-- ============================================================================
-- Stores customer profile and signup information
-- Primary key: customer_id

CREATE TABLE customers (
    customer_id VARCHAR(10) PRIMARY KEY,
    signup_date DATE,
    segment VARCHAR(50),
    country VARCHAR(5),
    is_enterprise BOOLEAN,
    INDEX idx_signup_date (signup_date),
    INDEX idx_segment (segment),
    INDEX idx_country (country)
);

-- ============================================================================
-- SUBSCRIPTIONS TABLE
-- ============================================================================
-- Stores subscription lifecycle and revenue data
-- Primary key: subscription_id
-- Foreign key: customer_id -> customers

CREATE TABLE subscriptions (
    subscription_id VARCHAR(10) PRIMARY KEY,
    customer_id VARCHAR(10) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_price DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_start_date (start_date),
    INDEX idx_end_date (end_date),
    INDEX idx_status (status)
);

-- ============================================================================
-- EVENTS TABLE
-- ============================================================================
-- Stores user funnel events and acquisition source data
-- Primary key: event_id
-- Foreign key: customer_id -> customers

CREATE TABLE events (
    event_id VARCHAR(10) PRIMARY KEY,
    customer_id VARCHAR(10) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_date DATE NOT NULL,
    source VARCHAR(50) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_event_type (event_type),
    INDEX idx_event_date (event_date),
    INDEX idx_source (source)
);

-- ============================================================================
-- DATA LOADING NOTES
-- ============================================================================
-- Use the following commands to load data (adjust path as needed):
--
-- LOAD DATA LOCAL INFILE 'data/customers.csv'
-- INTO TABLE customers
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;
--
-- LOAD DATA LOCAL INFILE 'data/subscriptions.csv'
-- INTO TABLE subscriptions
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;
--
-- LOAD DATA LOCAL INFILE 'data/events.csv'
-- INTO TABLE events
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;
--
-- ============================================================================

-- Verify table creation
SHOW TABLES;
