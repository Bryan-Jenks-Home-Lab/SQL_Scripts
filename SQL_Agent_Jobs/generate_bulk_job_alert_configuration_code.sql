/*
    Source:
    https://www.mssqltips.com/sqlservertip/1091/setting-up-alerts-for-all-sql-server-agent-jobs/
*/

USE msdb
GO

DECLARE @operator varchar(50)
SET @operator = 'SQLalerts'

SELECT 'EXEC msdb.dbo.sp_update_job @job_ID = ''' + convert(varchar(50),job_id) + ''' ,@notify_level_email = 2, @notify_email_operator_name = ''' + @operator + ''''
FROM sysjobs
