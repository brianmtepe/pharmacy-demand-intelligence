DROP DATABASE IF EXISTS pharmacy_demand_intelligence;
CREATE DATABASE pharmacy_demand_intelligence;
USE pharmacy_demand_intelligence;

-- =====================================================================
-- Pharmacy Operations & Demand Intelligence — Synthetic Demonstration
-- 01_create_tables_mysql.sql
-- MySQL 8.x compatible version (converted from SQL Server DDL)
-- =====================================================================

DROP DATABASE IF EXISTS pharmacy_demand_intelligence;
CREATE DATABASE pharmacy_demand_intelligence;
USE pharmacy_demand_intelligence;

-- ---------------------------------------------------------------------
-- 1. Suppliers
-- ---------------------------------------------------------------------
CREATE TABLE Suppliers (
    Supplier_ID            INT NOT NULL AUTO_INCREMENT,
    Supplier_Name          VARCHAR(100) NOT NULL,
    Supplier_Category      VARCHAR(50) NULL,
    Typical_Lead_Time_Days INT NOT NULL,
    Active                 BIT NOT NULL DEFAULT 1,
    PRIMARY KEY (Supplier_ID)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. Product_Master
-- ---------------------------------------------------------------------
CREATE TABLE Product_Master (
    Product_ID          INT NOT NULL AUTO_INCREMENT,
    Product_Name        VARCHAR(100) NOT NULL,
    Category             VARCHAR(50) NOT NULL,
    Subcategory          VARCHAR(50) NULL,
    Dosage_Form           VARCHAR(30) NULL,
    Strength              VARCHAR(30) NULL,
    Pack_Size              VARCHAR(30) NULL,
    Supplier_ID             INT NULL,
    Unit_Cost                DECIMAL(10,2) NOT NULL,
    Selling_Price             DECIMAL(10,2) NOT NULL,
    Routinely_Stocked          BIT NOT NULL DEFAULT 1,
    Active                      BIT NOT NULL DEFAULT 1,
    PRIMARY KEY (Product_ID),
    CONSTRAINT FK_Product_Supplier
        FOREIGN KEY (Supplier_ID) REFERENCES Suppliers(Supplier_ID),
    CONSTRAINT CK_Price_Positive
        CHECK (Selling_Price >= 0 AND Unit_Cost >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. Sales
-- ---------------------------------------------------------------------
CREATE TABLE Sales (
    Sale_ID              INT NOT NULL AUTO_INCREMENT,
    Sale_Date             DATE NOT NULL,
    Product_ID             INT NOT NULL,
    Quantity                 INT NOT NULL,
    Unit_Selling_Price        DECIMAL(10,2) NOT NULL,
    Revenue                     DECIMAL(10,2) NOT NULL,
    Unit_Cost                    DECIMAL(10,2) NULL,
    Margin                         DECIMAL(10,2) NULL,
    PRIMARY KEY (Sale_ID),
    CONSTRAINT FK_Sales_Product
        FOREIGN KEY (Product_ID) REFERENCES Product_Master(Product_ID),
    CONSTRAINT CK_Sales_Qty_Positive
        CHECK (Quantity > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. Stock_Daily
-- ---------------------------------------------------------------------
CREATE TABLE Stock_Daily (
    Stock_ID        INT NOT NULL AUTO_INCREMENT,
    `Date`           DATE NOT NULL,
    Product_ID        INT NOT NULL,
    Opening_Stock       INT NOT NULL,
    Received              INT NOT NULL DEFAULT 0,
    Sold                    INT NOT NULL DEFAULT 0,
    Adjustments               INT NOT NULL DEFAULT 0,
    Closing_Stock               INT NOT NULL,
    PRIMARY KEY (Stock_ID),
    CONSTRAINT UQ_Stock_ProductDate UNIQUE (Product_ID, `Date`),
    CONSTRAINT FK_Stock_Product
        FOREIGN KEY (Product_ID) REFERENCES Product_Master(Product_ID),
    CONSTRAINT CK_Stock_NonNegative
        CHECK (Opening_Stock >= 0 AND Closing_Stock >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. Orders
-- ---------------------------------------------------------------------
CREATE TABLE Orders (
    Order_ID            INT NOT NULL AUTO_INCREMENT,
    Order_Date            DATE NOT NULL,
    Product_ID              INT NOT NULL,
    Quantity_Ordered          INT NOT NULL,
    Supplier_ID                 INT NOT NULL,
    Reason                        VARCHAR(30) NOT NULL,
    Expected_Date                  DATE NULL,
    Received_Date                    DATE NULL,
    Quantity_Received                  INT NULL,
    PRIMARY KEY (Order_ID),
    CONSTRAINT FK_Orders_Product
        FOREIGN KEY (Product_ID) REFERENCES Product_Master(Product_ID),
    CONSTRAINT FK_Orders_Supplier
        FOREIGN KEY (Supplier_ID) REFERENCES Suppliers(Supplier_ID),
    CONSTRAINT CK_Order_Qty_Positive
        CHECK (Quantity_Ordered > 0),
    CONSTRAINT CK_Order_Reason
        CHECK (Reason IN ('Routine Replenishment','Customer Request','Stock Shortage','Other'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. Customer_Requests
-- ---------------------------------------------------------------------
CREATE TABLE Customer_Requests (
    Request_ID              INT NOT NULL AUTO_INCREMENT,
    Request_Date              DATE NOT NULL,
    Requested_Product_ID        INT NULL,
    Requested_Category            VARCHAR(50) NULL,
    Quantity_Requested               INT NULL,
    Available                          BIT NOT NULL,
    Alternative_Offered                  BIT NOT NULL DEFAULT 0,
    Alternative_Product_ID                 INT NULL,
    Ordered_For_Customer                     BIT NOT NULL DEFAULT 0,
    Order_ID                                   INT NULL,
    Fulfilled_Date                               DATE NULL,
    Outcome                                        VARCHAR(30) NOT NULL,
    PRIMARY KEY (Request_ID),
    CONSTRAINT FK_Request_Product
        FOREIGN KEY (Requested_Product_ID) REFERENCES Product_Master(Product_ID),
    CONSTRAINT FK_Request_Alternative_Product
        FOREIGN KEY (Alternative_Product_ID) REFERENCES Product_Master(Product_ID),
    CONSTRAINT FK_Request_Order
        FOREIGN KEY (Order_ID) REFERENCES Orders(Order_ID),
    CONSTRAINT CK_Request_Outcome
        CHECK (Outcome IN ('Sold','Alternative Accepted','Ordered and Fulfilled','Unavailable','Customer Declined','Other')),
    CONSTRAINT CK_Request_ProductOrCategory
        CHECK (Requested_Product_ID IS NOT NULL OR Requested_Category IS NOT NULL)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Auto-increment starting values (MySQL equivalent of IDENTITY(seed,1))
-- ---------------------------------------------------------------------
ALTER TABLE Suppliers          AUTO_INCREMENT = 1;
ALTER TABLE Product_Master     AUTO_INCREMENT = 101;
ALTER TABLE Sales              AUTO_INCREMENT = 500001;
ALTER TABLE Stock_Daily        AUTO_INCREMENT = 1;
ALTER TABLE Orders             AUTO_INCREMENT = 9001;
ALTER TABLE Customer_Requests  AUTO_INCREMENT = 70001;

-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------
SHOW TABLES;

DESCRIBE Suppliers;
DESCRIBE Product_Master;
DESCRIBE Sales;
DESCRIBE Stock_Daily;
DESCRIBE Orders;
DESCRIBE Customer_Requests;