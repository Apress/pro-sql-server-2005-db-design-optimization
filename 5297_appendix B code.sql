SET nocount on
go

--====================================================
-- Decimal Data
--====================================================
DECLARE @testvar decimal(3,1)

SELECT @testvar = -10.155555555
SELECT @testvar
GO
SET NUMERIC_ROUNDABORT ON
DECLARE @testvar decimal(3,1)
SELECT @testvar = -10.155555555
GO
SET NUMERIC_ROUNDABORT OFF
go
--====================================================
-- Money Data
--====================================================

create table dbo.testMoney
(
    moneyValue money
)
go

insert into dbo.testMoney
values ($100)
insert into dbo.testMoney
values (100)
insert into dbo.testMoney
values (£100)
go
select * from dbo.testMoney
go


DECLARE @money1 money, @money2 money

SET @money1 = 1.00 
SET @money2 = 800.00 
SELECT cast(@money1/@money2 as money)

DECLARE @decimal1 decimal(19,4), @decimal2 decimal(19,4)
SET @decimal1 = 1.00 
SET @decimal2 = 800.00
SELECT cast(@decimal1/@decimal2 as decimal(19,4))

SELECT @money1/@money2
SELECT @decimal1/@decimal2
GO
--===========================================================================
-- Using User-Defined Data Types to Manipulate Dates and Times
--===========================================================================
USE AdventureWorks
GO

SELECT *
FROM HumanResources.employee
WHERE birthDate = '1966-03-14'
GO

SELECT *
FROM   HumanResources.employee
WHERE  birthDate >= '1966-03-14 0:00:00.000' 
  AND  birthDate < '1966-03-15 0:00:00.000' 
GO

SELECT *
FROM   HumanResources.employee
WHERE birthDate BETWEEN '1967-07-12 0:00:00.00'
AND '1967-07-12 23:59:59.997'
GO

--note, no key on table just for quick demo purposes, 
--please wear all protective gear in designed databases

--in tempdb
USE tempdb
go
CREATE TABLE date
(
       dateValue   datetime,
       year        as (datepart(yy, dateValue)) persisted,
       month       as (datepart(m, dateValue)) persisted
)
go

INSERT INTO date(dateValue)
VALUES ('2005-04-12')
SELECT * FROM date
go

CREATE FUNCTION intDateType$convertToDatetime
(
   @dateTime   int
) 
RETURNS datetime
AS
BEGIN
   RETURN ( dateadd(second,@datetime,'1990-01-01'))
END
GO

SELECT dbo.intDateType$convertToDatetime(485531247) as convertedValue

--========================================================
-- char(length)
--========================================================
use tempdb
drop table sequence
go
create table sequence
(
	number	int
)	
go

declare @digits table (i int)
insert into @digits values (1)
insert into @digits values (2)
insert into @digits values (3)
insert into @digits values (4)
insert into @digits values (5)
insert into @digits values (6)
insert into @digits values (7)
insert into @digits values (8)
insert into @digits values (9)
insert into @digits values (0)


insert into sequence(number)
                                                --uncomment to increase max value to
		                               --more than 999
SELECT distinct D1.i + (10*D2.i)+ (100*D3.i) --+ (1000*D4.i)+ (10000*D5.i) --+ (100000*D6.i) 
FROM @Digits AS D1 
        CROSS JOIN @Digits AS D2
        CROSS JOIN @Digits AS D3
--      CROSS JOIN @Digits AS D4
--      CROSS JOIN @Digits as D5
--      CROSS JOIN @Digits As D6 
go

select number, char(number)
from dbo.sequence
where number >=0 and number <= 255

--========================================================
-- Varchar(max)
--========================================================

DECLARE @value varchar(max)
SET @value = replicate('X',8000) + replicate('X',8000)
SELECT len(@value)
go

DECLARE @value varchar(max)
SET @value = replicate(cast('X' as varchar(max)),16000) 
SELECT len(@value)
go

--========================================================
-- Binary(length)
--========================================================

declare @value binary(10)
set @value = cast('helloworld' as binary(10))
select @value
go

select cast(0x68656C6C6F776F726C64 as varchar(10))
go

declare @value binary(10)
set @value = cast('HELLOWORLD' as binary(10))
select @value
go


--========================================================
-- Binary(length)
--========================================================
CREATE TABLE testRowversion
(
   value   varchar(20) NOT NULL,
   auto_rv   rowversion NOT NULL
)
go
INSERT INTO testRowversion (value) values ('Insert')

SELECT value, auto_rv FROM testRowversion
UPDATE testRowversion
SET value = 'First Update'

SELECT value, auto_rv from testRowversion
UPDATE testRowversion
SET value = 'Last Update'

SELECT value, auto_rv FROM testRowversion
go

--========================================================
-- Uniqueidentifier
--========================================================

DECLARE @guidVar uniqueidentifier
SET @guidVar = newid()

SELECT @guidVar as guidVar
go

CREATE TABLE guidPrimaryKey
(
   guidPrimaryKeyId uniqueidentifier NOT NULL 
   rowguidcol DEFAULT newId(),
   value varchar(10)
)
GO
INSERT INTO guidPrimaryKey(value)
VALUES ('Test')
GO
SELECT *
FROM guidPrimaryKey
GO
drop TABLE guidPrimaryKey
go
CREATE TABLE guidPrimaryKey
(
   guidPrimaryKeyId uniqueidentifier NOT NULL rowguidcol DEFAULT newSequentialId(),
   value varchar(10)
)
GO
INSERT INTO guidPrimaryKey(value)
SELECT 'Test'
UNION ALL
SELECT 'Test1'
UNION ALL
SELECT 'Test2'

GO
SELECT *
FROM guidPrimaryKey
GO

--========================================================
-- Table 
--========================================================

DECLARE @tableVar TABLE
( 
   id int IDENTITY, 
   value varchar(100)
)
INSERT INTO @tableVar (value) 
VALUES ('This is a cool test')

SELECT id, value
FROM @tableVar

--====================================================
-- SQL Variant
--====================================================


CREATE TABLE vehicle
(
    vehicleId   int constraint PKvehicle Primary Key,
    name        varchar(60) constraint AKvehicle UNIQUE
)
go
INSERT INTO vehicle
SELECT 1, 'Main Car'
UNION ALL
SELECT 2, 'Backup Truck'


CREATE TABLE vehicleProperty 
( 
 vehicleId int, 
 propertyName varchar(30), 
 propertyValue sql_variant, 
 constraint PKproperty primary key (vehicleId, propertyName),
 constraint property$suppliespropertyvaluesfor$vehicle foreign key (vehicleId) references vehicle (vehicleId)
) 

INSERT INTO vehicleProperty 
SELECT 1,'main driver','Joe'
UNION ALL
SELECT 1, 'interior color','beige'
UNION ALL
SELECT 2,'trailer hitch style','small'
UNION ALL
SELECT 2,'interior color','tan'

INSERT INTO vehicleProperty 
SELECT 2,'tow capacity (lbs)',2000

SELECT * from vehicleProperty


SELECT  vehicleName, vehicleId, [main driver], [interior color], 
        [trailer hitch style], [tow capacity (lbs)]
FROM 
(SELECT vehicle.name as vehicleName, vehicleProperty.vehicleId, 
        vehicleProperty.propertyName, vehicleProperty.propertyValue
 FROM vehicle
       join vehicleProperty
            on vehicle.vehicleId = vehicleProperty.vehicleId) as properties
PIVOT
(
max (propertyValue)
FOR PropertyName IN
( [main driver], [interior color], [trailer hitch style], [tow capacity (lbs)])
) AS pvt
ORDER BY VehicleName;

go

DECLARE @varcharVariant sql_variant
SET @varcharVariant = '1234567890'
SELECT @varcharVariant AS varcharVariant, 
   SQL_VARIANT_PROPERTY(@varcharVariant,'BaseType') as baseType,
   SQL_VARIANT_PROPERTY(@varcharVariant,'MaxLength') as maxLength,
   SQL_VARIANT_PROPERTY(@varcharVariant,'Collation') as collation
