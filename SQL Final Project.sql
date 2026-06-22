CREATE DATABASE IF NOT EXISTS marketing_analytics;
USE marketing_analytics;

-- create tables
CREATE TABLE IF NOT EXISTS CampaignMeta (
    CampaignID VARCHAR(10) PRIMARY KEY,
    Objective VARCHAR(50),
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(12,2),
    CampaignType VARCHAR(30),
    CreativeType VARCHAR(30),
    Manager VARCHAR(50),
    CampaignName VARCHAR(100),
    ConversionGoal VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS ChannelRates (
    ChannelID INT PRIMARY KEY,
    Channel VARCHAR(20),
    AvgCPM DECIMAL(6,2),
    AvgCPC DECIMAL(5,2),
    Remarks VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS CampaignPerformance (
    PerformanceID INT AUTO_INCREMENT PRIMARY KEY,
    Date DATE NOT NULL,
    CampaignID VARCHAR(10),
    ChannelID INT,
    TargetAudience VARCHAR(20),
    Impressions INT,
    Clicks INT,
    Leads INT,
    Applications INT,
    Enrollments INT,
    Cost DECIMAL(12,2),
    Revenue DECIMAL(12,2),
    Region VARCHAR(20)
    );

-- add foregin keys to CampaignPerformance 
ALTER TABLE CampaignPerformance 
ADD CONSTRAINT fk_campaign FOREIGN KEY (CampaignID) REFERENCES CampaignMeta(CampaignID),
ADD CONSTRAINT fk_channel FOREIGN KEY (ChannelID) REFERENCES ChannelRates(ChannelID);

-- update target audience spelling
UPDATE CampaignPerformance 
SET TargetAudience = REPLACE(TargetAudience, 'ä€', '–')
WHERE PerformanceID > 0;

-- target Audience dimension table
CREATE TABLE IF NOT EXISTS TargetAudienceDim (
    AudienceID INT PRIMARY KEY AUTO_INCREMENT,
    AudienceName VARCHAR(30) NOT NULL UNIQUE
);

-- Region dimension table
CREATE TABLE IF NOT EXISTS RegionDim (
    RegionID INT PRIMARY KEY AUTO_INCREMENT,
    RegionName VARCHAR(30) NOT NULL UNIQUE
);

-- Insert distinct TargetAudience values
INSERT INTO TargetAudienceDim (AudienceName)
SELECT DISTINCT TargetAudience
FROM CampaignPerformance
WHERE TargetAudience IS NOT NULL
ORDER BY TargetAudience;

-- Insert distinct Region values
INSERT INTO RegionDim (RegionName)
SELECT DISTINCT Region
FROM CampaignPerformance
WHERE Region IS NOT NULL
ORDER BY Region;

-- add new foreign key columns to CampaignPerformance
ALTER TABLE CampaignPerformance 
ADD COLUMN AudienceID INT,
ADD COLUMN RegionID INT;

-- update the new columns with corresponding IDs
UPDATE CampaignPerformance cp
JOIN TargetAudienceDim ta ON cp.TargetAudience = ta.AudienceName
SET cp.AudienceID = ta.AudienceID;

UPDATE CampaignPerformance cp
JOIN RegionDim r ON cp.Region = r.RegionName
SET cp.RegionID = r.RegionID;

-- put on unsafe mode
SET SQL_SAFE_UPDATES = 0;

-- drop the old columns and add foreign key constraints
ALTER TABLE CampaignPerformance 
DROP COLUMN TargetAudience,
DROP COLUMN Region,
ADD CONSTRAINT fk_audience FOREIGN KEY (AudienceID) REFERENCES TargetAudienceDim(AudienceID),
ADD CONSTRAINT fk_region FOREIGN KEY (RegionID) REFERENCES RegionDim(RegionID);


-- add computed metrics imp for marketing analysis
ALTER TABLE CampaignPerformance
ADD COLUMN CTR DECIMAL(10,4) GENERATED ALWAYS AS (Clicks / NULLIF(Impressions, 0)) STORED,
ADD COLUMN ConversionRate DECIMAL(10,4) GENERATED ALWAYS AS (Enrollments / NULLIF(Clicks, 0)) STORED,
ADD COLUMN ROI DECIMAL(12,2) GENERATED ALWAYS AS ((Revenue - Cost) / NULLIF(Cost, 0)) STORED;

-- view tables
SELECT * FROM CampaignMeta;
SELECT * FROM ChannelRates;
SELECT * FROM CampaignPerformance;
SELECT * FROM TargetAudienceDim;
SELECT * FROM RegionDim;

-- adjust misspelling in target audience
UPDATE TargetAudienceDim 
SET AudienceName = REPLACE(AudienceName, 'â€“', '-')
WHERE AudienceName LIKE '%â€“%';

-- add table dimdate
CREATE TABLE DateDim (
    DateID INT PRIMARY KEY,
    FullDate DATE NOT NULL,
    Year INT,
    Month INT,
    Day INT,
    IsWeekend BOOLEAN
);


-- to create the procedure 
DELIMITER $$

CREATE PROCEDURE FillDateDim(IN start_date DATE, IN end_date DATE)
BEGIN
    DECLARE cur_date DATE DEFAULT start_date;
    
    WHILE cur_date <= end_date DO
        INSERT INTO DateDim (DateID, FullDate, Year, Month, Day, IsWeekend)
        VALUES (
            DATE_FORMAT(cur_date, '%Y%m%d'),
            cur_date,
            YEAR(cur_date),
            MONTH(cur_date),
            DAY(cur_date),
            IF(DAYOFWEEK(cur_date) IN (1,7), TRUE, FALSE)
        );
        SET cur_date = DATE_ADD(cur_date, INTERVAL 1 DAY);
    END WHILE;
END$$

DELIMITER ;

-- call the procedure
CALL FillDateDim('2024-01-01', '2025-12-31');

-- link DateDim to CampaignPerformance
ALTER TABLE CampaignPerformance ADD COLUMN DateID INT;
UPDATE CampaignPerformance cp
JOIN DateDim dd ON cp.Date = dd.FullDate
SET cp.DateID = dd.DateID;
ALTER TABLE CampaignPerformance ADD CONSTRAINT fk_date FOREIGN KEY (DateID) REFERENCES DateDim(DateID);

-- total revenue per campaign
SELECT cm.CampaignName, SUM(cp.Revenue) AS TotalRevenue
FROM CampaignPerformance cp
JOIN CampaignMeta cm ON cp.CampaignID = cm.CampaignID
GROUP BY cm.CampaignName;

-- Total Cost vs Revenue by Campaign (which campaigns are profitable or losing money)
SELECT cm.CampaignName,
       ROUND(SUM(cp.Cost), 2) AS TotalCost,
       ROUND(SUM(cp.Revenue), 2) AS TotalRevenue,
       ROUND(SUM(cp.Revenue) - SUM(cp.Cost), 2) AS Profit
FROM CampaignPerformance cp
JOIN CampaignMeta cm ON cp.CampaignID = cm.CampaignID
GROUP BY cm.CampaignName
ORDER BY Profit DESC;


-- campaigns with ROI > 50%
SELECT cm.CampaignName, ROUND(AVG(cp.ROI), 2) AS AvgROI
FROM CampaignPerformance cp
JOIN CampaignMeta cm ON cp.CampaignID = cm.CampaignID
GROUP BY cm.CampaignName
HAVING AvgROI > 0.5
ORDER BY AvgROI DESC;

-- Campaigns with Above-Average ROI (campaigns that perform better than the average )
SELECT cm.CampaignName,
       ROUND(AVG(cp.ROI), 2) AS AvgROI
FROM CampaignPerformance cp
JOIN CampaignMeta cm ON cp.CampaignID = cm.CampaignID
GROUP BY cm.CampaignName
HAVING AvgROI > (SELECT AVG(ROI) FROM CampaignPerformance)
ORDER BY AvgROI DESC;

 -- best performing audience by enrollments
SELECT ta.AudienceName, SUM(cp.Enrollments) AS TotalEnrollments
FROM CampaignPerformance cp
JOIN TargetAudienceDim ta ON cp.AudienceID = ta.AudienceID
GROUP BY ta.AudienceName
ORDER BY TotalEnrollments DESC;

 -- Find days with unusually high CTR (no row in CampaignPerformance table has a CTR greater than twice the overall average CTR)
SELECT Date, CTR, Revenue
FROM CampaignPerformance
WHERE CTR > (SELECT AVG(CTR) * 2 FROM CampaignPerformance)
ORDER BY CTR DESC;

-- Weekend vs weekday performance 0 → Weekdays (Monday–Friday) 1 → Weekends(Saturday–Sunday)
SELECT dd.IsWeekend, SUM(Revenue) AS TotalRevenue, AVG(ROI) AS AvgROI
FROM CampaignPerformance cp
JOIN DateDim dd ON cp.DateID = dd.DateID
GROUP BY dd.IsWeekend;

-- Top 3 campaigns by total enrollments
SELECT CampaignID, SUM(Enrollments) AS TotalEnrollments
FROM CampaignPerformance
GROUP BY CampaignID
ORDER BY TotalEnrollments DESC
LIMIT 3;

-- Budget vs Actual Spend (Campaigns at Risk of Overspending or to exceed the budget)
SELECT 
    cm.CampaignID, 
    cm.CampaignName, 
    cm.Budget,   -- This is the daily budget
    SUM(cp.Cost) AS TotalSpent,
    ROUND(SUM(cp.Cost) / (cm.Budget * (DATEDIFF(cm.EndDate, cm.StartDate) + 1)) * 100, 2) AS SpendPct,
    cm.EndDate
FROM CampaignPerformance cp
JOIN CampaignMeta cm ON cp.CampaignID = cm.CampaignID
GROUP BY cm.CampaignID, cm.Budget, cm.StartDate, cm.EndDate
HAVING SpendPct > 90
ORDER BY SpendPct DESC;

--  Funnel Efficiency – Which Campaigns Lose Most Between Leads → Enrollments? , marketing fails to convert qualified leads into paying students
SELECT CampaignID,
       SUM(Leads) AS TotalLeads,
       SUM(Enrollments) AS TotalEnrollments,
       ROUND(100 * SUM(Enrollments) / NULLIF(SUM(Leads), 0), 2) AS LeadToEnrollPct
FROM CampaignPerformance
GROUP BY CampaignID
ORDER BY LeadToEnrollPct ASC;

-- Audience ROI by Region – Where to Double Down , which audience–region combinations give the highest return
SELECT ta.AudienceName, rd.RegionName,
       ROUND(SUM(cp.Revenue) / NULLIF(SUM(cp.Cost), 0), 2) AS ROI_Multiple,
       SUM(cp.Enrollments) AS Enrollments,
       SUM(cp.Cost) AS TotalCost
FROM CampaignPerformance cp
JOIN TargetAudienceDim ta ON cp.AudienceID = ta.AudienceID
JOIN RegionDim rd ON cp.RegionID = rd.RegionID
GROUP BY ta.AudienceName, rd.RegionName
HAVING ROI_Multiple > 1.5 AND TotalCost > 10000   -- high ROI with meaningful spend
ORDER BY ROI_Multiple DESC
LIMIT 10;

