-- =====================================================
-- FRAUD DETECTION SQL PROJECT
-- Data & Fraud Analysis Queries
-- Author: Bárbara Luise
-- =====================================================

-- =====================================================
-- 1. TRANSACTION OVERVIEW
-- =====================================================

-- Get summary statistics of all transactions
SELECT 
    COUNT(*) AS total_transactions,
    SUM(amount) AS total_amount,
    AVG(amount) AS average_amount,
    MIN(amount) AS minimum_amount,
    MAX(amount) AS maximum_amount,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT transaction_date) AS active_days
FROM transactions;

-- =====================================================
-- 2. FRAUD DETECTION - SUSPICIOUS PATTERNS
-- =====================================================

-- Identify transactions with unusually high amounts
SELECT 
    transaction_id,
    customer_id,
    amount,
    transaction_date,
    merchant_category,
    ROUND(amount / (SELECT AVG(amount) FROM transactions), 2) AS amount_multiplier,
    CASE 
        WHEN amount > (SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions) 
        THEN 'HIGH RISK'
        WHEN amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions) 
        THEN 'MEDIUM RISK'
        ELSE 'NORMAL'
    END AS risk_level
FROM transactions
WHERE amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions)
ORDER BY amount DESC;

-- Detect multiple transactions from same customer in short time window
SELECT 
    customer_id,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT DATE(transaction_date)) AS days_active,
    SUM(amount) AS total_amount,
    MAX(amount) AS max_transaction,
    MIN(transaction_date) AS first_transaction,
    MAX(transaction_date) AS last_transaction
FROM transactions
WHERE transaction_date >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY customer_id
HAVING COUNT(*) > 5
ORDER BY transaction_count DESC;

-- Identify geographic inconsistencies (impossible travel)
SELECT 
    t1.customer_id,
    t1.merchant_location AS location_1,
    t2.merchant_location AS location_2,
    t1.transaction_date AS time_1,
    t2.transaction_date AS time_2,
    TIMESTAMPDIFF(MINUTE, t1.transaction_date, t2.transaction_date) AS minutes_between,
    CASE 
        WHEN TIMESTAMPDIFF(MINUTE, t1.transaction_date, t2.transaction_date) < 30 
        THEN 'IMPOSSIBLE TRAVEL - ALERT'
        ELSE 'VERIFY'
    END AS flag
FROM transactions t1
JOIN transactions t2 
    ON t1.customer_id = t2.customer_id 
    AND t1.transaction_id < t2.transaction_id
    AND t1.merchant_location != t2.merchant_location
WHERE t1.transaction_date >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    AND TIMESTAMPDIFF(MINUTE, t1.transaction_date, t2.transaction_date) < 120
ORDER BY customer_id, t1.transaction_date;

-- =====================================================
-- 3. CUSTOMER BEHAVIOR ANALYSIS
-- =====================================================

-- Customer spending patterns by category
SELECT 
    c.customer_id,
    c.customer_name,
    t.merchant_category,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS category_total,
    AVG(t.amount) AS avg_transaction,
    ROUND(SUM(t.amount) / (SELECT SUM(amount) FROM transactions WHERE customer_id = c.customer_id) * 100, 2) AS pct_of_total_spending
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.customer_name, t.merchant_category
ORDER BY c.customer_id, category_total DESC;

-- Identify customers with unusual spending behavior
SELECT 
    customer_id,
    COUNT(*) AS transactions_this_month,
    SUM(amount) AS spending_this_month,
    AVG(amount) AS avg_transaction_amount,
    MAX(amount) AS largest_transaction,
    COUNT(DISTINCT merchant_category) AS unique_categories,
    CASE 
        WHEN SUM(amount) > (SELECT AVG(monthly_spending) FROM customer_metrics) * 2 
        THEN 'HIGH SPENDER'
        WHEN COUNT(*) > 50 
        THEN 'FREQUENT_USER'
        WHEN COUNT(DISTINCT merchant_category) > 10 
        THEN 'DIVERSE_SPENDING'
        ELSE 'NORMAL'
    END AS spending_pattern
FROM transactions
WHERE MONTH(transaction_date) = MONTH(NOW())
    AND YEAR(transaction_date) = YEAR(NOW())
GROUP BY customer_id
ORDER BY spending_this_month DESC;

-- =====================================================
-- 4. MERCHANT ANALYSIS
-- =====================================================

-- Top merchants by transaction volume and amount
SELECT 
    merchant_id,
    merchant_name,
    merchant_category,
    COUNT(*) AS total_transactions,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_transaction,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM customers) * 100, 2) AS pct_customer_base
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
GROUP BY merchant_id, merchant_name, merchant_category
ORDER BY total_revenue DESC
LIMIT 20;

-- Merchants with suspicious activity patterns
SELECT 
    m.merchant_id,
    m.merchant_name,
    m.merchant_category,
    COUNT(*) AS transactions_last_7days,
    SUM(t.amount) AS revenue_last_7days,
    AVG(t.amount) AS avg_transaction,
    COUNT(DISTINCT t.customer_id) AS unique_customers,
    CASE 
        WHEN AVG(t.amount) > (SELECT AVG(amount) * 1.5 FROM transactions) 
        THEN 'HIGH_AVG_AMOUNT'
        WHEN COUNT(*) > 100 
        THEN 'HIGH_VOLUME'
        ELSE 'NORMAL'
    END AS merchant_flag
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.transaction_date >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY m.merchant_id, m.merchant_name, m.merchant_category
HAVING COUNT(*) > 20
ORDER BY revenue_last_7days DESC;

-- =====================================================
-- 5. TIME-BASED ANALYSIS
-- =====================================================

-- Hourly transaction distribution (identify off-peak fraud)
SELECT 
    HOUR(transaction_date) AS hour_of_day,
    COUNT(*) AS transaction_count,
    SUM(amount) AS hourly_total,
    AVG(amount) AS avg_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM transactions WHERE DATE(transaction_date) = CURDATE()) * 100, 2) AS pct_daily_volume
FROM transactions
WHERE DATE(transaction_date) = CURDATE()
GROUP BY HOUR(transaction_date)
ORDER BY hour_of_day;

-- Weekly trend analysis
SELECT 
    WEEK(transaction_date) AS week_number,
    DATE_FORMAT(transaction_date, '%Y-%m-%d') AS week_start,
    COUNT(*) AS transactions,
    SUM(amount) AS weekly_total,
    AVG(amount) AS avg_transaction,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(CASE WHEN amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions) THEN 1 END) AS high_value_transactions
FROM transactions
WHERE transaction_date >= DATE_SUB(NOW(), INTERVAL 12 WEEK)
GROUP BY WEEK(transaction_date), week_start
ORDER BY transaction_date DESC;

-- =====================================================
-- 6. RISK SCORING MODEL
-- =====================================================

-- Comprehensive risk assessment per transaction
SELECT 
    t.transaction_id,
    t.customer_id,
    t.merchant_id,
    t.amount,
    t.transaction_date,
    (
        CASE WHEN t.amount > (SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions) THEN 30 ELSE 0 END +
        CASE WHEN HOUR(t.transaction_date) IN (2, 3, 4, 5) THEN 15 ELSE 0 END +
        CASE WHEN t.amount > (SELECT MAX(amount) * 0.8 FROM transactions WHERE customer_id = t.customer_id) THEN 20 ELSE 0 END +
        CASE WHEN (SELECT COUNT(*) FROM transactions WHERE customer_id = t.customer_id AND DATE(transaction_date) = DATE(t.transaction_date)) > 10 THEN 15 ELSE 0 END +
        CASE WHEN t.merchant_category IN ('GAMBLING', 'HIGH_RISK') THEN 10 ELSE 0 END
    ) AS risk_score,
    CASE 
        WHEN (SELECT COUNT(*) FROM transactions) IS NULL THEN 'NO_DATA'
        WHEN (CASE WHEN t.amount > (SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions) THEN 30 ELSE 0 END +
              CASE WHEN HOUR(t.transaction_date) IN (2, 3, 4, 5) THEN 15 ELSE 0 END +
              CASE WHEN t.amount > (SELECT MAX(amount) * 0.8 FROM transactions WHERE customer_id = t.customer_id) THEN 20 ELSE 0 END +
              CASE WHEN (SELECT COUNT(*) FROM transactions WHERE customer_id = t.customer_id AND DATE(transaction_date) = DATE(t.transaction_date)) > 10 THEN 15 ELSE 0 END +
              CASE WHEN t.merchant_category IN ('GAMBLING', 'HIGH_RISK') THEN 10 ELSE 0 END) >= 60 THEN 'HIGH_RISK'
        WHEN (CASE WHEN t.amount > (SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions) THEN 30 ELSE 0 END +
              CASE WHEN HOUR(t.transaction_date) IN (2, 3, 4, 5) THEN 15 ELSE 0 END +
              CASE WHEN t.amount > (SELECT MAX(amount) * 0.8 FROM transactions WHERE customer_id = t.customer_id) THEN 20 ELSE 0 END +
              CASE WHEN (SELECT COUNT(*) FROM transactions WHERE customer_id = t.customer_id AND DATE(transaction_date) = DATE(t.transaction_date)) > 10 THEN 15 ELSE 0 END +
              CASE WHEN t.merchant_category IN ('GAMBLING', 'HIGH_RISK') THEN 10 ELSE 0 END) >= 30 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS risk_classification
FROM transactions t
WHERE t.transaction_date >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY risk_score DESC
LIMIT 100;

-- =====================================================
-- 7. COMPLIANCE & REPORTING
-- =====================================================

-- Daily fraud alert summary
SELECT 
    DATE(transaction_date) AS transaction_date,
    COUNT(*) AS total_transactions,
    COUNT(CASE WHEN amount > (SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions) THEN 1 END) AS high_value_count,
    SUM(CASE WHEN amount > (SELECT AVG(amount) + 3 * STDDEV(amount) FROM transactions) THEN amount ELSE 0 END) AS high_value_amount,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT merchant_id) AS unique_merchants
FROM transactions
WHERE transaction_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(transaction_date)
ORDER BY transaction_date DESC;

-- Customer risk profile summary
SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_email,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_spending,
    COUNT(CASE WHEN t.amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions) THEN 1 END) AS suspicious_transactions,
    ROUND(COUNT(CASE WHEN t.amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions) THEN 1 END) / COUNT(t.transaction_id) * 100, 2) AS suspicious_pct,
    MAX(t.transaction_date) AS last_transaction,
    CASE 
        WHEN COUNT(CASE WHEN t.amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions) THEN 1 END) > 5 THEN 'HIGH_PRIORITY_REVIEW'
        WHEN COUNT(CASE WHEN t.amount > (SELECT AVG(amount) + 2 * STDDEV(amount) FROM transactions) THEN 1 END) > 2 THEN 'STANDARD_REVIEW'
        ELSE 'LOW_RISK'
    END AS review_status
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
WHERE t.transaction_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY c.customer_id, c.customer_name, c.customer_email
ORDER BY suspicious_transactions DESC;

-- =====================================================
-- END OF FRAUD DETECTION QUERIES
-- =====================================================
