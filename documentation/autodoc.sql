/***********************************************************************
1. Paste this code into SSMS
2. Use the hotkey CTRL + SHIFT + M
3. Modify the variable names in the 3rd Column
4. Run your query for SQL Server Generated Markdown Documentation
************************************************************************/
 
USE <Database, sysname, Database_Name>
GO
 
SELECT
         '|' AS '|'
       , '-' AS 'TABLE_CATALOG'
       , '|' AS '|'
       , '-' AS 'TABLE_SCHEMA'
       , '|' AS '|'
       , '-' AS 'TABLE_NAME'
       , '|' AS '|'
       , '-' AS 'COLUMN_NAME'
       , '|' AS '|'
       , '-' AS 'ORDINAL_POSITION'
       , '|' AS '|'
       , '-' AS 'IS_NULLABLE'
       , '|' AS '|'
       , '-' AS 'DATA_TYPE'
       , '|' AS '|'
       , '-' AS 'CREATED_DATE'
       , '|' AS '|'
       , '-' AS 'EDITED_DATE'
       , '|' AS '|'
       , '-' AS 'COMMENT'
       , '|' AS '|'
 
UNION
 
SELECT
         '|' AS '|'
       , UPPER(TABLE_CATALOG)
       , '|' AS '|'
       , UPPER(TABLE_SCHEMA)
       , '|' AS '|'
       , TABLE_NAME
       , '|' AS '|'
       , COLUMN_NAME
       , '|' AS '|'
       , CAST(ORDINAL_POSITION AS NVARCHAR)
       , '|' AS '|'
       , IS_NULLABLE
       , '|' AS '|'
       , UPPER(DATA_TYPE)
       , '|' AS '|'
       , CAST(FORMAT(GETDATE(), 'yyyy-MM-dd') AS NVARCHAR) AS 'CREATED_DATE'
       , '|' AS '|'
       , NULL AS 'EDITED_DATE'
       , '|' AS '|'
       , NULL AS 'COMMENT'
       , '|' AS '|'
 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = N'<Database, sysname, Database_Name>'
AND TABLE_SCHEMA = N'<Schema_Name, sysname, Schema_Name>'
AND TABLE_NAME = N'<Table_Name, sysname, Table_Name>'
ORDER BY
         TABLE_CATALOG
       , TABLE_SCHEMA
       , TABLE_NAME
       , ORDINAL_POSITION
