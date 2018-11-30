/* 
 * Title: FinanceDW Views and Indexes
 * Assignment 2
 * ---------------------
 *
 *
 * Lionell Carlo Paquit
 * 
 * Notes:
 * Data Analyst: Sheldon Mazzola
 * Requested two views
 * 1. Views for total yearly sales by Country / Segment
 * 2. Views for total yearly kpi by Country / Segment
 * 3. Create Index for faster execution of the views
 *
 * 
*/

USE FinanceDW;
GO
-- Create view for total yearly sales by country/segment
-- DROP VIEW IF EXISTS vw_Total_Yearly_Sales;
-- DROP VIEW IF EXISTS vw_Total_Yearly_KPI

-- vw_Totaly_Yearly_Sales shows yearly sales by each sales region
CREATE VIEW vw_Total_Yearly_Sales AS (
SELECT
	YEAR(sales.SalesOrderDate) AS CalendarYear,
	country.CountryName,
	segment.SegmentName,
	SUM(sales.SalePrice) AS TotalYearlySales
FROM [FinanceDW].[dbo].[FactSales] sales
	LEFT JOIN [FinanceDW].[dbo].[DimCountry] country ON country.CountryID = sales.CountryID
	LEFT JOIN [FinanceDW].[dbo].[DimSegment] segment ON segment.SegmentID = sales.SegmentID
GROUP BY
	country.CountryName,
	segment.SegmentName,
	YEAR(sales.SalesOrderDate)
);

-- vw_Total_Yearly_KPI shows total kpi of each sales region yearly
CREATE VIEW vw_Total_Yearly_KPI AS (
SELECT
	kpi.SalesYear,
	country.CountryName,
	segment.SegmentName,
	SUM(kpi.KPI) AS TotalYearlyKPI
FROM [FinanceDW].[dbo].[FactKPI] kpi
	LEFT JOIN [FinanceDW].[dbo].[DimCountry] country ON country.CountryID = kpi.CountryID
	LEFT JOIN [FinanceDW].[dbo].[DimSegment] segment ON segment.SegmentID = kpi.SegmentID
GROUP BY
	country.CountryName,
	segment.SegmentName,
	kpi.SalesYear 
);

/*
 * This section is where indices created for faster execution of the views
 * 
 * 2 Facts tables were used in the views. And in order to make the execution faster I created indices on both
 * At the join tables primary keys CountryID and SegmentID were used, it's apt to create index for this fk
 * in the FactSales and in Fact KPI.
 * 
 * Uncomment the drop statement in order to drop the index
*/
-- DROP INDEX idx_FactSales ON FactSales;	--> Uncomment to drop index
CREATE INDEX idx_FactSales ON FactSales (CountryID, SegmentID);
-- DROP INDEX idx_FactKPI ON FactKPI		--> Uncomment to drop index
CREATE INDEX idx_FactKPI ON FactKPI (CountryID, SegmentID);
