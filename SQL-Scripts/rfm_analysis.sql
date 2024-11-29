
-- Step 1: Calculate Recency (How recently a customer made a purchase.)
WITH recency AS (
    SELECT 
        customer_id,
        MAX(invoice_date) AS last_purchase_date,
        DATEDIFF(DAY, MAX(invoice_date), GETDATE()) AS recency		-- Days since the customer’s last purchase.
    FROM online_retail_staging
    GROUP BY customer_id
),

-- Step 2: Calculate Frequency (How often a customer makes a purchase.)
frequency AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT invoice_no) AS frequency		-- Total number of transactions per customer.
    FROM online_retail_staging
    GROUP BY customer_id
),

-- Step 3: Calculate Monetary (How much money a customer spends.)
monetary AS (
    SELECT 
        customer_id,
        SUM(total_price) AS monetary		-- Total spending per customer.
    FROM online_retail_staging
    GROUP BY customer_id
),

-- Step 4: Combine RFM metrics (Recency, Frequency, Monetary)
rfm AS (
    SELECT 
        r.customer_id, 
        r.recency, 
        f.frequency, 
        m.monetary
    FROM recency r
    JOIN frequency f ON r.customer_id = f.customer_id
    JOIN monetary m ON r.customer_id = m.customer_id
),

-- Step 5: Rank customers into quartiles
ranked_rfm AS (
    SELECT *,
        NTILE(4) OVER(ORDER BY recency DESC) AS recency_score,
        NTILE(4) OVER(ORDER BY frequency DESC) AS frequency_score,
        NTILE(4) OVER(ORDER BY monetary DESC) AS monetary_score
    FROM rfm
),

-- Step 6: Segment customers based on RFM scores
customer_segment AS (
    SELECT 
        customer_id, 
        recency, 
        frequency, 
        monetary, 
        recency_score, 
        frequency_score, 
        monetary_score,
        CASE
			-- Best Customers: High engagement across all metrics (recent, frequent, and high spenders)
            WHEN recency_score = 1 AND frequency_score = 1 AND monetary_score = 1 THEN 'Best Customers'
			-- At Risk Customers: Previously frequent and high spenders, but their recent engagement is low
            WHEN recency_score = 4 AND frequency_score = 1 AND monetary_score = 1 THEN 'At Risk Customers'
			-- Low Value Customers: Low engagement across all metrics (infrequent, low spenders, and not recent)
            WHEN recency_score = 4 AND frequency_score = 4 AND monetary_score = 4 THEN 'Low Value Customers'
			-- Lost Customers: Previously engaged with high frequency and spending, but recent inactivity
            WHEN recency_score = 1 AND frequency_score = 4 AND monetary_score = 4 THEN 'Lost Customers'
			-- New Customers: Recently engaged with low monetary value but higher potential based on frequency
            WHEN recency_score = 4 AND frequency_score = 4 AND monetary_score = 1 THEN 'New Customers'
			-- Regular Customers: Mid-range engagement across all metrics
            WHEN recency_score BETWEEN 2 AND 3 AND frequency_score BETWEEN 2 AND 3 AND monetary_score BETWEEN 2 AND 3 THEN 'Regular Customers'
			-- Other: Customers who do not fit into the predefined categories
            ELSE 'Other'
        END AS customer_segment
    FROM ranked_rfm
)

-- Step 7: Summarize RFM Segments
SELECT 
    customer_segment,
    COUNT(customer_id) AS num_customers,
    SUM(monetary) AS total_revenue,
	-- Calculate the percentage of customers
    CAST(COUNT(customer_id) * 100.0 / (SELECT COUNT(*) FROM customer_segment) AS DECIMAL(10, 2)) AS pct_customers,
	-- Calculate the percentage of revenue
    CAST(SUM(monetary) * 100.0 / (SELECT SUM(monetary) FROM customer_segment) AS DECIMAL(10, 2)) AS pct_revenue
FROM customer_segment
GROUP BY customer_segment
ORDER BY pct_revenue DESC;
