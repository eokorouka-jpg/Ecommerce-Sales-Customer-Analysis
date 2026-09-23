USE ecommerce_analysis;

SHOW VARIABLES LIKE 'local_infile';

SELECT COUNT(*) AS rows_before_import
FROM ecommerce_sales;

USE ecommerce_analysis;

CREATE TABLE ecommerce_sales (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(12,2),
    CustomerID DECIMAL(10,1),
    Country VARCHAR(100),
    Revenue DECIMAL(15,2),
    Year INT,
    Month INT,
    MonthName VARCHAR(20),
    YearMonth VARCHAR(10)
);

SELECT DATABASE();

SHOW TABLES;

LOAD DATA LOCAL INFILE
'C:/Users/Owner/Desktop/MyDataScience_Project/Ecommerce Sales Customer Analysis/data/ecommerce_sales_clean.csv'
INTO TABLE ecommerce_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    @CustomerID,
    Country,
    Revenue,
    Year,
    Month,
    MonthName,
    YearMonth
)
SET CustomerID = NULLIF(@CustomerID, '');

SELECT COUNT(*) AS total_rows
FROM ecommerce_sales;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    SUM(Quantity) AS total_units,
    COUNT(DISTINCT StockCode) AS unique_products,
    MIN(InvoiceDate) AS first_sale,
    MAX(InvoiceDate) AS last_sale
FROM ecommerce_sales;

SELECT
    COUNT(DISTINCT StockCode) AS unique_stock_codes,
    COUNT(DISTINCT Description) AS unique_descriptions
FROM ecommerce_sales;

SELECT
    COUNT(*) AS null_stockcodes
FROM ecommerce_sales
WHERE StockCode IS NULL;

SELECT
    MIN(LENGTH(StockCode)) AS min_length,
    MAX(LENGTH(StockCode)) AS max_length
FROM ecommerce_sales;

-- =====================================================
-- STEP 4: SQL BUSINESS ANALYSIS
-- =====================================================

-- 4.1 Overall Sales Performance

SELECT
    ROUND(SUM(Revenue), 2) AS total_revenue,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    SUM(Quantity) AS total_units_sold,
    COUNT(DISTINCT StockCode) AS unique_stock_codes,
    ROUND(
        SUM(Revenue) / COUNT(DISTINCT InvoiceNo),
        2
    ) AS average_order_value
FROM ecommerce_sales;

-- 4.2 Monthly Revenue and Order Trends

SELECT
    YearMonth,
    ROUND(SUM(Revenue), 2) AS monthly_revenue,
    COUNT(DISTINCT InvoiceNo) AS monthly_orders,
    SUM(Quantity) AS units_sold,
    ROUND(
        SUM(Revenue) / COUNT(DISTINCT InvoiceNo),
        2
    ) AS average_order_value
FROM ecommerce_sales
GROUP BY YearMonth
ORDER BY YearMonth;

-- 4.3 Month-over-Month Revenue Growth
-- Using a CTE and LAG() window function

WITH monthly_sales AS (
    SELECT
        YearMonth,
        ROUND(SUM(Revenue), 2) AS monthly_revenue
    FROM ecommerce_sales
    GROUP BY YearMonth
),

revenue_comparison AS (
    SELECT
        YearMonth,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            ORDER BY YearMonth
        ) AS previous_month_revenue
    FROM monthly_sales
)

SELECT
    YearMonth,
    monthly_revenue,
    previous_month_revenue,
    ROUND(
        (monthly_revenue - previous_month_revenue)
        / previous_month_revenue * 100,
        2
    ) AS mom_growth_pct
FROM revenue_comparison
ORDER BY YearMonth;

-- 4.4 Rank Months by Revenue
-- Using RANK() window function

WITH monthly_sales AS (
    SELECT
        YearMonth,
        ROUND(SUM(Revenue), 2) AS monthly_revenue,
        COUNT(DISTINCT InvoiceNo) AS monthly_orders
    FROM ecommerce_sales
    GROUP BY YearMonth
)

SELECT
    YearMonth,
    monthly_revenue,
    monthly_orders,
    RANK() OVER (
        ORDER BY monthly_revenue DESC
    ) AS revenue_rank
FROM monthly_sales
ORDER BY revenue_rank;

-- 4.5 Product Performance
-- Initial product ranking before business-rule exclusions

SELECT
    StockCode,
    Description,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    SUM(Quantity) AS units_sold,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    RANK() OVER (
        ORDER BY SUM(Revenue) DESC
    ) AS revenue_rank
FROM ecommerce_sales
GROUP BY StockCode, Description
ORDER BY total_revenue DESC
LIMIT 15;

-- 4.6 Merchandise Product Performance
-- Exclude operational/non-product codes and the fully reversed anomaly

SELECT
    StockCode,
    Description,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    SUM(Quantity) AS units_sold,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    RANK() OVER (
        ORDER BY SUM(Revenue) DESC
    ) AS revenue_rank
FROM ecommerce_sales
WHERE UPPER(TRIM(StockCode)) NOT IN (
    'DOT',
    'POST',
    'M',
    'AMAZONFEE',
    'B',
    'BANK CHARGES',
    'C2',
    'S'
)
AND UPPER(TRIM(StockCode)) NOT LIKE 'GIFT_%'
AND TRIM(StockCode) <> '23843'
GROUP BY StockCode, Description
ORDER BY total_revenue DESC
LIMIT 10;

-- 4.7 Geographic Sales Performance

SELECT
    Country,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    SUM(Quantity) AS units_sold,
    ROUND(
        SUM(Revenue) / COUNT(DISTINCT InvoiceNo),
        2
    ) AS average_order_value
FROM ecommerce_sales
GROUP BY Country
ORDER BY total_revenue DESC;

-- 4.8 UK vs International Revenue
-- Using conditional aggregation

SELECT
    ROUND(
        SUM(CASE
            WHEN Country = 'United Kingdom'
            THEN Revenue
            ELSE 0
        END),
        2
    ) AS uk_revenue,

    ROUND(
        SUM(CASE
            WHEN Country <> 'United Kingdom'
            THEN Revenue
            ELSE 0
        END),
        2
    ) AS international_revenue,

    ROUND(
        SUM(CASE
            WHEN Country = 'United Kingdom'
            THEN Revenue
            ELSE 0
        END) / SUM(Revenue) * 100,
        2
    ) AS uk_revenue_pct,

    ROUND(
        SUM(CASE
            WHEN Country <> 'United Kingdom'
            THEN Revenue
            ELSE 0
        END) / SUM(Revenue) * 100,
        2
    ) AS international_revenue_pct

FROM ecommerce_sales;

-- 4.9 Customer-Level Metrics
-- Build one summary row per identifiable customer

WITH customer_summary AS (
    SELECT
        CustomerID,
        ROUND(SUM(Revenue), 2) AS total_revenue,
        COUNT(DISTINCT InvoiceNo) AS total_orders,
        SUM(Quantity) AS units_purchased,
        MIN(InvoiceDate) AS first_purchase,
        MAX(InvoiceDate) AS last_purchase,
        ROUND(
            SUM(Revenue) / COUNT(DISTINCT InvoiceNo),
            2
        ) AS average_order_value
    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
)

SELECT *
FROM customer_summary
ORDER BY total_revenue DESC
LIMIT 10;

-- 4.10 Repeat vs One-Time Customers

WITH customer_orders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS total_orders,
        SUM(Revenue) AS total_revenue
    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),

customer_type AS (
    SELECT
        CustomerID,
        total_orders,
        total_revenue,
        CASE
            WHEN total_orders = 1 THEN 'One-Time Customer'
            ELSE 'Repeat Customer'
        END AS customer_segment
    FROM customer_orders
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_pct,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_customer,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer
FROM customer_type
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- 4.11 Customer Revenue Concentration
-- Measure revenue generated by the top 10% of customers

WITH customer_revenue AS (
    SELECT
        CustomerID,
        SUM(Revenue) AS total_revenue
    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),

ranked_customers AS (
    SELECT
        CustomerID,
        total_revenue,
        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC
        ) AS customer_rank,
        COUNT(*) OVER () AS total_customers
    FROM customer_revenue
)

SELECT
    COUNT(*) AS top_10_pct_customers,
    ROUND(SUM(total_revenue), 2) AS top_10_pct_revenue,
    ROUND(
        SUM(total_revenue) /
        (SELECT SUM(total_revenue) FROM customer_revenue)
        * 100,
        2
    ) AS revenue_share_pct
FROM ranked_customers
WHERE customer_rank <= FLOOR(total_customers * 0.10);

-- 4.12 RFM Customer Metrics

WITH rfm_metrics AS (
    SELECT
        CustomerID,

        DATEDIFF(
            '2011-12-10',
            MAX(InvoiceDate)
        ) AS recency_days,

        COUNT(DISTINCT InvoiceNo) AS frequency,

        ROUND(SUM(Revenue), 2) AS monetary_value

    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
)

SELECT *
FROM rfm_metrics
ORDER BY monetary_value DESC
LIMIT 10;

-- 4.13 RFM Scoring
-- Assign customers Recency, Frequency and Monetary scores from 1 to 5

WITH rfm_metrics AS (
    SELECT
        CustomerID,

        DATEDIFF(
            '2011-12-10',
            MAX(InvoiceDate)
        ) AS recency_days,

        COUNT(DISTINCT InvoiceNo) AS frequency,

        ROUND(SUM(Revenue), 2) AS monetary_value

    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),

rfm_scores AS (
    SELECT
        CustomerID,
        recency_days,
        frequency,
        monetary_value,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value ASC
        ) AS monetary_score

    FROM rfm_metrics
)

SELECT *
FROM rfm_scores
ORDER BY monetary_value DESC
LIMIT 10;

-- 4.14 RFM Customer Segmentation

WITH rfm_metrics AS (
    SELECT
        CustomerID,
        DATEDIFF(
            '2011-12-10',
            MAX(InvoiceDate)
        ) AS recency_days,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        ROUND(SUM(Revenue), 2) AS monetary_value
    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),

rfm_scores AS (
    SELECT
        CustomerID,
        recency_days,
        frequency,
        monetary_value,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value ASC
        ) AS monetary_score

    FROM rfm_metrics
),

rfm_segments AS (
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
                 AND frequency_score >= 4
                THEN 'Champions'

            WHEN recency_score >= 3
                 AND frequency_score >= 4
                THEN 'Loyal Customers'

            WHEN recency_score >= 4
                 AND frequency_score BETWEEN 2 AND 3
                THEN 'Potential Loyalists'

            WHEN recency_score >= 4
                 AND frequency_score = 1
                THEN 'New Customers'

            WHEN recency_score BETWEEN 2 AND 3
                 AND frequency_score BETWEEN 2 AND 3
                THEN 'Need Attention'

            WHEN recency_score <= 2
                 AND frequency_score >= 3
                THEN 'At Risk'

            WHEN recency_score <= 2
                 AND frequency_score <= 2
                THEN 'Hibernating'

            ELSE 'Other'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(SUM(monetary_value), 2) AS total_revenue,
    ROUND(AVG(monetary_value), 2) AS avg_customer_value
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- Step 4.15 — RFM Revenue Share

WITH rfm_metrics AS (
    SELECT
        CustomerID,
        DATEDIFF(
            '2011-12-10',
            MAX(InvoiceDate)
        ) AS recency_days,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        ROUND(SUM(Revenue), 2) AS monetary_value
    FROM ecommerce_sales
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),

rfm_scores AS (
    SELECT
        CustomerID,
        recency_days,
        frequency,
        monetary_value,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value ASC
        ) AS monetary_score

    FROM rfm_metrics
),

rfm_segments AS (
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
                 AND frequency_score >= 4
                THEN 'Champions'

            WHEN recency_score >= 3
                 AND frequency_score >= 4
                THEN 'Loyal Customers'

            WHEN recency_score >= 4
                 AND frequency_score BETWEEN 2 AND 3
                THEN 'Potential Loyalists'

            WHEN recency_score >= 4
                 AND frequency_score = 1
                THEN 'New Customers'

            WHEN recency_score BETWEEN 2 AND 3
                 AND frequency_score BETWEEN 2 AND 3
                THEN 'Need Attention'

            WHEN recency_score <= 2
                 AND frequency_score >= 3
                THEN 'At Risk'

            WHEN recency_score <= 2
                 AND frequency_score <= 2
                THEN 'Hibernating'

            ELSE 'Other'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary_value), 2) AS total_revenue,

    ROUND(
        SUM(monetary_value) /
        SUM(SUM(monetary_value)) OVER () * 100,
        2
    ) AS revenue_share_pct

FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- 4.16 Create Cancellation Table

CREATE TABLE ecommerce_cancellations (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(12,4),
    CustomerID DECIMAL(10,1),
    Country VARCHAR(100),
    CancellationValue DECIMAL(15,4)
);

SHOW TABLES;

-- 4.17 Load Cancellation Data

LOAD DATA LOCAL INFILE
'C:/Users/Owner/Desktop/MyDataScience_Project/Ecommerce Sales Customer Analysis/data/ecommerce_cancellations_clean.csv'
INTO TABLE ecommerce_cancellations
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    @CustomerID,
    Country,
    CancellationValue
)
SET CustomerID = NULLIF(@CustomerID, '');

SELECT
    COUNT(*) AS cancellation_rows,
    COUNT(DISTINCT InvoiceNo) AS cancellation_invoices,
    SUM(Quantity) AS cancellation_quantity,
    ROUND(SUM(CancellationValue), 2) AS total_cancellation_value,
    COUNT(DISTINCT CustomerID) AS customers_with_cancellations
FROM ecommerce_cancellations;

-- 4.18 Top Merchandise Products by Cancellation Value

SELECT
    StockCode,
    Description,

    ROUND(SUM(CancellationValue), 2) AS cancellation_value,

    SUM(ABS(Quantity)) AS cancelled_units,

    COUNT(DISTINCT InvoiceNo) AS cancellation_invoices,

    RANK() OVER (
        ORDER BY SUM(CancellationValue) DESC
    ) AS cancellation_rank

FROM ecommerce_cancellations

WHERE UPPER(TRIM(StockCode)) NOT IN (
    'DOT',
    'POST',
    'M',
    'AMAZONFEE',
    'B',
    'BANK CHARGES',
    'C2',
    'S',
    'CRUK',
    'D'
)

AND UPPER(TRIM(StockCode)) NOT LIKE 'GIFT_%'

GROUP BY
    StockCode,
    Description

ORDER BY cancellation_value DESC
LIMIT 10;

-- 4.19 Merchandise Sales vs Cancellations

WITH product_sales AS (
    SELECT
        UPPER(TRIM(StockCode)) AS StockCode,
        ROUND(SUM(Revenue), 2) AS sales_revenue,
        SUM(Quantity) AS units_sold,
        COUNT(DISTINCT InvoiceNo) AS sales_orders
    FROM ecommerce_sales
    WHERE UPPER(TRIM(StockCode)) NOT IN (
        'DOT', 'POST', 'M', 'AMAZONFEE', 'B',
        'BANK CHARGES', 'C2', 'S'
    )
    AND UPPER(TRIM(StockCode)) NOT LIKE 'GIFT_%'
    GROUP BY UPPER(TRIM(StockCode))
),

product_cancellations AS (
    SELECT
        UPPER(TRIM(StockCode)) AS StockCode,
        ROUND(SUM(CancellationValue), 2) AS cancellation_value,
        SUM(ABS(Quantity)) AS cancelled_units,
        COUNT(DISTINCT InvoiceNo) AS cancellation_invoices
    FROM ecommerce_cancellations
    WHERE UPPER(TRIM(StockCode)) NOT IN (
        'DOT', 'POST', 'M', 'AMAZONFEE', 'B',
        'BANK CHARGES', 'C2', 'S', 'CRUK', 'D'
    )
    AND UPPER(TRIM(StockCode)) NOT LIKE 'GIFT_%'
    GROUP BY UPPER(TRIM(StockCode))
)

SELECT
    s.StockCode,
    s.sales_revenue,
    c.cancellation_value,

    ROUND(
        c.cancellation_value / s.sales_revenue * 100,
        2
    ) AS cancellation_value_pct,

    s.units_sold,
    c.cancelled_units,

    ROUND(
        c.cancelled_units / s.units_sold * 100,
        2
    ) AS cancelled_units_pct,

    s.sales_orders,
    c.cancellation_invoices

FROM product_sales s
INNER JOIN product_cancellations c
    ON s.StockCode = c.StockCode

WHERE s.sales_revenue > 0

ORDER BY c.cancellation_value DESC
LIMIT 10;

/* =========================================================
   4.20 FINAL SQL BUSINESS INSIGHTS
   =========================================================

1. SALES PERFORMANCE
   - Gross positive-sales revenue: £10.64M.
   - 19,960 orders generated 5.57M units sold.
   - Average order value was approximately £533.17.
   - November 2011 was the highest complete revenue month,
     generating approximately £1.50M from 2,769 orders.
   - September to November showed particularly strong sales activity.
   - December 2011 is a partial month and should not be directly
     compared with complete months.

2. GEOGRAPHIC PERFORMANCE
   - The United Kingdom generated approximately £9.00M,
     representing 84.59% of gross positive-sales revenue.
   - International markets contributed approximately 15.41%.
   - Several international markets showed high average order values,
     despite substantially lower order volumes than the UK.

3. CUSTOMER BEHAVIOUR
   - 4,338 identifiable customers were analysed.
   - 65.58% were repeat purchasers.
   - Repeat customers generated approximately £8.27M,
     representing 93.09% of identifiable-customer gross
     positive-sales revenue.
   - The top 10% of customers generated 61.41% of identifiable-
     customer gross positive-sales revenue, indicating strong
     revenue concentration.

4. RFM CUSTOMER SEGMENTATION
   - Champions generated 67.05% of identifiable-customer revenue.
   - Loyal Customers contributed a further 9.18%.
   - The At Risk segment contained 262 customers associated with
     approximately £515.58K in historical gross positive-sales
     revenue, making this group relevant for re-engagement analysis.
   - RFM segments are analytical business-rule classifications
     rather than universal customer categories.

5. PRODUCT PERFORMANCE
   - REGENCY CAKESTAND 3 TIER was one of the strongest merchandise
     products by gross positive-sales revenue.
   - Product-code and description inconsistencies were identified,
     demonstrating the importance of product master-data
     standardisation.

6. CANCELLATION ANALYSIS
   - 9,251 cancellation transaction rows were identified across
     3,836 cancellation invoices.
   - Total cancellation value was approximately £893.98K.
   - 1,589 identifiable customers were associated with at least
     one cancellation.
   - Product 23843 showed a complete reversal: £168,469.60 of
     positive sales and the same value cancelled.
   - Product 23166 had cancellation value equivalent to 94.83%
     of its gross positive-sales revenue.
   - Product 23113 also showed a high comparison at 81.84%.
   - These percentages compare cancellation value with gross
     positive-sales revenue and should not be interpreted as
     formal refund or return rates because cancellations are not
     explicitly linked to their originating invoices.

========================================================= */