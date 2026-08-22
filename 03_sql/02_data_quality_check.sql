-- =====================================================================
-- Pharmacy Operations & Demand Intelligence — Synthetic Demonstration
-- 05_sql/02_data_quality_checks_mysql.sql
-- Run after loading data. Every query should return 0 rows except where noted.
-- =====================================================================
USE pharmacy_demand_intelligence;

-- Duplicates
SELECT Sale_ID, COUNT(*) AS n FROM Sales GROUP BY Sale_ID HAVING COUNT(*) > 1;

-- Missing Product_ID references
SELECT s.* FROM Sales s LEFT JOIN Product_Master p ON s.Product_ID = p.Product_ID WHERE p.Product_ID IS NULL;

-- Invalid dates (future dates, or before data start)
SELECT * FROM Sales WHERE Sale_Date > CURDATE() OR Sale_Date < '2025-01-01';

-- Negative/zero quantities
SELECT * FROM Sales WHERE Quantity <= 0;
SELECT * FROM Orders WHERE Quantity_Ordered <= 0;

-- Impossible stock balances
-- NOTE: rows where Closing_Stock = 0 due to a write-off adjustment exceeding
-- available stock are EXPECTED (floor-at-zero business rule) and will show
-- here as a mismatch — review individually rather than treating all flagged
-- rows as errors.
SELECT * FROM Stock_Daily
WHERE Closing_Stock <> (Opening_Stock + Received - Sold + Adjustments)
   OR Opening_Stock < 0 OR Closing_Stock < 0;

-- Orders received before ordered
SELECT * FROM Orders WHERE Received_Date IS NOT NULL AND Received_Date < Order_Date;

-- Sales for inactive products
SELECT s.* FROM Sales s JOIN Product_Master p ON s.Product_ID = p.Product_ID WHERE p.Active = 0;

-- Active products missing a supplier
SELECT * FROM Product_Master WHERE Active = 1 AND Supplier_ID IS NULL;

-- Orders referencing an inactive supplier (should be investigated, not necessarily an error)
SELECT o.* FROM Orders o JOIN Suppliers s ON o.Supplier_ID = s.Supplier_ID WHERE s.Active = 0;

-- Duplicate product records (same name+form+strength)
SELECT Product_Name, Dosage_Form, Strength, COUNT(*) AS n
FROM Product_Master GROUP BY Product_Name, Dosage_Form, Strength HAVING COUNT(*) > 1;

-- Inconsistent categories (visual scan for case/whitespace variants)
SELECT DISTINCT Category FROM Product_Master ORDER BY Category;

-- Customer_Requests referencing a non-existent Order_ID
SELECT cr.* FROM Customer_Requests cr
LEFT JOIN Orders o ON cr.Order_ID = o.Order_ID
WHERE cr.Order_ID IS NOT NULL AND o.Order_ID IS NULL;

-- Requests missing both a specific product and a category (should never happen)
SELECT * FROM Customer_Requests WHERE Requested_Product_ID IS NULL AND Requested_Category IS NULL;

-- Fulfilled_Date earlier than Request_Date (logically impossible)
SELECT * FROM Customer_Requests WHERE Fulfilled_Date IS NOT NULL AND Fulfilled_Date < Request_Date;