/* 
 * Title: FinanceDW DDL
 * Assignment 2
 * ---------------------
 *
 * Lionell Carlo Paquit
 * 
 * Schema		: FinanceDW
 * Stage tables	: stage_sales_person, stage_region, stage_sales_region, stage_product_cost, stage_promotion,
 *		stage_kpi, stage_sales_order, stage_sales_order_line_item
 * Dimensions	: DimDate, DimCountry, DimSegment, DimProduct, DimSalesPerson, DimPromotion
 * Facts		: FactSalesRegion, FactKPI, FactProductCost, FactSales
*/
USE master;
GO

-- Create FinanceDW Database
-- WARNING! Do not RE-RUN this DDL when FinanceDW is ALREADY created otherwise the database will be DROPPED.
IF EXISTS (
	SELECT 1 FROM sys.databases WHERE [name] = 'FinanceDW'
) DROP DATABASE FinanceDW;
GO
CREATE DATABASE FinanceDW
ON PRIMARY
(
	NAME = FinanceDW_Data,
	FILENAME = 'C:\DAT701\dbData\FinanceDW_Data.mdf'
)
LOG ON
(
	NAME = FinanceDW_Log,
	FILENAME = 'C:\DAT701\dbLogs\FinanceDW_Log.ldf'
);
GO

ALTER DATABASE FinanceDW SET RECOVERY SIMPLE;
GO

-- Use Finance data warehouse
USE FinanceDW;
GO

/*---------------------
 * Staging Tables
*/---------------------
IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_sales_person' and [type] = 'U'
) DROP TABLE stage_sales_person;
GO
CREATE TABLE stage_sales_person (
  SalesPersonID   int, 
  FirstName       nvarchar(32), 
  LastName        nvarchar(32), 
  Gender          nvarchar(10), 
  HireDate        date, 
  DayOfBirth      date, 
  DaysOfLeave     int NULL, 
  DaysOfSickLeave int NULL 
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_region' and [type] = 'U'
) DROP TABLE stage_region;
GO
CREATE TABLE stage_region (
  RegionID      tinyint,
  CountryID     tinyint, 
  SegmentID     tinyint 
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_sales_region' and [type] = 'U'
) DROP TABLE stage_sales_region;
GO
CREATE TABLE stage_sales_region (
  SalesRegionID	 smallint, 
  RegionID		 tinyint, 
  SalesPersonID	 int
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_product_cost' and [type] = 'U'
) DROP TABLE stage_product_cost;
GO
CREATE TABLE stage_product_cost (
  ProductCostID      int, 
  ProductID          tinyint,
  CountryID          tinyint, 
  ManufacturingPrice money, 
  RRP                money
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_promotion' and [type] = 'U'
) DROP TABLE stage_promotion;
GO
CREATE TABLE stage_promotion (
  PromotionID   int, 
  ProductID     tinyint, 
  PromotionYear smallint, 
  Discount      float(10)
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_kpi' and [type] = 'U'
) DROP TABLE stage_kpi;
GO
CREATE TABLE stage_kpi (
  KPIID			int,
  SalesPersonID int, 
  SalesRegionID smallint,
  SalesYear     smallint, 
  KPI           money
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_sales_order' and [type] = 'U'
) DROP TABLE stage_sales_order;
GO
CREATE TABLE stage_sales_order (
  SalesOrderID         bigint,
  SalesOrderNumber     nvarchar(24),
  SalesOrderDate	   date,
  SalesPersonID        int, 
  SalesRegionID        smallint
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'stage_sales_order_line_item' and [type] = 'U'
) DROP TABLE stage_sales_order_line_item;
GO
CREATE TABLE stage_sales_order_line_item (
  SalesOrderLineItemID bigint,
  SalesOrderID         bigint,
  SalesOrderLineNumber int,
  PromotionID		   int,
  ProductID			   int, 
  UnitsSold            smallint, 
  SalePrice            money
);
GO

/*---------------------
 * DIMENSIONS
*/---------------------

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'DimDate' and [type] = 'U'
) DROP TABLE DimDate;
GO
CREATE TABLE DimDate (
  DateID			   int PRIMARY KEY, 
  FullDate             date NOT NULL UNIQUE, 
  DayNumberOfWeek      tinyint NOT NULL, 
  EnglishDayNameOfWeek nvarchar(10) NOT NULL, 
  SpanishDayNameOfWeek nvarchar(10) NOT NULL, 
  FrenchDayNameOfWeek  nvarchar(10) NOT NULL, 
  GermanDayNameOfWeek  nvarchar(10) NOT NULL, 
  DayNameOfWeekAbbr	   nvarchar(3) NOT NULL,
  MonthNumberOfYear    tinyint NOT NULL, 
  EnglishMonthName     nvarchar(10) NOT NULL, 
  SpanishMonthname     nvarchar(10) NOT NULL, 
  FrenchMonthName      nvarchar(10) NOT NULL, 
  GermanMonthName      nvarchar(10) NOT NULL,
  MonthNameAbbr        nvarchar(3) NOT NULL,
  CalendarYear         smallint NOT NULL, 
  CalendarQuarter      tinyint NOT NULL, 
  CalendarSemester     tinyint NOT NULL
);
GO
 
IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'DimCountry' and [type] = 'U'
) DROP TABLE DimCountry;
GO
CREATE TABLE DimCountry (
  CountryID   tinyint PRIMARY KEY, 
  CountryName nvarchar(28) NOT NULL UNIQUE 
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'DimSegment' and [type] = 'U'
) DROP TABLE DimSegment;
GO
CREATE TABLE DimSegment (
  SegmentID   tinyint PRIMARY KEY, 
  SegmentName nvarchar(28) NOT NULL UNIQUE 
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'DimProduct' and [type] = 'U'
) DROP TABLE DimProduct;
GO
CREATE TABLE DimProduct (
  ProductID   tinyint PRIMARY KEY, 
  ProductName nvarchar(12) NOT NULL UNIQUE
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'DimSalesPerson' and [type] = 'U'
) DROP TABLE DimSalesPerson;
GO
CREATE TABLE DimSalesPerson (
  SalesPersonID   int PRIMARY KEY, 
  FirstName       nvarchar(32) NOT NULL, 
  LastName        nvarchar(32) NOT NULL, 
  Gender          nvarchar(10) NULL, 
  HireDate        date NULL, 
  DayOfBirth      date NULL,  
  DaysOfLeave     int NULL, 
  DaysOfSickLeave int NULL 
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'DimPromotion' and [type] = 'U'
) DROP TABLE DimPromotion;
GO
CREATE TABLE DimPromotion (
  PromotionID   int PRIMARY KEY, 
  ProductID     tinyint FOREIGN KEY REFERENCES DimProduct(ProductID), 
  PromotionYear smallint NULL, 
  Discount      float(10) NULL
);
GO

/*---------------------
 * FACTS
*/---------------------

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'FactSalesRegion' and [type] = 'U'
) DROP TABLE FactSalesRegion;
GO
CREATE TABLE FactSalesRegion (
  SalesRegionID	smallint PRIMARY KEY, 
  CountryID     tinyint FOREIGN KEY REFERENCES DimCountry(CountryID), 
  SegmentID     tinyint FOREIGN KEY REFERENCES DimSegment(SegmentID),
  SalesPersonID int FOREIGN KEY REFERENCES DimSalesPerson(SalesPersonID)
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'FactKPI' and [type] = 'U'
) DROP TABLE FactKPI;
GO
CREATE TABLE FactKPI (
  KPIID			int PRIMARY KEY,
  SalesPersonID int FOREIGN KEY REFERENCES DimSalesPerson(SalesPersonID), 
  CountryID     tinyint FOREIGN KEY REFERENCES DimCountry(CountryID), 
  SegmentID     tinyint FOREIGN KEY REFERENCES DimSegment(SegmentID), 
  SalesYear     smallint NOT NULL, 
  KPI           money NOT NULL
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'FactProductCost' and [type] = 'U'
) DROP TABLE FactProductCost;
GO
CREATE TABLE FactProductCost (
  ProductCostID      int PRIMARY KEY, 
  CountryID          tinyint FOREIGN KEY REFERENCES DimCountry(CountryID), 
  ProductID          tinyint FOREIGN KEY REFERENCES DimProduct(ProductID), 
  ManufacturingPrice money NOT NULL, 
  RRP                money NOT NULL
);
GO

IF EXISTS (
	SELECT 1 FROM sys.tables WHERE [name] = 'FactSales' and [type] = 'U'
) DROP TABLE FactSales;
GO
CREATE TABLE FactSales (
  SalesOrderLineItemID bigint PRIMARY KEY,
  DateOrderID          int FOREIGN KEY REFERENCES DimDate(DateID),
  SalesOrderDate	   date NOT NULL, 
  CountryID            tinyint FOREIGN KEY REFERENCES DimCountry(CountryID), 
  SegmentID            tinyint FOREIGN KEY REFERENCES DimSegment(SegmentID), 
  SalesPersonID        int FOREIGN KEY REFERENCES DimSalesPerson(SalesPersonID), 
  ProductID            tinyint FOREIGN KEY REFERENCES DimProduct(ProductID), 
  ProductCostID        int FOREIGN KEY REFERENCES FactProductCost(ProductCostID), 
  PromotionID          int FOREIGN KEY REFERENCES DimPromotion(PromotionID), 
  SalesOrderID		   bigint NOT NULL, 
  SalesOrderLineNumber int NOT NULL, 
  UnitsSold            smallint NOT NULL, 
  SalePrice            money NOT NULL, 
  Profit			   money NOT NULL
);
GO