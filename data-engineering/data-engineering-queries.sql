-- ============================================
-- DATA ENGINEERING SQL INTERVIEW QUERIES
-- ============================================

-- ============================================
-- 1. INCREMENTAL DATA LOAD PATTERN
-- ============================================

-- Create tables
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

-- ============================================
-- 2. SLOWLY CHANGING DIMENSION (SCD) TYPE 2
-- ============================================

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

-- Expire current record
UPDATE dim_customer
SET expiry_date = CURRENT_DATE - INTERVAL 1 DAY,
    is_current = FALSE
WHERE customer_id = 101
  AND is_current = TRUE;

-- Insert new version
INSERT INTO dim_customer (customer_id, customer_name, email, city, effective_date, expiry_date, is_current)
VALUES (101, 'John Doe', 'john.new@email.com', 'New York', CURRENT_DATE, '9999-12-31', TRUE);

-- Query customer history
SELECT customer_id, customer_name, email, city, 
       effective_date, expiry_date, is_current
FROM dim_customer
WHERE customer_id = 101
ORDER BY effective_date DESC;

-- ============================================
-- 3. DATA DEDUPLICATION FOR KAFKA STREAMS
-- ============================================

CREATE TABLE kafka_events (
    event_id VARCHAR(50),
    partition_id INT,
    offset_id BIGINT,
    event_data JSON,
    event_timestamp TIMESTAMP,
    ingestion_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

-- ============================================
-- 4. WINDOWED AGGREGATIONS (TUMBLING WINDOW)
-- ============================================

CREATE TABLE sensor_readings (
    sensor_id INT,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    reading_timestamp TIMESTAMP
);

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

-- ============================================
-- 5. LATE ARRIVING DATA HANDLING
-- ============================================

CREATE TABLE event_stream (
    event_id VARCHAR(50),
    user_id INT,
    event_type VARCHAR(50),
    event_time TIMESTAMP,
    processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

-- ============================================
-- 6. DATA QUALITY CHECKS
-- ============================================

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    amount DECIMAL(10,2),
    status VARCHAR(20)
);

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

-- ============================================
-- 7. DUPLICATE DETECTION ACROSS PARTITIONS
-- ============================================

CREATE TABLE distributed_data (
    record_id VARCHAR(50),
    partition_key VARCHAR(50),
    data_value VARCHAR(200),
    created_at TIMESTAMP
);

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

-- ============================================
-- 8. PARTITION PRUNING QUERY
-- ============================================

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

-- Efficient query with partition pruning
SELECT 
    region,
    COUNT(*) as sale_count,
    SUM(amount) as total_amount
FROM sales_partitioned
WHERE sale_date >= '2024-01-01' 
  AND sale_date < '2024-04-01'
  AND region = 'North'
GROUP BY region;

-- Check partition usage
EXPLAIN PARTITIONS
SELECT * FROM sales_partitioned
WHERE sale_date BETWEEN '2024-01-01' AND '2024-03-31';

-- ============================================
-- 9. BATCH PROCESSING OPTIMIZATION
-- ============================================

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

-- ============================================
-- 10. STAR SCHEMA QUERY
-- ============================================

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

-- ============================================
-- 11. CUMULATIVE METRICS
-- ============================================

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

-- ============================================
-- 12. EVENT SOURCING QUERY PATTERN
-- ============================================

CREATE TABLE account_events (
    event_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    event_type VARCHAR(50),
    amount DECIMAL(10,2),
    event_timestamp TIMESTAMP,
    metadata JSON
);

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

-- ============================================
-- 13. CDC (CHANGE DATA CAPTURE) PATTERN
-- ============================================

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
WHERE change_id IN (1, 2, 3, 4, 5);

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

-- ============================================
-- 14. SAGA PATTERN - DISTRIBUTED TRANSACTION
-- ============================================

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

-- ============================================
-- 15. TIME-SERIES DATA ANALYSIS
-- ============================================

CREATE TABLE pipeline_metrics (
    metric_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(100),
    metric_name VARCHAR(50),
    metric_value DECIMAL(15,2),
    recorded_at TIMESTAMP
);

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

-- ============================================
-- 16. UPSERT PATTERN (MERGE/INSERT ON DUPLICATE)
-- ============================================

-- MySQL UPSERT using INSERT ... ON DUPLICATE KEY UPDATE
INSERT INTO target_table (id, name, value, updated_at)
VALUES (1, 'Product A', 100.00, NOW())
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    value = VALUES(value),
    updated_at = NOW();

-- Batch UPSERT
INSERT INTO target_table (id, name, value, updated_at)
SELECT id, name, value, NOW()
FROM staging_table
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    value = VALUES(value),
    updated_at = NOW();

-- ============================================
-- 17. DATA LINEAGE TRACKING
-- ============================================

CREATE TABLE data_lineage (
    lineage_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_table VARCHAR(100),
    source_record_id INT,
    target_table VARCHAR(100),
    target_record_id INT,
    transformation_name VARCHAR(100),
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Track data lineage
INSERT INTO data_lineage (source_table, source_record_id, target_table, target_record_id, transformation_name)
SELECT 
    'raw_orders' as source_table,
    order_id as source_record_id,
    'fact_orders' as target_table,
    order_key as target_record_id,
    'etl_orders_transform' as transformation_name
FROM raw_orders r
INNER JOIN fact_orders f ON r.order_id = f.source_order_id
WHERE r.processed_date = CURRENT_DATE;

-- Query lineage for a specific record
SELECT 
    source_table,
    source_record_id,
    target_table,
    target_record_id,
    transformation_name,
    processed_at
FROM data_lineage
WHERE target_table = 'fact_orders'
  AND target_record_id = 12345
ORDER BY processed_at;

-- ============================================
-- 18. IDEMPOTENT ETL PATTERN
-- ============================================

-- Delete and reload pattern for idempotency
DELETE FROM target_table
WHERE batch_date = '2024-03-01';

INSERT INTO target_table (id, name, value, batch_date)
SELECT id, name, value, '2024-03-01'
FROM source_table
WHERE DATE(created_at) = '2024-03-01';

-- Using staging table for idempotent loads
TRUNCATE TABLE staging_table;

LOAD DATA INFILE '/path/to/data.csv'
INTO TABLE staging_table
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Merge from staging to target
INSERT INTO target_table
SELECT * FROM staging_table
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    value = VALUES(value);

-- ============================================
-- 19. BACKFILL QUERY PATTERN
-- ============================================

-- Backfill missing dates in time-series data
WITH RECURSIVE date_range AS (
    SELECT DATE('2024-01-01') as date_value
    UNION ALL
    SELECT DATE_ADD(date_value, INTERVAL 1 DAY)
    FROM date_range
    WHERE date_value < '2024-12-31'
)
SELECT 
    dr.date_value,
    COALESCE(s.total_sales, 0) as total_sales,
    COALESCE(s.order_count, 0) as order_count
FROM date_range dr
LEFT JOIN (
    SELECT 
        DATE(order_date) as order_date,
        SUM(amount) as total_sales,
        COUNT(*) as order_count
    FROM orders
    GROUP BY DATE(order_date)
) s ON dr.date_value = s.order_date
ORDER BY dr.date_value;

-- ============================================
-- 20. PIPELINE MONITORING QUERIES
-- ============================================

CREATE TABLE pipeline_runs (
    run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(100),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(20),
    records_processed INT,
    records_failed INT,
    error_message TEXT
);

-- Pipeline health dashboard query
SELECT 
    pipeline_name,
    COUNT(*) as total_runs,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_runs,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
    AVG(TIMESTAMPDIFF(SECOND, start_time, end_time)) as avg_duration_seconds,
    SUM(records_processed) as total_records_processed,
    MAX(end_time) as last_run_time
FROM pipeline_runs
WHERE start_time >= CURRENT_DATE - INTERVAL 7 DAY
GROUP BY pipeline_name
ORDER BY failed_runs DESC, pipeline_name;

-- Identify slow-running pipelines
SELECT 
    pipeline_name,
    run_id,
    start_time,
    end_time,
    TIMESTAMPDIFF(SECOND, start_time, end_time) as duration_seconds,
    records_processed,
    records_processed / TIMESTAMPDIFF(SECOND, start_time, end_time) as records_per_second
FROM pipeline_runs
WHERE status = 'SUCCESS'
  AND start_time >= CURRENT_DATE - INTERVAL 1 DAY
  AND TIMESTAMPDIFF(SECOND, start_time, end_time) > (
      SELECT AVG(TIMESTAMPDIFF(SECOND, start_time, end_time)) * 2
      FROM pipeline_runs
      WHERE status = 'SUCCESS'
  )
ORDER BY duration_seconds DESC;
