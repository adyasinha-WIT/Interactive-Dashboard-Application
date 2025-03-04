/*	
	Date: 27/09/2024
	Course: DS6504
	Assignment: 2
	Purpose: 
		- Import the exported file from APlus+ into SQL Server
		- Create Database DS6504Attendance
		- Create Tables Attendance and ColumnList
		- Add data from the exported file into these two tables
		- Students are to design and create new tables with relationships based on these tables
*/

-- Uncomment if you need to create the database
--use master
--DROP DATABASE IF EXISTS DS6504Attendance2024;

--CREATE DATABASE DS6504Attendance2024;
--GO

USE DS6504Attendance2024;
GO

-- Create Attendance table
DROP TABLE IF EXISTS Attendance;
CREATE TABLE Attendance (	
	Student_Name NVARCHAR(30),
	Student_ID NVARCHAR(10));
GO

-- CREATE table to store columns' names
DROP TABLE IF EXISTS ColumnList;
CREATE TABLE ColumnList (
	colNameID INT IDENTITY(1,1),
	columnName NVARCHAR(20)); 

-- Configuration parameter: number of columns: 19
DECLARE @ncolumn INT = 20;
-- Configuration parameter: file path
DECLARE @filePath NVARCHAR(MAX) = 'C:\DS6504_Assignment2_Adya\Attendance-AB.csv' -- To change to your file Path
DECLARE @tableName NVARCHAR(MAX) = 'Attendance'
DECLARE @sql NVARCHAR(MAX)
DECLARE @rawstr NVARCHAR(MAX);
DECLARE @i INT = 0;
DECLARE @str NVARCHAR(30);
DECLARE @strn NVARCHAR(30);

-- Read the csv file as a single row and store in @rawstr
SET @sql = 'SET @outstr = (SELECT * FROM  OPENROWSET(BULK N''' + @filePath + ''', SINGLE_CLOB) AS x)';
EXEC sp_executesql @sql, N'@outstr NVARCHAR(MAX) output', @rawstr output;

-- Automatically read columns' names from @rawstr and add data into ColumnTable
-- Add columns into the Attendance table
WHILE @i < @ncolumn
BEGIN
	SET @str = LEFT(@rawstr, CHARINDEX(CHAR(44), @rawstr));
	SET @strn = LEFT(@rawstr, CHARINDEX(CHAR(13), @rawstr));
	IF LEN(@str) > LEN(@strn)
		SET @str = @strn;
	SET @rawstr = SUBSTRING(@rawstr, LEN(@str) + 1, LEN(@rawstr));
	-- Remove comma or \n at the end of the string
	SET @str = LEFT(@str, LEN(@str) - 1);
	INSERT INTO ColumnList (columnName) VALUES (@str);

	-- Add column into Attendance table
	IF (@str <> 'Last Name') AND (@str <> 'Student ID')
	BEGIN
		SET @sql = 'ALTER TABLE ' + @tableName + ' ADD [' + @str + '] NVARCHAR(10)'; -- you may change @str to STR(@i-1)
		SELECT @sql;
		EXEC sp_executesql @sql;
	END

	SET @i = @i + 1;
END
GO

SELECT * FROM Attendance;
GO

SELECT * FROM ColumnList;
GO

-- Insert data into Attendance table
BULK INSERT Attendance
FROM 'C:\DS6504_Assignment2_Adya\Attendance-AB.csv' -- To change to your file Path
WITH
(
    FIRSTROW = 2, -- as 1st one is header
    FIELDTERMINATOR = ',',  --CSV field delimiter
    ROWTERMINATOR = '\n',   --Use to shift the control to next row
    TABLOCK
)

SELECT * FROM Attendance;
GO

-- Create table Student
GO
DROP TABLE IF EXISTS Student;
CREATE TABLE Student (
	Student_ID NVARCHAR(10) PRIMARY KEY, 
	Student_Name NVARCHAR(30));
GO

/* 
	Create table ClassSession with 2 main columns S_ID (session ID) and S_Name (session name)
	and 4 computed columns 
		S_Date, 
		S_Time, 
		S_DayOfWeek and 
		S_Type (0 is Lecture, 1 is Lab)
*/

DROP TABLE IF EXISTS ClassSession;
CREATE TABLE ClassSession (
	S_ID INT IDENTITY(1, 1) PRIMARY KEY, 
	S_Name NVARCHAR(20),
	S_Date AS CONVERT(DATE, '2023 ' + S_Name), 
	S_Time AS CONVERT(TIME, '2023 ' + S_Name),
	S_DayOfWeek AS DATENAME(WEEKDAY, CONVERT(DATE, '2023 ' + S_Name)),
	S_Type AS 
		CASE 
			WHEN (UPPER(DATENAME(WEEKDAY, CONVERT(DATE, '2023 ' + S_Name))) = 'WEDNESDAY') THEN 1
			ELSE 0
		END)
GO


-- Create table StudentAttendance
DROP TABLE IF EXISTS StudentAttendance;
CREATE TABLE StudentAttendance (
	Student_ID NVARCHAR(10), --REFERENCES Student(Student_ID), 
	S_ID INT, --REFERENCES ClassSession(S_ID),
	SS_Attendance NVARCHAR(10)
	PRIMARY KEY (Student_ID, S_ID));
GO

-- Insert data into table Student
INSERT INTO Student (Student_ID, Student_Name)
	SELECT Student_ID, Student_Name FROM Attendance;
GO

-- Insert data into table ClassSession
INSERT INTO ClassSession (S_Name)
	SELECT	columnName	FROM ColumnList
	WHERE colNameID > 2; -- first 2 rows are not interested

--SELECT Student_ID, 1, [11 Jul 10am] FROM Attendance;

-- Insert data into StudentAttendance table
DECLARE @S_Number INT = (SELECT COUNT(*) FROM ClassSession);
DECLARE @i INT = 1;
DECLARE @S_Name NVARCHAR(20);
DECLARE @sql NVARCHAR(MAX);

-- browse through every session
WHILE @i <= @S_Number
BEGIN
	SET @S_Name = (SELECT S_Name FROM ClassSession WHERE S_ID = @i);
	PRINT @S_Name;
	SET @sql = 'INSERT INTO StudentAttendance (Student_ID, S_ID, SS_Attendance)
					SELECT Student_ID,' + STR(@i) + ', [' + @S_Name + '] FROM Attendance';
	PRINT 'EXEC sp_executesql ' + @sql;
	EXEC sp_executesql @sql;
	SET @i = @i+1;
END;
GO

SELECT * FROM StudentAttendance;
GO
SELECT * FROM Student;
GO
SELECT * FROM ClassSession;
GO
