/**************************************************************************************************************************\
|===========================================================================================================================|
|                                                                                                                           |
|                                                                                                                           |
| Reference Article: https://www.mssqltips.com/sqlservertip/4054/creating-a-date-dimension-or-calendar-table-in-sql-server/ |
|                                                                                                                           |
|                                                                                                                           |
|===========================================================================================================================|
***************************************************************************************************************************/

-- FIXME Change all instances of `Ticketer` to the database chosen to house these DBO's
USE <++>

IF OBJECT_ID('dbo.Holiday_Dimension') IS NOT NULL DROP TABLE dbo.Holiday_Dimension
IF OBJECT_ID('dbo.Date_Dimension') IS NOT NULL DROP TABLE dbo.Date_Dimension
IF OBJECT_ID('dbo.The_Calendar') IS NOT NULL DROP VIEW dbo.VW_The_Calendar

-- prevent set or regional settings from interfering with
-- interpretation of dates / literals
SET DATEFIRST  7 -- 1 = Monday, 7 = Sunday
    , DATEFORMAT mdy
    , LANGUAGE   US_ENGLISH;

-- Start and End points
DECLARE @Start_Date  DATE = '20100101';
DECLARE @Cut_off_Date DATE = DATEADD(DAY, -1, DATEADD(YEAR, 30, @Start_Date));

-- First CTE generating the list of numbers from the Start and End points
;WITH seq(n) AS
(
	SELECT 0 UNION ALL SELECT n + 1 FROM seq
	WHERE n < DATEDIFF(DAY, @Start_Date, @Cut_off_Date)
),
d(d) AS
( -- Second CTE generating an ISO 8601 Date from the numbers
	SELECT DATEADD(DAY, n, @Start_Date) FROM seq
),
src AS
( -- Third CTE taking the generated dates and parsing them into the pertinent information
	SELECT
		  The_Date           = CONVERT(DATE,	   d)
		, The_Day            = DATEPART(DAY,       d)
		, The_Day_Name       = DATENAME(WEEKDAY,   d)
		, The_Week           = DATEPART(WEEK,      d)
		, The_ISO_Week       = DATEPART(ISO_WEEK,  d)
		, The_Day_Of_Week    = DATEPART(WEEKDAY,   d)
		, The_Month          = DATEPART(MONTH,     d)
		, The_Month_Name     = DATENAME(MONTH,     d)
		, The_Quarter        = DATEPART(Quarter,   d)
		, The_Year           = DATEPART(YEAR,      d)
		, The_First_Of_Month = DATEFROMPARTS(YEAR(d), MONTH(d), 1)
		, The_Last_Of_Year   = DATEFROMPARTS(YEAR(d), 12, 31)
		, The_Day_Of_Year    = DATEPART(DAYOFYEAR, d)
	FROM d
),
dim AS
( -- Fourth CTE adding additional information of value
	SELECT
		  The_Date
		, The_Day
		, The_Day_Suffix           = CONVERT(CHAR(2), CASE
												WHEN The_Day / 10 = 1 THEN 'th'
												ELSE 
													CASE RIGHT(The_Day, 1)
														WHEN '1' THEN 'st'
														WHEN '2' THEN 'nd'
														WHEN '3' THEN 'rd'
														ELSE 'th' END
												END)
		, The_Day_Name
		, The_Day_Of_Week
		, The_Day_Of_Week_In_Month = CONVERT(TINYINT, ROW_NUMBER() OVER (PARTITION BY The_First_Of_Month, The_Day_Of_Week ORDER BY The_Date))
		, The_Day_Of_Year
		, Is_Weekend               = CASE WHEN The_Day_Of_Week IN (
									    CASE @@DATEFIRST
                                        WHEN 1 THEN 6
                                        WHEN 7 THEN 1
                                        END, 7
								   ) 
								     THEN 1 ELSE 0 END
		, The_Week
		, The_ISO_week
		, The_First_Of_Week        = DATEADD(DAY, 1 - The_Day_Of_Week, The_Date)
		, The_Last_Of_Week         = DATEADD(DAY, 6, DATEADD(DAY, 1 - The_Day_Of_Week, The_Date))
		, The_Week_Of_Month        = CONVERT(TINYINT, DENSE_RANK() OVER (PARTITION BY The_Year, The_Month ORDER BY The_Week))
		, The_Month
		, The_Month_Name
		, The_First_Of_Month
		, The_Last_Of_Month        = MAX(The_Date) OVER (PARTITION BY The_Year, The_Month)
		, The_First_Of_Next_Month  = DATEADD(MONTH, 1, The_First_Of_Month)
		, The_Last_Of_Next_Month   = DATEADD(DAY, -1, DATEADD(MONTH, 2, The_First_Of_Month))
		, The_Quarter
		, The_First_Of_Quarter     = MIN(The_Date) OVER (PARTITION BY The_Year, The_Quarter)
		, The_Last_Of_Quarter      = MAX(The_Date) OVER (PARTITION BY The_Year, The_Quarter)
		, The_Year
		, The_ISO_Year             = The_Year - CASE WHEN The_Month = 1 AND The_ISO_Week > 51 THEN 1
											    WHEN The_Month = 12 AND The_ISO_Week = 1 THEN -1
											    ELSE 0 END
		, The_First_Of_Year        = DATEFROMPARTS(The_Year, 1,  1)
		, The_Last_Of_Year
		, Is_Leap_Year             = CONVERT(BIT, CASE WHEN The_Year % 400 = 0 OR (The_Year % 4 = 0 AND The_Year % 100 <> 0) THEN 1 ELSE 0 END)
		, Has_53_Weeks             = CASE WHEN DATEPART(WEEK, The_Last_Of_Year) = 53 THEN 1 ELSE 0 END
		, Has_53_ISO_Weeks         = CASE WHEN DATEPART(ISO_WEEK, The_Last_Of_Year) = 53 THEN 1 ELSE 0 END
		, YYYYMM			       = CONCAT(The_Year, CASE WHEN LEN(The_Month) = 1 THEN CONCAT('0', The_Month) ELSE The_Month END) 
		, MMYYYY                   = CONVERT(CHAR(2), CONVERT(CHAR(8), The_Date, 101)) + CONVERT(CHAR(4), The_Year)
		, Style_101                = CONVERT(CHAR(10), The_Date, 101)
		, Style_103                = CONVERT(CHAR(10), The_Date, 103)
		, Style_112                = CONVERT(CHAR(8),  The_Date, 112)
		, Style_120                = CONVERT(CHAR(10), The_Date, 120)
	FROM src
)
-- CREATE THE DATE DIMENSION TABLE
SELECT *
INTO dbo.Date_Dimension
FROM dim
ORDER BY The_Date
OPTION (MAXRECURSION 0);

CREATE UNIQUE CLUSTERED INDEX CIX_Date_Dimension ON dbo.Date_Dimension(The_Date);

-- CREATE THE HOLIDAY DIMENSION TABLE
CREATE TABLE dbo.Holiday_Dimension
(
	The_Date DATE NOT NULL,
	Holiday_Text NVARCHAR(255) NOT NULL,
	CONSTRAINT FK_Date_Dimension FOREIGN KEY(The_Date) REFERENCES dbo.Date_Dimension(The_Date)
);

CREATE CLUSTERED INDEX CIX_Holiday_Dimension ON dbo.Holiday_Dimension(The_Date);

;WITH x AS
(
	SELECT
		  The_Date
		, The_First_Of_Year
		, The_Day_Of_Week_In_Month
		, The_Month
		, The_Day_Name
		, The_Day
		, The_Last_Day_Of_Week_In_Month = ROW_NUMBER() OVER
		  (
			PARTITION BY The_First_Of_Month, The_Day_Of_Week
			ORDER BY The_Date DESC
		  )
	FROM dbo.Date_Dimension
),
s AS
(
	SELECT
		  The_Date
		, Holiday_Text = CASE
		WHEN (The_Date = The_First_Of_Year) THEN 'New Year''s Day'
		WHEN (The_Day_Of_Week_In_Month = 3 AND The_Month = 1 AND The_Day_Name = 'Monday') THEN 'Martin Luther King Day'		-- (3rd Monday in January)
		WHEN (The_Day_Of_Week_In_Month = 3 AND The_Month = 2 AND The_Day_Name = 'Monday') THEN 'President''s Day'		    -- (3rd Monday in February)
		WHEN (The_Month = 3 AND The_Day = 31) THEN 'Cesar Chavez Day'
		WHEN (The_Last_Day_Of_Week_In_Month = 1 AND The_Month = 5 AND The_Day_Name = 'Monday') THEN 'Memorial Day'			-- (last Monday in May)
		WHEN (The_Month = 7 AND The_Day = 4) THEN 'Independence Day'				                                        -- (July 4th)
		WHEN (The_Day_Of_Week_In_Month = 1 AND The_Month = 9 AND The_Day_Name = 'Monday') THEN 'Labour Day'					-- (first Monday in September)
		WHEN (The_Month = 11 AND The_Day = 11) THEN 'Veterans'' Day'				                                        -- (November 11th)
		WHEN (The_Day_Of_Week_In_Month = 4 AND The_Month = 11 AND The_Day_Name = 'Thursday') THEN 'Thanksgiving Day'        -- (Thanksgiving Day ()fourth Thursday in November)
		WHEN (The_Month = 12 AND The_Day = 25) THEN 'Christmas Day'
		END
	FROM x
	WHERE (The_Date = The_First_Of_Year) --------------------------------------------------------- New Years
		OR (The_Day_Of_Week_In_Month = 3      AND The_Month = 1  AND The_Day_Name = 'Monday') ---- MLK Day
		OR (The_Day_Of_Week_In_Month = 3      AND The_Month = 2  AND The_Day_Name = 'Monday') ---- Presidents Day
		OR (The_Month = 3				      AND The_Day = 31)	---------------------------------- Cesar Chavez Day
		OR (The_Last_Day_Of_Week_In_Month = 1 AND The_Month = 5  AND The_Day_Name = 'Monday') ---- Memorial Day
		OR (The_Month = 7				      AND The_Day = 4) ----------------------------------- Independence Day
		OR (The_Day_Of_Week_In_Month = 1      AND The_Month = 9  AND The_Day_Name = 'Monday') ---- Labor Day
		OR (The_Month = 11				      AND The_Day = 11)	---------------------------------- Veterans Day
		OR (The_Day_Of_Week_In_Month = 4      AND The_Month = 11 AND The_Day_Name = 'Thursday')	-- Thanksgiving Day
		OR (The_Month = 12				      AND The_Day = 25)	---------------------------------- Christmas Day
)
INSERT dbo.Holiday_Dimension(The_Date, Holiday_Text)

SELECT The_Date, Holiday_Text FROM s
UNION ALL
SELECT DATEADD(DAY, 1, The_Date), 'Black Friday' -- Special Case
FROM s WHERE Holiday_Text = 'Thanksgiving Day'
ORDER BY The_Date;
GO

CREATE VIEW dbo.VW_The_Calendar
AS
	SELECT
		  d.*
		, Is_Holiday = CASE WHEN h.The_Date IS NOT NULL THEN 1 ELSE 0 END
		, h.Holiday_Text
	FROM dbo.Date_Dimension AS d
		LEFT OUTER JOIN dbo.Holiday_Dimension AS h
			ON d.The_Date = h.The_Date;
