# Data Engineering SQL Interview Questions

This document contains SQL queries and solutions specifically designed for data engineering interviews, covering data pipelines, ETL processes, streaming data, and integration with modern data stack technologies.

## Table of Contents
1. [Data Pipeline & ETL Queries](#data-pipeline--etl-queries)
2. [Streaming Data & Real-time Processing](#streaming-data--real-time-processing)
3. [Data Quality & Validation](#data-quality--validation)
4. [Performance & Optimization](#performance--optimization)
5. [Data Warehousing & Analytics](#data-warehousing--analytics)
6. [Microservices Data Integration](#microservices-data-integration)

---

## Data Pipeline & ETL Queries

### 1. Incremental Data Load Pattern
**Problem**: Design a query to identify new/updated records for incremental ETL processing.

**Schema**:
```sql
CREATE TABLE source_data (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    value DECIMAL(10,2),
    last_modified TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE etl_metadata (
    table_name VARCHAR(100) PRIMARY KEY,
    last_processed_timestamp TIMESTAMP
);
```

**Solution**:
```sql
-- Get incremental changes since last ETL run
SELECT s.*
FROM source_data s
CROSS JOIN etl_metadata e
WHERE e.table_name = 'source_data'
  AND s.last_modified > e.last_processed_timestamp
  AND s.is_deleted = FALSE;

-- Update metadata after successful load
UPDATE etl_metadata
SET last_processed_timestamp = CURRENT_TIMESTAMP
WHERE table_name = 'source_data';
```

### 2. Slowly Changing Dimension (SCD) Type 2
**Problem**: Implement SCD Type 2 to track historical changes in dimension data.

**Schema**:
```sql
CREATE TABLE dim_customer (
    customer_key INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    city VARCHAR(50),
    effective_date DATE,
    expiry_date DATE,
    is_current BOOLEAN DEFAULT TRUE
);
```

**Solution**:
```sql
-- Insert new record and expire old one for changed customer
-- Step 1: Expire current record
UPDATE dim_customer
SET expiry_date = CURRENT_DATE - INTERVAL 1 DAY,
    is_current = FALSE
WHERE customer_id = 101
  AND is_current = TRUE;

-- Step 2: Insert new version
INSERT INTO dim_customer (customer_id, customer_name, email, city, effective_date, expiry_date, is_current)
VALUES (101, 'John Doe', 'john.new@email.com', 'New York', CURRENT_DATE, '9999-12-31', TRUE);

-- Query to get customer history
SELECT customer_id, customer_name, email, city, 
       effective_date, expiry_date, is_current
FROM dim_customer
WHERE customer_id = 101
ORDER BY effective_date DESC;
```

### 3. Data Deduplication for Kafka Streams
**Problem**: Remove duplicate records from streaming data ingestion (simulating Kafka consumer behavior).

**Schema**:
```sql
CREATE TABLE kafka_events (
    event_id VARCHAR(50),
    partition_id INT,
    offset_id BIGINT,
    event_data JSON,
    event_timestamp TIMESTAMP,
    ingestion_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Solution**:
```sql
-- Deduplicate using ROW_NUMBER (keep latest by offset)
WITH ranked_events AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY event_id 
               ORDER BY offset_id DESC
           ) as rn
    FROM kafka_events
    WHERE DATE(ingestion_time) = CURRENT_DATE
)
SELECT event_id, partition_id, offset_id, event_data, event_timestamp
FROM ranked_events
WHERE rn = 1;

-- Alternative: Using GROUP BY for deduplication
SELECT event_id,
       MAX(partition_id) as partition_id,
       MAX(offset_id) as offset_id,
       MAX(event_data) as event_data,
       MAX(event_timestamp) as event_timestamp
FROM kafka_events
WHERE DATE(ingestion_time) = CURRENT_DATE
GROUP BY event_id;
```

---

## Streaming Data & Real-time Processing

### 4. Windowed Aggregations (Tumbling Window)
**Problem**: Calculate 5-minute tumbling window aggregations for real-time metrics.

**Schema**:
```sql
CREATE TABLE sensor_readings (
    sensor_id INT,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    reading_timestamp TIMESTAMP
);
```

**Solution**:
```sql
-- 5-minute tumbling window aggregation
SELECT 
    sensor_id,
    DATE_FORMAT(
        FROM_UNIXTIME(
            FLOOR(UNIX_TIMESTAMP(reading_timestamp) / 300) * 300
        ), 
        '%Y-%m-%d %H:%i:00'
    ) as window_start,
    COUNT(*) as reading_count,
    AVG(temperature) as avg_temperature,
    MAX(temperature) as max_temperature,
    MIN(temperature) as min_temperature,
    AVG(humidity) as avg_humidity
FROM sensor_readings
WHERE reading_timestamp >= NOW() - INTERVAL 1 HOUR
GROUP BY 
    sensor_id,
    FLOOR(UNIX_TIMESTAMP(reading_timestamp) / 300);
```

### 5. Late Arriving Data Handling
**Problem**: Handle late-arriving events in a streaming pipeline with watermarking.

**Schema**:
```sql
CREATE TABLE event_stream (
    event_id VARCHAR(50),
    user_id INT,
    event_type VARCHAR(50),
    event_time TIMESTAMP,
    processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Solution**:
```sql
-- Identify late events (arrived more than 10 minutes after event time)
SELECT 
    event_id,
    user_id,
    event_type,
    event_time,
    processing_time,
    TIMESTAMPDIFF(MINUTE, event_time, processing_time) as lateness_minutes
FROM event_stream
WHERE TIMESTAMPDIFF(MINUTE, event_time, processing_time) > 10
ORDER BY lateness_minutes DESC;

-- Reprocess late events within acceptable window
WITH acceptable_events AS (
    SELECT *
    FROM event_stream
    WHERE TIMESTAMPDIFF(MINUTE, event_time, processing_time) <= 60
)
SELECT 
    user_id,
    event_type,
    DATE(event_time) as event_date,
    COUNT(*) as event_count
FROM acceptable_events
GROUP BY user_id, event_type, DATE(event_time);
```

---

## Data Quality & Validation

### 6. Data Quality Checks
**Problem**: Implement comprehensive data quality validation for ETL pipeline.

**Schema**:
```sql
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    amount DECIMAL(10,2),
    status VARCHAR(20)
);
```

**Solution**:
```sql
-- Comprehensive data quality report
SELECT 
    'Null Check' as check_type,
    'customer_id' as column_name,
    COUNT(*) as failed_records
FROM orders
WHERE customer_id IS NULL
UNION ALL
SELECT 
    'Null Check',
    'amount',
    COUNT(*)
FROM orders
WHERE amount IS NULL
UNION ALL
SELECT 
    'Range Check',
    'amount',
    COUNT(*)
FROM orders
WHERE amount < 0 OR amount > 1000000
UNION ALL
SELECT 
    'Date Check',
    'order_date',
    COUNT(*)
FROM orders
WHERE order_date > CURRENT_DATE OR order_date < '2020-01-01'
UNION ALL
SELECT 
    'Referential Integrity',
    'customer_id',
    COUNT(*)
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

### 7. Duplicate Detection Across Partitions
**Problem**: Detect duplicates in partitioned data (common in distributed systems like Spark).

**Schema**:
```sql
CREATE TABLE distributed_data (
    record_id VARCHAR(50),
    partition_key VARCHAR(50),
    data_value VARCHAR(200),
    created_at TIMESTAMP
);
```

**Solution**:
```sql
-- Find duplicates across all partitions
SELECT 
    record_id,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(DISTINCT partition_key) as partitions,
    MIN(created_at) as first_seen,
    MAX(created_at) as last_seen
FROM distributed_data
GROUP BY record_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Get detailed duplicate records
WITH duplicate_ids AS (
    SELECT record_id
    FROM distributed_data
    GROUP BY record_id
    HAVING COUNT(*) > 1
)
SELECT d.*
FROM distributed_data d
INNER JOIN duplicate_ids dup ON d.record_id = dup.record_id
ORDER BY d.record_id, d.created_at;
```

---

## Performance & Optimization

### 8. Partition Pruning Query
**Problem**: Write queries optimized for partitioned tables (common in data lakes).

**Schema**:
```sql
CREATE TABLE sales_partitioned (
    sale_id INT,
    product_id INT,
    amount DECIMAL(10,2),
    sale_date DATE,
    region VARCHAR(50)
) PARTITION BY RANGE (YEAR(sale_date)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025)
);
```

**Solution**:
```sql
-- Efficient query with partition pruning
SELECT 
    region,
    COUNT(*) as sale_count,
    SUM(amount) as total_amount
FROM sales_partitioned
WHERE sale_date >= '2024-01-01' 
  AND sale_date < '2024-04-01'  -- Partition pruning
  AND region = 'North'
GROUP BY region;

-- Check partition usage
EXPLAIN PARTITIONS
SELECT * FROM sales_partitioned
WHERE sale_date BETWEEN '2024-01-01' AND '2024-03-31';
```

### 9. Batch Processing Optimization
**Problem**: Optimize bulk insert operations for ETL pipelines.

**Solution**:
```sql
-- Efficient bulk insert with INSERT INTO SELECT
INSERT INTO target_table (id, name, value, processed_date)
SELECT 
    id,
    name,
    value,
    CURRENT_DATE
FROM staging_table
WHERE status = 'READY'
  AND NOT EXISTS (
      SELECT 1 FROM target_table t 
      WHERE t.id = staging_table.id
  );

-- Batch update using CASE statement
UPDATE large_table
SET 
    status = CASE 
        WHEN amount > 1000 THEN 'HIGH'
        WHEN amount > 500 THEN 'MEDIUM'
        ELSE 'LOW'
    END,
    processed_flag = TRUE
WHERE processed_flag = FALSE
  AND created_date >= CURRENT_DATE - INTERVAL 7 DAY;
```

---

## Data Warehousing & Analytics

### 10. Star Schema Query
**Problem**: Query a star schema for analytical reporting.

**Schema**:
```sql
CREATE TABLE fact_sales (
    sale_id INT PRIMARY KEY,
    date_key INT,
    product_key INT,
    customer_key INT,
    store_key INT,
    quantity INT,
    amount DECIMAL(10,2)
);

CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    date DATE,
    year INT,
    quarter INT,
    month INT,
    day_of_week VARCHAR(10)
);

CREATE TABLE dim_product (
    product_key INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50)
);
```

**Solution**:
```sql
-- Multi-dimensional analysis
SELECT 
    d.year,
    d.quarter,
    p.category,
    p.subcategory,
    COUNT(DISTINCT f.sale_id) as transaction_count,
    SUM(f.quantity) as total_quantity,
    SUM(f.amount) as total_revenue,
    AVG(f.amount) as avg_transaction_value
FROM fact_sales f
INNER JOIN dim_date d ON f.date_key = d.date_key
INNER JOIN dim_product p ON f.product_key = p.product_key
WHERE d.year = 2024
GROUP BY d.year, d.quarter, p.category, p.subcategory
ORDER BY d.quarter, total_revenue DESC;
```

### 11. Cumulative Metrics
**Problem**: Calculate running totals and cumulative metrics for dashboards.

**Solution**:
```sql
-- Running total and moving average
SELECT 
    sale_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7day
FROM (
    SELECT 
        DATE(sale_timestamp) as sale_date,
        SUM(amount) as daily_revenue
    FROM sales
    GROUP BY DATE(sale_timestamp)
) daily_sales
ORDER BY sale_date;
```

---

## Microservices Data Integration

### 12. Event Sourcing Query Pattern
**Problem**: Query event-sourced data to rebuild current state.

**Schema**:
```sql
CREATE TABLE account_events (
    event_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    event_type VARCHAR(50),
    amount DECIMAL(10,2),
    event_timestamp TIMESTAMP,
    metadata JSON
);
```

**Solution**:
```sql
-- Rebuild current account balance from events
SELECT 
    account_id,
    SUM(CASE 
        WHEN event_type = 'DEPOSIT' THEN amount
        WHEN event_type = 'WITHDRAWAL' THEN -amount
        ELSE 0
    END) as current_balance,
    COUNT(*) as total_transactions,
    MAX(event_timestamp) as last_transaction_time
FROM account_events
WHERE account_id = 12345
GROUP BY account_id;

-- Get account state at specific point in time
SELECT 
    account_id,
    SUM(CASE 
        WHEN event_type = 'DEPOSIT' THEN amount
        WHEN event_type = 'WITHDRAWAL' THEN -amount
        ELSE 0
    END) as balance_at_time
FROM account_events
WHERE account_id = 12345
  AND event_timestamp <= '2024-01-15 23:59:59'
GROUP BY account_id;
```

### 13. CDC (Change Data Capture) Pattern
**Problem**: Track and process database changes for microservices synchronization.

**Schema**:
```sql
CREATE TABLE cdc_log (
    change_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100),
    operation_type ENUM('INSERT', 'UPDATE', 'DELETE'),
    record_id INT,
    old_values JSON,
    new_values JSON,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE
);
```

**Solution**:
```sql
-- Get unprocessed changes for downstream services
SELECT 
    change_id,
    table_name,
    operation_type,
    record_id,
    new_values,
    changed_at
FROM cdc_log
WHERE processed = FALSE
  AND table_name IN ('orders', 'customers', 'products')
ORDER BY change_id
LIMIT 1000;

-- Mark changes as processed
UPDATE cdc_log
SET processed = TRUE
WHERE change_id IN (/* list of processed IDs */);

-- Aggregate changes by table for monitoring
SELECT 
    table_name,
    operation_type,
    COUNT(*) as change_count,
    MIN(changed_at) as oldest_change,
    MAX(changed_at) as newest_change
FROM cdc_log
WHERE processed = FALSE
GROUP BY table_name, operation_type;
```

### 14. Saga Pattern - Distributed Transaction Query
**Problem**: Query saga execution state across microservices.

**Schema**:
```sql
CREATE TABLE saga_execution (
    saga_id VARCHAR(50) PRIMARY KEY,
    saga_type VARCHAR(50),
    status VARCHAR(20),
    started_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE TABLE saga_steps (
    step_id INT AUTO_INCREMENT PRIMARY KEY,
    saga_id VARCHAR(50),
    service_name VARCHAR(50),
    step_name VARCHAR(50),
    status VARCHAR(20),
    request_data JSON,
    response_data JSON,
    executed_at TIMESTAMP,
    FOREIGN KEY (saga_id) REFERENCES saga_execution(saga_id)
);
```

**Solution**:
```sql
-- Get saga execution details with all steps
SELECT 
    se.saga_id,
    se.saga_type,
    se.status as saga_status,
    ss.service_name,
    ss.step_name,
    ss.status as step_status,
    ss.executed_at,
    TIMESTAMPDIFF(SECOND, se.started_at, COALESCE(se.completed_at, NOW())) as duration_seconds
FROM saga_execution se
LEFT JOIN saga_steps ss ON se.saga_id = ss.saga_id
WHERE se.saga_id = 'saga-12345'
ORDER BY ss.executed_at;

-- Find failed sagas requiring compensation
SELECT 
    se.saga_id,
    se.saga_type,
    COUNT(ss.step_id) as total_steps,
    SUM(CASE WHEN ss.status = 'COMPLETED' THEN 1 ELSE 0 END) as completed_steps,
    SUM(CASE WHEN ss.status = 'FAILED' THEN 1 ELSE 0 END) as failed_steps
FROM saga_execution se
INNER JOIN saga_steps ss ON se.saga_id = ss.saga_id
WHERE se.status = 'FAILED'
GROUP BY se.saga_id, se.saga_type
HAVING failed_steps > 0;
```

---

## Additional Topics

### 15. Time-Series Data Analysis
**Problem**: Analyze time-series metrics for monitoring pipelines.

**Schema**:
```sql
CREATE TABLE pipeline_metrics (
    metric_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(100),
    metric_name VARCHAR(50),
    metric_value DECIMAL(15,2),
    recorded_at TIMESTAMP
);
```

**Solution**:
```sql
-- Calculate pipeline performance metrics
SELECT 
    pipeline_name,
    DATE(recorded_at) as metric_date,
    AVG(CASE WHEN metric_name = 'processing_time_ms' THEN metric_value END) as avg_processing_time,
    MAX(CASE WHEN metric_name = 'processing_time_ms' THEN metric_value END) as max_processing_time,
    SUM(CASE WHEN metric_name = 'records_processed' THEN metric_value END) as total_records,
    SUM(CASE WHEN metric_name = 'errors' THEN metric_value END) as total_errors
FROM pipeline_metrics
WHERE recorded_at >= CURRENT_DATE - INTERVAL 7 DAY
GROUP BY pipeline_name, DATE(recorded_at)
ORDER BY pipeline_name, metric_date;

-- Detect anomalies using standard deviation
WITH stats AS (
    SELECT 
        pipeline_name,
        AVG(metric_value) as mean_value,
        STDDEV(metric_value) as std_dev
    FROM pipeline_metrics
    WHERE metric_name = 'processing_time_ms'
      AND recorded_at >= NOW() - INTERVAL 24 HOUR
    GROUP BY pipeline_name
)
SELECT 
    pm.pipeline_name,
    pm.recorded_at,
    pm.metric_value,
    s.mean_value,
    s.std_dev,
    (pm.metric_value - s.mean_value) / s.std_dev as z_score
FROM pipeline_metrics pm
INNER JOIN stats s ON pm.pipeline_name = s.pipeline_name
WHERE pm.metric_name = 'processing_time_ms'
  AND ABS((pm.metric_value - s.mean_value) / s.std_dev) > 3
ORDER BY pm.recorded_at DESC;
```

---

## Interview Tips

1. **Understand the Data Pipeline**: Be ready to explain how your SQL fits into ETL/ELT workflows
2. **Scalability**: Discuss how queries perform on large datasets (billions of rows)
3. **Idempotency**: Ensure queries can be safely re-run without side effects
4. **Partitioning Strategy**: Know when and how to partition data
5. **Streaming vs Batch**: Understand the trade-offs and appropriate use cases
6. **Data Quality**: Always consider validation and error handling
7. **Monitoring**: Include queries for pipeline observability
8. **Integration**: Explain how SQL integrates with Spark, Kafka, Airflow, etc.

=============
Done! I've created a comprehensive data engineering SQL interview resource in the data-engineering folder with:

data-engineering-queries.md - Detailed explanations with 15 major topics covering:

ETL/ELT patterns (incremental loads, SCD Type 2)
Streaming data (Kafka deduplication, windowed aggregations, late data handling)
Data quality checks and validation
Performance optimization (partitioning, batch processing)
Data warehousing (star schema, cumulative metrics)
Microservices patterns (event sourcing, CDC, saga pattern)
Time-series analysis and anomaly detection
data-engineering-queries.sql - 20 executable SQL queries covering:

Pipeline monitoring and health checks
Idempotent ETL patterns
Data lineage tracking
Backfill strategies
UPSERT operations
All the patterns from the markdown file
The queries are specifically tailored for data engineering roles working with modern data stacks including Kafka, Spark, microservices architectures, and distributed systems. Each query includes practical scenarios you'd encounter in real-world data pipelines.
============