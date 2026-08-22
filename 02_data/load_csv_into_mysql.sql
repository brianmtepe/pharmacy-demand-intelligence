-- =====================================================================
-- Pharmacy Operations & Demand Intelligence — Synthetic Demonstration
-- 04_load_csv_into_mysql.sql  (FULL REPLACEMENT — BIT -> TINYINT fix applied)
--
-- BEFORE RUNNING:
-- 1. Confirm LOCAL INFILE is enabled:
--      SHOW GLOBAL VARIABLES LIKE 'local_infile';   -- must show ON
--      If OFF: SET GLOBAL local_infile = 1;
-- 2. Confirm this connection's Advanced tab has: OPT_LOCAL_INFILE=1
--    in the "Others" box, and that you're on a FRESH connection
--    (closed and reopened) since making that change.
-- 3. Update the file paths below to your actual clean/ folder location.
-- =====================================================================
USE pharmacy_demand_intelligence;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- SCHEMA FIX: BIT columns don't reliably load via LOAD DATA INFILE.
-- Convert all flag columns to TINYINT(1), which behaves as expected.
-- ---------------------------------------------------------------------
ALTER TABLE Suppliers          MODIFY Active TINYINT NOT NULL DEFAULT 1;

ALTER TABLE Product_Master     MODIFY Routinely_Stocked TINYINT NOT NULL DEFAULT 1,
                                MODIFY Active TINYINT NOT NULL DEFAULT 1;

ALTER TABLE Customer_Requests  MODIFY Available TINYINT NOT NULL,
                                MODIFY Alternative_Offered TINYINT NOT NULL DEFAULT 0,
                                MODIFY Ordered_For_Customer TINYINT NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------
-- CLEAR ALL TABLES (child tables first, to respect foreign keys)
-- ---------------------------------------------------------------------
TRUNCATE TABLE Customer_Requests;
TRUNCATE TABLE Stock_Daily;
TRUNCATE TABLE Sales;
TRUNCATE TABLE Orders;
TRUNCATE TABLE Product_Master;
TRUNCATE TABLE Suppliers;

-- ---------------------------------------------------------------------
-- 1. Suppliers
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/USER/Desktop/pharmacy-demand-intelligence/04_synthetic_data/clean/Suppliers.csv'
INTO TABLE Suppliers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Supplier_ID, Supplier_Name, Supplier_Category, Typical_Lead_Time_Days, Active);

-- ---------------------------------------------------------------------
-- 2. Product_Master
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/USER/Desktop/pharmacy-demand-intelligence/04_synthetic_data/clean/Product_Master.csv'
INTO TABLE Product_Master
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Product_ID, Product_Name, Category, Subcategory, Dosage_Form, Strength, Pack_Size,
 Supplier_ID, Unit_Cost, Selling_Price, Routinely_Stocked, Active);

-- ---------------------------------------------------------------------
-- 3. Orders (before Customer_Requests, which references Order_ID)
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/USER/Desktop/pharmacy-demand-intelligence/04_synthetic_data/clean/Orders.csv'
INTO TABLE Orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Order_ID, Order_Date, Product_ID, Quantity_Ordered, Supplier_ID, Reason,
 Expected_Date, @Received_Date, @Quantity_Received)
SET Received_Date = NULLIF(@Received_Date, ''),
    Quantity_Received = NULLIF(@Quantity_Received, '');

-- ---------------------------------------------------------------------
-- 4. Sales
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/USER/Desktop/pharmacy-demand-intelligence/04_synthetic_data/clean/Sales.csv'
INTO TABLE Sales
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Sale_ID, Sale_Date, Product_ID, Quantity, Unit_Selling_Price, Revenue, Unit_Cost, Margin);

-- ---------------------------------------------------------------------
-- 5. Stock_Daily
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/USER/Desktop/pharmacy-demand-intelligence/04_synthetic_data/clean/Stock_Daily.csv'
INTO TABLE Stock_Daily
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Stock_ID, `Date`, Product_ID, Opening_Stock, Received, Sold, Adjustments, Closing_Stock);

-- ---------------------------------------------------------------------
-- 6. Customer_Requests (loaded last: references Product_Master AND Orders)
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/USER/Desktop/pharmacy-demand-intelligence/04_synthetic_data/clean/Customer_Requests.csv'
INTO TABLE Customer_Requests
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Request_ID, Request_Date, @Requested_Product_ID, @Requested_Category, @Quantity_Requested,
 Available, Alternative_Offered, @Alternative_Product_ID, Ordered_For_Customer,
 @Order_ID, @Fulfilled_Date, Outcome)
SET Requested_Product_ID = NULLIF(@Requested_Product_ID, ''),
    Requested_Category = NULLIF(@Requested_Category, ''),
    Quantity_Requested = NULLIF(@Quantity_Requested, ''),
    Alternative_Product_ID = NULLIF(@Alternative_Product_ID, ''),
    Order_ID = NULLIF(@Order_ID, ''),
    Fulfilled_Date = NULLIF(@Fulfilled_Date, '');

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- VERIFY: row counts
-- ---------------------------------------------------------------------
SELECT 'Suppliers' AS tbl, COUNT(*) FROM Suppliers
UNION ALL SELECT 'Product_Master', COUNT(*) FROM Product_Master
UNION ALL SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL SELECT 'Sales', COUNT(*) FROM Sales
UNION ALL SELECT 'Stock_Daily', COUNT(*) FROM Stock_Daily
UNION ALL SELECT 'Customer_Requests', COUNT(*) FROM Customer_Requests;

-- ---------------------------------------------------------------------
-- VERIFY: the actual bug fix — Available should now show TWO groups
-- ---------------------------------------------------------------------
SELECT Available, COUNT(*) FROM Customer_Requests GROUP BY Available;

SELECT Routinely_Stocked, COUNT(*) FROM Product_Master GROUP BY Routinely_Stocked;

-- ---------------------------------------------------------------------
-- VERIFY: the signal itself — Antimalarial Option C should be near top
-- ---------------------------------------------------------------------
SELECT * FROM vw_requests_summary ORDER BY Unavailable_Count DESC LIMIT 10;