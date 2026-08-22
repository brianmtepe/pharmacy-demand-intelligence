-- =====================================================================
-- Pharmacy Operations & Demand Intelligence — Synthetic Demonstration
-- 03_sql/03_analytical_views_mysql.sql
-- =====================================================================
USE pharmacy_demand_intelligence;

-- A. SALES -------------------------------------------------------------
DROP VIEW IF EXISTS vw_sales_trends;
CREATE VIEW vw_sales_trends AS
SELECT
    s.Sale_Date,
    p.Category,
    p.Product_Name,
    SUM(s.Quantity) AS Units_Sold,
    SUM(s.Revenue)  AS Total_Revenue
FROM Sales s
JOIN Product_Master p ON s.Product_ID = p.Product_ID
GROUP BY s.Sale_Date, p.Category, p.Product_Name;

-- B. REQUESTS ------------------------------------------------------------
DROP VIEW IF EXISTS vw_requests_summary;
CREATE VIEW vw_requests_summary AS
SELECT
    COALESCE(p.Category, cr.Requested_Category) AS Category,
    COALESCE(p.Product_Name, cr.Requested_Category) AS Product_Or_Category,
    COUNT(*) AS Request_Count,
    SUM(CASE WHEN cr.Available = 0 THEN 1 ELSE 0 END) AS Unavailable_Count
FROM Customer_Requests cr
LEFT JOIN Product_Master p ON cr.Requested_Product_ID = p.Product_ID
GROUP BY COALESCE(p.Category, cr.Requested_Category),
         COALESCE(p.Product_Name, cr.Requested_Category);

-- C. AVAILABILITY --------------------------------------------------------
DROP VIEW IF EXISTS vw_availability;
CREATE VIEW vw_availability AS
SELECT
    Request_Date,
    COUNT(*) AS Total_Requests,
    SUM(CASE WHEN Available = 0 THEN 1 ELSE 0 END) AS Unavailable_Requests,
    ROUND(SUM(CASE WHEN Available = 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 4) AS Unavailable_Rate
FROM Customer_Requests
GROUP BY Request_Date;

-- D. STOCK MOVEMENT --------------------------------------------------------
DROP VIEW IF EXISTS vw_product_movement;
CREATE VIEW vw_product_movement AS
SELECT
    p.Product_ID, p.Product_Name, p.Category, p.Routinely_Stocked,
    SUM(sd.Sold) AS Total_Units_Sold,
    SUM(CASE WHEN sd.Closing_Stock = 0 THEN 1 ELSE 0 END) AS Stockout_Days
FROM Stock_Daily sd
JOIN Product_Master p ON sd.Product_ID = p.Product_ID
GROUP BY p.Product_ID, p.Product_Name, p.Category, p.Routinely_Stocked;

-- E. ORDERING -----------------------------------------------------------
DROP VIEW IF EXISTS vw_order_reasons;
CREATE VIEW vw_order_reasons AS
SELECT Reason, COUNT(*) AS Order_Count, SUM(Quantity_Ordered) AS Units_Ordered
FROM Orders
GROUP BY Reason;

-- F. SUPPLIER FULFILLMENT ------------------------------------------------
-- NOTE: MySQL DATEDIFF(date1, date2) = date1 - date2 in days
--       (order is reversed vs. SQL Server's DATEDIFF(day, start, end))
DROP VIEW IF EXISTS vw_supplier_performance;
CREATE VIEW vw_supplier_performance AS
SELECT
    s.Supplier_Name,
    COUNT(o.Order_ID) AS Total_Orders,
    ROUND(AVG(DATEDIFF(o.Received_Date, o.Order_Date)), 1) AS Avg_Fulfillment_Days,
    SUM(CASE WHEN o.Received_Date IS NULL THEN 1 ELSE 0 END) AS Unresolved_Orders
FROM Orders o
JOIN Suppliers s ON o.Supplier_ID = s.Supplier_ID
GROUP BY s.Supplier_Name;

-- G. ASSORTMENT -----------------------------------------------------------

DROP VIEW IF EXISTS vw_assortment_review;
CREATE VIEW vw_assortment_review AS
WITH sales_by_product AS (
    SELECT Product_ID, SUM(Quantity) AS Units_Sold_Period
    FROM Sales
    GROUP BY Product_ID
),
requests_by_product AS (
    SELECT Requested_Product_ID AS Product_ID, COUNT(*) AS Request_Count
    FROM Customer_Requests
    WHERE Requested_Product_ID IS NOT NULL
    GROUP BY Requested_Product_ID
),
avg_sales AS (
    SELECT AVG(Units_Sold_Period) AS Avg_Units FROM sales_by_product
)
SELECT
    p.Product_ID, p.Product_Name, p.Category, p.Routinely_Stocked,
    COALESCE(sbp.Units_Sold_Period, 0) AS Units_Sold_Period,
    COALESCE(rbp.Request_Count, 0) AS Request_Count,
    CASE
        WHEN p.Routinely_Stocked = 0 AND COALESCE(rbp.Request_Count, 0) >= 5
            THEN 'Review: Frequently requested, not routinely stocked'
        WHEN p.Routinely_Stocked = 1 AND COALESCE(sbp.Units_Sold_Period, 0) < (SELECT Avg_Units * 0.25 FROM avg_sales)
            THEN 'Review: Stocked, low movement'
        ELSE NULL
    END AS Review_Flag
FROM Product_Master p
LEFT JOIN sales_by_product sbp ON p.Product_ID = sbp.Product_ID
LEFT JOIN requests_by_product rbp ON p.Product_ID = rbp.Product_ID;

-- Quick smoke test after creation:
SELECT * FROM vw_assortment_review WHERE Review_Flag IS NOT NULL ORDER BY Request_Count DESC;
