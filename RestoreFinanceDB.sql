USE master;
GO

RESTORE filelistonly
FROM DISK = 'C:\DAT701\dbDataDumps\FinanceDB_FinalBackup_Oct2018.bak' ;


RESTORE DATABASE FinanceDB
FROM DISK = 'C:\DAT701\dbDataDumps\FinanceDB_FinalBackup_Oct2018.bak'
WITH RECOVERY,
	MOVE 'FinanceDB' to 'C:\DAT701\dbData\FinanceDB_Data.mdf',
	MOVE 'FinanceDB_log' to 'C:\DAT701\dbLogs\FinanceDB_Log.ldf',
	stats = 10,
	replace;