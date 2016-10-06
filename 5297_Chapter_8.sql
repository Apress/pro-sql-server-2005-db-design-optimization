set nocount on --no pesky messages for me thanks
-----------------------------------------------------------
-- Files and Filegroups
-----------------------------------------------------------

CREATE DATABASE demonstrateFilegroups ON
PRIMARY ( NAME = Primary1, FILENAME = 'c:\demonstrateFilegroups_primary.mdf', 
          SIZE = 10MB),
FILEGROUP SECONDARY
        ( NAME = Secondary1,FILENAME = 'c:\demonstrateFilegroups_secondary1.ndf', 
          SIZE = 10MB),
        ( NAME = Secondary2,FILENAME = 'c:\demonstrateFilegroups_secondary2.ndf', 
          SIZE = 10MB)
LOG ON ( NAME = Log1,FILENAME = 'c:\demonstrateFilegroups_log.ldf', SIZE = 10MB)

GO

USE demonstrateFilegroups
GO
SELECT fg.name as file_group, 
        df.name as file_logical_name,
        df.physical_name as physical_file_name
FROM 	sys.filegroups fg
         join sys.database_files df
            on fg.data_space_id = df.data_space_id
GO

use master
GO
DROP DATABASE demonstrateFileGroups

-----------------------------------------------------------
-- Basics of Index Creation
-----------------------------------------------------------
USE tempdb
GO
CREATE SCHEMA produce 
GO
CREATE TABLE produce.vegetable
(
   --PK constraint defaults to clustered
   vegetableId int CONSTRAINT PKvegetable PRIMARY KEY,
   name varchar(10) 
                   CONSTRAINT AKvegetable_name UNIQUE,
   color varchar(10),
   consistency varchar(10)
)
GO

CREATE INDEX Xvegetable_color ON produce.vegetable(color)
CREATE INDEX Xvegetable_consistency ON produce.vegetable(consistency)
GO

CREATE UNIQUE INDEX Xproduce_vegetable_vegetableId_color 
        ON produce.vegetable(vegetableId, color)	
GO
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (1,'carrot','orange','crunchy')
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (2,'broccoli','green','treelike')
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (3,'mushroom','brown','squishy')
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (4,'pea','green','squishy')
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (5,'asparagus','green','crunchy')
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (6,'sprouts','green','leafy')
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (7,'lettuce','green','leafy')
GO
SELECT  name, type_desc 
FROM    sys.indexes
WHERE   object_id('produce.vegetable') = object_id
GO
DROP INDEX produce.vegetable.Xvegetable_consistency 
GO
-----------------------------------------------------------
-- Basic Index Usage
-----------------------------------------------------------

SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   produce.vegetable
GO
SET SHOWPLAN_TEXT OFF
GO
--Note, I am not including the showplan statements.  Use the graphical plan using Ctrl-L (Estimated)
--Ctrl-M (toggle actual plan display)

SELECT *
FROM   produce.vegetable
GO

SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4
GO

SELECT *
FROM   produce.vegetable
WHERE  vegetableId in (1,4)
GO

-----------------------------------------------------------
-- Determining Index Usefulness
-----------------------------------------------------------
USE AdventureWorks
GO
DBCC SHOW_STATISTICS('humanResources.employee', 'IX_Employee_ManagerID') 
                                                          WITH DENSITY_VECTOR
DBCC SHOW_STATISTICS('humanResources.employee', 'IX_Employee_ManagerID') 
                                                         WITH HISTOGRAM
GO

--managerId can be null, use isnull to deal with this
SELECT 1.0/ count(distinct isnull(managerId,0)), 
                      count(distinct isnull(managerId,0))
FROM   humanResources.employee

SELECT 1.0/ count(*), count(*) --since employeeId, managerId are unique
FROM   humanResources.employee
GO

USE Tempdb
go

CREATE TABLE testIndex  
(
    testIndex int identity(1,1) constraint PKtestIndex primary key,
    bitValue bit,
    filler char(2000) not null default (replicate('A',2000))
)
CREATE INDEX XtestIndex_bitValue on testIndex(bitValue)
go

INSERT INTO testIndex(bitValue)
VALUES (0)
GO 20000 --runs current batch 20000 times.
INSERT INTO testIndex(bitValue)
VALUES (1)
GO 10 --puts 10 rows into table with value 1

UPDATE STATISTICS dbo.testIndex
DBCC SHOW_STATISTICS('dbo.testIndex', 'XtestIndex_bitValue') 
                                                WITH HISTOGRAM
GO

SELECT *
FROM   testIndex
WHERE  bitValue = 0
GO

SELECT *
FROM   testIndex
WHERE  bitValue = 1
GO

-----------------------------------------------------------
-- Covering Index
-----------------------------------------------------------

select name, color
from produce.vegetable
where color = 'orange' 

GO

DROP INDEX produce.vegetable.Xvegetable_color
CREATE INDEX Xvegetable_color ON produce.vegetable(color) INCLUDE (name)
GO

select name, color
from produce.vegetable
where color = 'orange' 

GO

-----------------------------------------------------------
-- Composite Indexes
-----------------------------------------------------------

SELECT color, consistency
FROM produce.vegetable
WHERE color = 'orange'
  and consistency = 'crunchy'
GO

CREATE INDEX xvegetable_consistencyAndColor
         ON produce.vegetable(consistency, color)
GO

SELECT color, consistency
FROM produce.vegetable
WHERE color = 'orange'
  and consistency = 'crunchy'
GO

SELECT color
FROM   produce.vegetable
WHERE  color = 'green'
GO

-----------------------------------------------------------
-- Multiple Index Usage
-----------------------------------------------------------

CREATE INDEX Xvegetable_consistency ON produce.vegetable(consistency)
--and this index previously created
--CREATE INDEX Xvegetable_color ON produce.vegetable(color) INCLUDE (name)
GO

SELECT consistency, color
FROM   produce.vegetable with (index=Xvegetable_color, 
                             index=Xvegetable_consistency)
WHERE  color = 'green'
 and   consistency = 'leafy'
GO


-----------------------------------------------------------
-- Nonclustered Index on a heap
-----------------------------------------------------------

ALTER TABLE produce.vegetable 
    DROP CONSTRAINT PKvegetable 

ALTER TABLE produce.vegetable 
    ADD CONSTRAINT PKvegetable PRIMARY KEY NONCLUSTERED (vegetableID)
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId in (1, 4)
GO

ALTER TABLE produce.vegetable 
    DROP CONSTRAINT PKvegetable 

ALTER TABLE produce.vegetable 
    ADD CONSTRAINT PKvegetable PRIMARY KEY CLUSTERED (vegetableID)
GO

-----------------------------------------------------------
-- Nonclustered Indexes with Clustered Tables
-----------------------------------------------------------

SELECT 	* 
FROM   produce.vegetable 
WHERE  name = 'asparagus'
GO

SELECT 	* 
FROM   produce.vegetable 
WHERE  color = 'orange'
GO

-----------------------------------------------------------
-- Using Indexed Views to Optimize Denormalizations
-----------------------------------------------------------
Use AdventureWorks
GO
CREATE VIEW Production.ProductAverageSales
WITH SCHEMABINDING
AS  
SELECT Product.productNumber, 
       SUM(SalesOrderDetail.lineTotal) as totalSales, 
       COUNT_BIG(*) as countSales
FROM   Production.Product as Product
          JOIN Sales.SalesOrderDetail as SalesOrderDetail
                 ON product.ProductID=SalesOrderDetail.ProductID
GROUP  BY Product.productNumber
GO

SELECT productNumber, totalSales, countSales
FROM   Production.ProductAverageSales
GO
CREATE UNIQUE CLUSTERED INDEX XPKProductAverageSales on 
                                       Production.ProductAverageSales(productNumber)
GO
SELECT productNumber, totalSales, countSales
FROM   Production.ProductAverageSales
GO

SELECT Product.productNumber, sum(SalesOrderDetail.lineTotal) / COUNT(*) 
FROM   Production.Product as Product
          JOIN Sales.SalesOrderDetail as SalesOrderDetail
                 ON product.ProductID=SalesOrderDetail.ProductID
GROUP  BY Product.productNumber
GO
-----------------------------------------------------------
--
-----------------------------------------------------------
