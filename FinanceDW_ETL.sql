/* 
 * Title: FinanceDW ETL
 * Assignment 2
 * ---------------------
 *
 *
 * Lionell Carlo Paquit
 * 
 *
 * Notes:
 * Currently DimDate_Lookup.csv file is populated upto the year 2017 if there are sales order exceeding that year
 * the csv file needs to be rebuild and repopulated
*/

USE FinanceDW;
GO

/*---------------------
 * Stored Procedure ETL for DIMENSIONS
*/---------------------

-- ETL SProcs for extracting data from Financedb to staging tables
-- 
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_extract_stage_tables' and [type] = 'P')
	DROP PROCEDURE etl_extract_stage_tables;
GO
CREATE PROCEDURE etl_extract_stage_tables 
AS
BEGIN
	
	-- Truncate staging tables
	TRUNCATE TABLE stage_sales_person;
	TRUNCATE TABLE stage_region;
	TRUNCATE TABLE stage_sales_region;
	TRUNCATE TABLE stage_product_cost;

	-- stage_sales_person
	INSERT INTO stage_sales_person
		SELECT
			SalesPersonID,
			FirstName,
			LastName,
			Gender,
			HireDate,
			DayOfBirth,
			DaysOfLeave,
			DaysOfSickLeave
		FROM [7.0.1.15].[FinanceDB].[dbo].[SalesPerson];

	-- stage_sales_region
	INSERT INTO stage_region
		SELECT
			RegionID,
			CountryID, 
			SegmentID
		FROM [7.0.1.15].[FinanceDB].[dbo].[Region];

	-- stage_sales_region
	INSERT INTO stage_sales_region
		SELECT
			SalesRegionID, 
			RegionID, 
			SalesPersonID
		FROM [7.0.1.15].[FinanceDB].[dbo].[SalesRegion];

	-- stage_product_cost
	INSERT INTO stage_product_cost
		SELECT
			ProductCostID,
			ProductID,
			CountryID,
			ManufacturingPrice, 
			RRP
		FROM [7.0.1.15].[FinanceDB].[dbo].[ProductCost];


END;
GO

-- ETL SProcs for extracting data from Financedb to stage_promotion with
-- paramater @start_year
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_extract_stage_promotion' and [type] = 'P')
	DROP PROCEDURE etl_extract_stage_promotion;
GO
CREATE PROCEDURE etl_extract_stage_promotion @start_year INT
AS
BEGIN
	
	-- Truncate staging tables
	TRUNCATE TABLE stage_promotion;

	-- stage_promotion
	INSERT INTO stage_promotion
		SELECT
			PromotionID,
			ProductID,
			PromotionYear,
			Discount
		FROM [7.0.1.15].[FinanceDB].[dbo].[Promotion]
		WHERE PromotionYear >= @start_year
			OR PromotionYear IS NULL;		-- This is because there is one promotion with PromotionID 0 that has NULL values it will cause
END;										-- foreign key restriction during inserting of sales. Thinking of fixing this in the future
GO

-- ETL SProcs for extracting data from Financedb to stage_kpi with
-- paramater @start_year
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_extract_stage_kpi' and [type] = 'P')
	DROP PROCEDURE etl_extract_stage_kpi;
GO
CREATE PROCEDURE etl_extract_stage_kpi @start_year INT
AS
BEGIN
	
	-- Truncate staging tables
	TRUNCATE TABLE stage_kpi;

	-- stage_KPI
	INSERT INTO stage_kpi
		SELECT
			KPIID,
			SalesPersonID, 
			SalesRegionID,
			SalesYear, 
			KPI
		FROM [7.0.1.15].[FinanceDB].[dbo].[SalesKPI]
		WHERE SalesYear >= @start_year;
END;
GO


-- ETL SProcs for extracting data from Financedb to stage_stage_sales with
-- paramater @start_date
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_extract_stage_sales' and [type] = 'P')
	DROP PROCEDURE etl_extract_stage_sales;
GO
CREATE PROCEDURE etl_extract_stage_sales @start_date DATE
AS
BEGIN
	
	-- Truncate staging tables
	TRUNCATE TABLE stage_sales_order;
	TRUNCATE TABLE stage_sales_order_line_item;

		-- stage_sales_order
	INSERT INTO stage_sales_order
		SELECT
			SalesOrderID,
			SalesOrderNumber,
			SalesOrderDate,
			SalesPersonID, 
			SalesRegionID
		FROM [7.0.1.15].[FinanceDB].[dbo].[SalesOrder]
		WHERE SalesOrderDate >= @start_date;

	-- stage_sales_order_line_item
	INSERT INTO stage_sales_order_line_item
		SELECT
			SalesOrderLineItemID,
			SalesOrderID,
			SalesOrderLineNumber,
			PromotionID,
			ProductID, 
			UnitsSold, 
			SalePrice
		FROM [7.0.1.15].[FinanceDB].[dbo].[SalesOrderLineItem] soli
		WHERE soli.SalesOrderID IN (SELECT SalesOrderID FROM [FinanceDW].[dbo].[stage_sales_order]);
		-- Inner join? Would probably be faster

END;
GO
-- ETL SProcs for extracting data from csv files
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_extract_csv_dimensions' and [type] = 'P')
	DROP PROCEDURE etl_extract_csv_dimensions;
GO
CREATE PROCEDURE etl_extract_csv_dimensions 
AS
BEGIN
	-- Populate Date Dimension from precalculated data stored in csv
	BULK INSERT [FinanceDW].[dbo].[DimDate]
		FROM 'DimDate_Lookup.csv'
		WITH (FIELDTERMINATOR=',', ROWTERMINATOR='\n', FIRSTROW=2);

END;
GO

-- ETL SProcs for extracting data from db and populate lookup tables dimensions:
-- DimCountry, DimSegment, DimProduct

IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_extract_dblookup_dimensions' and [type] = 'P')
	DROP PROCEDURE etl_extract_dblookup_dimensions;
GO
CREATE PROCEDURE etl_extract_dblookup_dimensions
AS
BEGIN
	-- Extract to Country Dimension
	INSERT INTO [FinanceDW].[dbo].[DimCountry]
		SELECT
			CountryID, CountryName
		FROM [7.0.1.15].[FinanceDB].[dbo].[Country];

	-- Extract to Segment Dimension
	INSERT INTO [FinanceDW].[dbo].[DimSegment]
		SELECT
			SegmentID, SegmentName
		FROM [7.0.1.15].[FinanceDB].[dbo].[Segment];

	-- Extract to Product Dimension
	INSERT INTO [FinanceDW].[dbo].[DimProduct]
		SELECT
			ProductID, ProductName
		FROM [7.0.1.15].[FinanceDB].[dbo].[Product];
END;
GO

/*----------------------------------------
 * Stored Procedures for Unstaging tables
 *
 * Notes: I think there is a more efficient way of doing the UpSert but UPDATE and INSERT will suffice for now.
*/----------------------------------------

-- Unstaging stage_sales_person for DimSalesPerson
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_unstage_sales_person' and [type] = 'P')
	DROP PROCEDURE etl_unstage_sales_person;
GO
CREATE PROCEDURE etl_unstage_sales_person
AS
BEGIN
	--UpSert Sales Person Data to update any changes from DimSalesPerson and insert new sales person data
	UPDATE [FinanceDW].[dbo].[DimSalesPerson]
	SET
		FirstName = stage.FirstName,
		LastName = stage.LastName,
		Gender = stage.Gender,
		HireDate = stage.Hiredate,
		DayOfBirth = stage.DayOfBirth,
		DaysOfLeave = stage.DaysOfLeave,
		DaysOfSickLeave = stage.DaysOfSickLeave
	FROM [FinanceDW].[dbo].[stage_sales_person] stage
		INNER JOIN [FinanceDW].[dbo].[DimSalesPerson] dw ON dw.SalesPersonID = stage.SalesPersonID;

	INSERT INTO [FinanceDW].[dbo].[DimSalesPerson]
		SELECT
			stage.SalesPersonID,
			stage.FirstName,
			stage.LastName,
			stage.Gender,
			stage.HireDate,
			stage.DayOfBirth,
			stage.DaysOfLeave,
			stage.DaysOfSickLeave
		FROM [FinanceDW].[dbo].[stage_sales_person] stage
			LEFT JOIN [FinanceDW].[dbo].[DimSalesPerson] dw ON dw.SalesPersonID = stage.SalesPersonID
		WHERE dw.SalesPersonID IS NULL;

END;
GO

-- Unstaging stage_promotion for DimPromotion
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_unstage_promotion' and [type] = 'P')
	DROP PROCEDURE etl_unstage_promotion;
GO
CREATE PROCEDURE etl_unstage_promotion
AS
BEGIN
	--UpSert promotion data to update any changes from DimPromotion and insert new promotion facts
	UPDATE [FinanceDW].[dbo].[DimPromotion]
	SET
		ProductID = stage.ProductID,
		PromotionYear = stage.PromotionYear,
		Discount = stage.Discount
	FROM [FinanceDW].[dbo].[stage_promotion] stage
		INNER JOIN [FinanceDW].[dbo].[DimPromotion] dw ON dw.PromotionID = stage.PromotionID;

	INSERT INTO [FinanceDW].[dbo].[DimPromotion]
		SELECT
			stage.PromotionID,
			stage.ProductID,
			stage.PromotionYear,
			stage.Discount
		FROM [FinanceDW].[dbo].[stage_promotion] stage			
			LEFT JOIN [FinanceDW].[dbo].[DimPromotion] dw ON dw.PromotionID = stage.PromotionID
		WHERE dw.PromotionID IS NULL;
END;
GO

/*--------------------------------
 * Stored Procedure ETL for FACTS
*/--------------------------------

-- Unstaging stage_region and stage_sales_region for FactSalesRegion
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_unstage_sales_region' and [type] = 'P')
	DROP PROCEDURE etl_unstage_sales_region;
GO
CREATE PROCEDURE etl_unstage_sales_region
AS
BEGIN
	--UpSert sales region data to update any changes from FactSalesRegion and insert new added sales region
	UPDATE [FinanceDW].[dbo].[FactSalesRegion]
	SET
		SalesPersonID = stage.SalesPersonID
	FROM [FinanceDW].[dbo].[stage_sales_region] stage
		INNER JOIN [FinanceDW].[dbo].[FactSalesRegion] dw ON dw.SalesRegionID = stage.SalesRegionID;

	INSERT INTO [FinanceDW].[dbo].[FactSalesRegion]
		SELECT
			ssr.SalesRegionID,
			sr.CountryID,
			sr.SegmentID,
			ssr.SalesPersonID
		FROM [FinanceDW].[dbo].[stage_sales_region] ssr
			LEFT JOIN [FinanceDW].[dbo].[stage_region] sr ON sr.RegionID = ssr.RegionID
			LEFT JOIN [FinanceDW].[dbo].[FactSalesRegion] dw ON dw.SalesRegionID = ssr.SalesRegionID
		WHERE dw.SalesRegionID is NULL;
END;
GO

-- Unstaging stage_kpi for FactKPI
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_unstage_kpi' and [type] = 'P')
	DROP PROCEDURE etl_unstage_kpi;
GO
CREATE PROCEDURE etl_unstage_kpi
AS
BEGIN
	--UpSert KPI data to update any changes from FactKPI and insert new KPI facts
	UPDATE [FinanceDW].[dbo].[FactKPI]
	SET
		SalesPersonID = stage.SalesPersonID,
		SalesYear = stage.SalesYear,
		KPI = stage.KPI
	FROM [FinanceDW].[dbo].[stage_kpi] stage
		INNER JOIN [FinanceDW].[dbo].[FactKPI] dw ON dw.KPIID = stage.KPIID;

	INSERT INTO [FinanceDW].[dbo].[FactKPI]
		SELECT
			stage.KPIID,
			stage.SalesPersonID,
			fsregion.CountryID,
			fsregion.SegmentID,
			stage.SalesYear,
			stage.KPI
		FROM [FinanceDW].[dbo].[stage_kpi] stage
			LEFT JOIN [FinanceDW].[dbo].[FactSalesRegion] fsregion ON fsregion.SalesRegionID = stage.SalesRegionID
			LEFT JOIN [FinanceDW].[dbo].[FactKPI] dw ON dw.KPIID = stage.KPIID
		WHERE dw.KPIID IS NULL;
END;
GO

-- Unstaging stage_product_cost for FactProductCost
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_unstage_product_cost' and [type] = 'P')
	DROP PROCEDURE etl_unstage_product_cost;
GO
CREATE PROCEDURE etl_unstage_product_cost
AS
BEGIN
	--UpSert product cost data to update any changes from FactProductCost and insert new product costs data
	UPDATE [FinanceDW].[dbo].[FactProductCost]
	SET
		ManufacturingPrice = stage.ManufacturingPrice,
		RRP = stage.RRP
	FROM [FinanceDW].[dbo].[stage_product_cost] stage
		INNER JOIN [FinanceDW].[dbo].[FactProductCost] dw ON dw.ProductCostID = stage.ProductCostID;

	INSERT INTO [FinanceDW].[dbo].[FactProductCost]
		SELECT
			stage.ProductCostID,
			stage.CountryID,
			stage.ProductID,
			stage.ManufacturingPrice,
			stage.RRP
		FROM [FinanceDW].[dbo].[stage_product_cost] stage
			LEFT JOIN [FinanceDW].[dbo].[FactProductCost] dw ON dw.ProductCostID = stage.ProductCostID
		WHERE dw.ProductCostID IS NULL;
END;
GO

-- Unstaging stage_sales and stage_sales_order_line_item for FactSales
IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_unstage_sales' and [type] = 'P')
	DROP PROCEDURE etl_unstage_sales;
GO
CREATE PROCEDURE etl_unstage_sales
AS
BEGIN
	--UpSert sales data to update any changes from FactSales and insert new sales facts
	UPDATE [FinanceDW].[dbo].[FactSales]
	SET
		DateOrderID = CAST(CONVERT(VARCHAR(8), sso.SalesOrderDate, 112) AS INT),
		SalesOrderDate = sso.SalesOrderDate,
		SalesPersonID = sso.SalesPersonID,
		ProductID = ssoli.ProductID,
		ProductCostID = fpc.ProductCostID,
		PromotionID = ssoli.PromotionID,
		SalesOrderLineNumber = ssoli.SalesOrderLineNumber,
		UnitsSold = ssoli.UnitsSold,
		SalePrice = ssoli.SalePrice,
		Profit = ssoli.SalePrice - (ssoli.UnitsSold*fpc.ManufacturingPrice)
	FROM [FinanceDW].[dbo].[stage_sales_order_line_item] ssoli
		INNER JOIN [FinanceDW].[dbo].[FactSales] dw ON dw.SalesOrderLineItemID = ssoli.SalesOrderLineItemID
		LEFT JOIN [FinanceDW].[dbo].[stage_sales_order] sso ON sso.SalesOrderID = ssoli.SalesOrderID
		LEFT JOIN [FinanceDW].[dbo].[FactSalesRegion] fsr ON fsr.SalesRegionID = sso.SalesRegionID
		LEFT JOIN [FinanceDW].[dbo].[FactProductCost] fpc ON fpc.ProductID = ssoli.ProductID
			AND fpc.CountryID = fsr.CountryID;

	INSERT INTO [FinanceDW].[dbo].[FactSales]
		SELECT
		  ssoli.SalesOrderLineItemID,
		  CAST(CONVERT(VARCHAR(8), sso.SalesOrderDate, 112) AS INT) AS DateOrderID,
		  sso.SalesOrderDate,
		  fsr.CountryID, 
		  fsr.SegmentID, 
		  sso.SalesPersonID, 
		  ssoli.ProductID, 
		  fpc.ProductCostID, 
		  ssoli.PromotionID, 
		  sso.SalesOrderID, 
		  ssoli.SalesOrderLineNumber, 
		  ssoli.UnitsSold, 
		  ssoli.SalePrice, 
		  Profit = ssoli.SalePrice - (ssoli.UnitsSold*fpc.ManufacturingPrice)
		FROM [FinanceDW].[dbo].[stage_sales_order_line_item] ssoli
			LEFT JOIN [FinanceDW].[dbo].[stage_sales_order] sso ON sso.SalesOrderID = ssoli.SalesOrderID
			LEFT JOIN [FinanceDW].[dbo].[FactSalesRegion] fsr ON fsr.SalesRegionID = sso.SalesRegionID
			LEFT JOIN [FinanceDW].[dbo].[FactProductCost] fpc ON fpc.ProductID = ssoli.ProductID
				AND fpc.CountryID = fsr.CountryID
			LEFT JOIN [FinanceDW].[dbo].[FactSales] dw ON dw.SalesOrderLineItemID = ssoli.SalesOrderLineItemID
		WHERE dw.SalesOrderLineItemID IS NULL;
END;
GO

/*---------------------
 * SProcs for ETL Pipeline
 *
 * parameters:
 *		@method: 'initialise', 'rebuild' or 'incremental'
 *			If initialise, 	this process MUST be run during the initial stage of FinanceDW it calls out all stored procedure for populating 
 *				stage tables, dimensions and facts defined by the starting date.
 *			If rebuild, this process runs those dimensions and facts that are defined by date or year, dimension like dimdate and lookup
 *				were not included in this method.
 *			If incremental, this process will only run the staging and unstaging of sales to FactSales table.
 *				This method will also be used by the Server Agent that I scheduled to run weekly.
 *				Important Note: Once sales data reaches to a New Year 'rebuild' method must be run to provide updated KPI and Promotion
 *
 *		@from_date: starting date will be supplied if @method is rebuild, intialise will use the default value '2001-01-01'
 *					while incremental will use the latest date stored in FactSales
 *
*/---------------------

IF EXISTS (SELECT 1 FROM sys.objects WHERE [name] = 'etl_pipeline' and [type] = 'P')
	DROP PROCEDURE etl_pipeline;
GO
CREATE PROCEDURE etl_pipeline @method NVARCHAR(16) = N'incremental', @from_date DATE = '2001-01-01'
AS
BEGIN

	DECLARE @local_start_date DATE;
	SET @local_start_date = CASE 
		WHEN @method = N'incremental' THEN (SELECT max(SalesOrderDate) FROM [FinanceDW].[dbo].[FactSales])
		ELSE @from_date
	END;

	IF @method = N'initialise'
	BEGIN
		EXEC etl_extract_stage_tables;
		EXEC etl_extract_csv_dimensions;
		EXEC etl_extract_dblookup_dimensions;
		EXEC etl_unstage_sales_person;
		EXEC etl_unstage_sales_region;
		EXEC etl_unstage_product_cost;
		EXEC etl_pipeline @method = N'rebuild', @from_date = @from_date;
	END;

	IF @method = N'rebuild'
	BEGIN
		DECLARE @local_start_year INT;
		SET @local_start_year = (SELECT YEAR(@from_date));
		EXEC etl_extract_stage_promotion @start_year = @local_start_year;
		EXEC etl_extract_stage_kpi @start_year = @local_start_year;
		EXEC etl_unstage_promotion;
		EXEC etl_unstage_kpi;
		EXEC etl_pipeline @method = N'incremental', @from_date = @from_date;
	END;

	IF @method = N'incremental'
	BEGIN
		IF (@local_start_date IS NULL) SET @local_start_date = '2001-01-01';
		EXEC etl_extract_stage_sales @start_date = @local_start_date;
		EXEC etl_unstage_sales;
	END;

END;
GO

/*-----------------------------------------------------------------
 * CONTROL OPTIONS
 *
 * This area handles all the execution of the stored procedure.
 * I put everything in comment so it is much easier to hit and execute the whole ETL first
 * without worrying on executing this area
-------------------------------------------------------------------
-------------------------------------------------------------------

-- Run this line to if you just created FinanceDW and wanted to extract the data from FinanceDB
EXEC etl_pipeline @method = N'initialise';

-- Run this line if you wanted to update Promotion, KPI and Sales to the specified year
EXEC etl_pipeline @method = N'rebuild', @from_date  = '2014-01-01'

-- This line will be used by the SQL Server Agent to run its weekly extraction of new or updated data from Sales in the Finance DB
-- I created the job in SQL Server Agent with attached schedule: RUN_ETL_Weekly
EXEC etl_pipeline @method = N'incremental';

-- Currently, I can't think of an efficient way of creating a procedure that would handle specific updates of Dimensions.
-- So running each stored procedures is the only option for now....
EXEC etl_extract_csv_dimensions;			--> DimDate need to be repopulated in R once the latest year in Sales exceeded from the generated one
EXEC etl_extract_dblookup_dimensions;		--> Country, Segment and Product can be updated here

-- For DimPromotion							--> We can use the rebuild method
-- For Sales Person
EXEC etl_extract_stage_tables;				--> This is not the most effecient way of updating sales person dimension
EXEC etl_unstage_sales_person;
*/-----------------------------------------------------------------